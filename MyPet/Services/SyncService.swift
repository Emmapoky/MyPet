import Foundation

// MARK: - Sync state

enum SyncState: Sendable, Hashable {
    case idle
    case syncing
    /// Deliberately offline, or no reachable backend. Edits queue in the outbox.
    case offline
    case failed(String)

    var displayName: String {
        switch self {
        case .idle: "Up to date"
        case .syncing: "Syncing…"
        case .offline: "Offline"
        case .failed(let message): "Failed: \(message)"
        }
    }

    var symbolName: String {
        switch self {
        case .idle: "checkmark.icloud.fill"
        case .syncing: "arrow.triangle.2.circlepath.icloud.fill"
        case .offline: "icloud.slash.fill"
        case .failed: "exclamationmark.icloud.fill"
        }
    }
}

// MARK: - Envelope

/// One replicated record, opaque payload plus the metadata needed to order it
/// against the same record edited elsewhere.
struct SyncEnvelope: Codable, Hashable, Sendable, Identifiable {

    enum EntityType: String, Codable, Hashable, Sendable {
        case pet, log, task, healthRecord
    }

    var entityType: EntityType
    var entityID: UUID

    /// Per-record edit counter from the originating device.
    var revision: Int

    /// Lamport timestamp. The reason this exists rather than trusting
    /// `updatedAt`: device clocks disagree, and a phone whose clock is five
    /// minutes fast would otherwise win every conflict forever. A Lamport clock
    /// gives a consistent causal order regardless of wall-clock skew.
    var lamport: Int

    /// Which device produced this version — the deterministic tiebreak when two
    /// devices land on the same Lamport value.
    var nodeID: String

    var updatedAt: Date
    var isDeleted: Bool = false

    /// JSON-encoded record.
    var payload: Data

    var id: String { "\(entityType.rawValue)-\(entityID.uuidString)-\(lamport)-\(nodeID)" }
}

// MARK: - Conflict resolution

/// The merge rule, factored out as pure functions so it can be unit-tested
/// without any I/O, timing or actor hops.
enum SyncResolver {

    enum Resolution: Hashable {
        /// Remote version wins; apply it locally.
        case takeRemote
        /// Local version wins; keep local and re-push.
        case keepLocal
        /// Identical versions; nothing to do.
        case noChange
    }

    /// Last-writer-wins, ordered by Lamport clock, then node ID as a
    /// deterministic tiebreak.
    ///
    /// LWW is the right trade here and worth being explicit about: it can lose
    /// a concurrent edit's content, but it always converges, needs no user
    /// intervention, and cannot corrupt a record. For a household care log —
    /// where genuine simultaneous edits to the *same field* of the *same
    /// record* are rare — that is the correct exchange. A field-level CRDT
    /// would preserve more, at a complexity cost this project does not need.
    static func resolve(local: SyncEnvelope?, remote: SyncEnvelope) -> Resolution {
        guard let local else { return .takeRemote }

        if local.lamport == remote.lamport
            && local.nodeID == remote.nodeID
            && local.revision == remote.revision {
            return .noChange
        }

        if remote.lamport != local.lamport {
            return remote.lamport > local.lamport ? .takeRemote : .keepLocal
        }

        // Same Lamport value: concurrent edits. Order by node ID so every
        // device in the mesh independently reaches the same answer.
        return remote.nodeID > local.nodeID ? .takeRemote : .keepLocal
    }
}

// MARK: - Backend protocol

/// What the sync layer needs from a server.
///
/// Deliberately tiny. Swapping the bundled in-memory stand-in for Firebase,
/// Supabase or a bespoke API means writing one conforming type; nothing above
/// this line changes.
protocol SyncBackend: Actor {
    /// Uploads envelopes and returns the backend's Lamport high-water mark.
    func push(_ envelopes: [SyncEnvelope]) async throws -> Int
    /// Returns every envelope with a Lamport value greater than `cursor`.
    func pull(since cursor: Int) async throws -> [SyncEnvelope]
}

/// A stand-in server that lives in memory, complete with artificial latency and
/// an injectable failure mode.
///
/// This exists so the distributed behaviour — outbox queueing, conflict
/// resolution, convergence between two devices — is real, demonstrable and
/// testable without provisioning a backend for a student project. The
/// `simulatePeerEdit` hook lets the Settings screen inject an edit "from
/// another carer's phone" and watch it merge.
actor InMemorySyncBackend: SyncBackend {

    private var store: [String: SyncEnvelope] = [:]
    private var clock: Int = 0

    /// Round-trip latency applied to both operations, so the UI's syncing state
    /// is actually visible rather than flickering past.
    var latency: Duration = .milliseconds(450)

    /// When true, every call throws — used to demonstrate the offline outbox.
    var shouldFail = false

    private func key(_ envelope: SyncEnvelope) -> String {
        "\(envelope.entityType.rawValue)-\(envelope.entityID.uuidString)"
    }

    struct BackendError: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    func push(_ envelopes: [SyncEnvelope]) async throws -> Int {
        try await Task.sleep(for: latency)
        if shouldFail { throw BackendError(message: "Backend unreachable") }

        for envelope in envelopes {
            clock = max(clock, envelope.lamport) + 1
            var stamped = envelope
            stamped.lamport = clock

            // The backend applies the same resolution rule as the client, so
            // an out-of-order push cannot roll a record backwards.
            let existing = store[key(envelope)]
            if SyncResolver.resolve(local: existing, remote: stamped) == .takeRemote || existing == nil {
                store[key(envelope)] = stamped
            }
        }
        return clock
    }

    func pull(since cursor: Int) async throws -> [SyncEnvelope] {
        try await Task.sleep(for: latency)
        if shouldFail { throw BackendError(message: "Backend unreachable") }
        return store.values.filter { $0.lamport > cursor }.sorted { $0.lamport < $1.lamport }
    }

    // MARK: Demo hooks

    func setShouldFail(_ value: Bool) { shouldFail = value }
    func setLatency(_ value: Duration) { latency = value }

    /// Injects a change as if a second device had made it, so merge behaviour
    /// can be exercised from the running app.
    func simulatePeerEdit(_ envelope: SyncEnvelope) {
        clock += 1
        var stamped = envelope
        stamped.lamport = clock
        store[key(envelope)] = stamped
    }

    func envelopeCount() -> Int { store.count }
    func currentClock() -> Int { clock }
    func reset() { store.removeAll(); clock = 0 }
}

// MARK: - SyncService

/// Coordinates replication between this device and a backend.
///
/// Offline-first by construction: every local edit lands in the outbox
/// immediately and the UI never waits on the network. When connectivity
/// returns, the outbox drains. Nothing about the user experience depends on the
/// backend being reachable.
actor SyncService {

    private let backend: any SyncBackend
    private let bus: EventBus

    private(set) var state: SyncState = .idle
    private(set) var nodeID: String
    private(set) var lamport: Int
    private(set) var cursor: Int = 0
    private(set) var lastSyncedAt: Date?

    /// Local edits not yet accepted by the backend, newest version per record.
    private(set) var outbox: [String: SyncEnvelope] = [:]

    /// Conflicts resolved during the last sync, kept for the Settings readout.
    private(set) var lastConflicts: [String] = []

    /// User-controlled offline switch, exposed in Settings for demos.
    private(set) var isOfflineMode = false

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(backend: any SyncBackend, bus: EventBus, nodeID: String, lamport: Int = 0) {
        self.backend = backend
        self.bus = bus
        self.nodeID = nodeID
        self.lamport = lamport
    }

    var pendingCount: Int { outbox.count }

    // MARK: Enqueue

    /// Records a local edit for replication. Never throws and never blocks —
    /// the caller has already updated the UI and must not be made to care
    /// whether a network exists.
    func enqueue<T: Syncable>(_ record: T, type: SyncEnvelope.EntityType, isDeleted: Bool = false) {
        lamport += 1
        guard let payload = try? encoder.encode(record) else { return }

        let envelope = SyncEnvelope(
            entityType: type,
            entityID: record.id,
            revision: record.revision,
            lamport: lamport,
            nodeID: nodeID,
            updatedAt: record.updatedAt,
            isDeleted: isDeleted,
            payload: payload
        )
        outbox["\(type.rawValue)-\(record.id.uuidString)"] = envelope
    }

    // MARK: Sync cycle

    /// Result of one sync pass, handed back to the store so it can apply
    /// incoming records on the main actor.
    struct SyncOutcome: Sendable {
        var pets: [Pet] = []
        var logs: [BehaviorLog] = []
        var tasks: [CareTask] = []
        var healthRecords: [HealthRecord] = []
        var deletedPetIDs: [UUID] = []
        var conflicts: [String] = []

        var totalApplied: Int {
            pets.count + logs.count + tasks.count + healthRecords.count + deletedPetIDs.count
        }
    }

    /// Pushes the outbox, pulls remote changes, and returns what to apply.
    @discardableResult
    func sync() async -> SyncOutcome {
        guard !isOfflineMode else {
            await setState(.offline)
            return SyncOutcome()
        }

        await setState(.syncing)
        lastConflicts = []

        do {
            if !outbox.isEmpty {
                let high = try await backend.push(Array(outbox.values))
                lamport = max(lamport, high)
                outbox.removeAll()
            }

            let incoming = try await backend.pull(since: cursor)
            let outcome = apply(incoming)

            if let maxLamport = incoming.map(\.lamport).max() {
                cursor = max(cursor, maxLamport)
                lamport = max(lamport, maxLamport)
            }

            lastSyncedAt = .now
            await setState(.idle)

            if outcome.totalApplied > 0 {
                await bus.publish(.remoteChangesApplied(count: outcome.totalApplied))
            }
            return outcome

        } catch {
            await setState(.failed(error.localizedDescription))
            return SyncOutcome()
        }
    }

    /// Decodes incoming envelopes, skipping any that lose to a local edit still
    /// sitting in the outbox.
    private func apply(_ envelopes: [SyncEnvelope]) -> SyncOutcome {
        var outcome = SyncOutcome()

        for envelope in envelopes {
            // Ignore our own echo.
            guard envelope.nodeID != nodeID else { continue }

            let key = "\(envelope.entityType.rawValue)-\(envelope.entityID.uuidString)"
            let resolution = SyncResolver.resolve(local: outbox[key], remote: envelope)

            guard resolution == .takeRemote else {
                if resolution == .keepLocal {
                    outcome.conflicts.append("\(envelope.entityType.rawValue) \(envelope.entityID.uuidString.prefix(8)) — kept local")
                }
                continue
            }

            if outbox[key] != nil {
                outcome.conflicts.append("\(envelope.entityType.rawValue) \(envelope.entityID.uuidString.prefix(8)) — took remote")
                outbox[key] = nil
            }

            if envelope.isDeleted {
                if envelope.entityType == .pet { outcome.deletedPetIDs.append(envelope.entityID) }
                continue
            }

            switch envelope.entityType {
            case .pet:
                if let value = try? decoder.decode(Pet.self, from: envelope.payload) { outcome.pets.append(value) }
            case .log:
                if let value = try? decoder.decode(BehaviorLog.self, from: envelope.payload) { outcome.logs.append(value) }
            case .task:
                if let value = try? decoder.decode(CareTask.self, from: envelope.payload) { outcome.tasks.append(value) }
            case .healthRecord:
                if let value = try? decoder.decode(HealthRecord.self, from: envelope.payload) { outcome.healthRecords.append(value) }
            }
        }

        lastConflicts = outcome.conflicts
        return outcome
    }

    // MARK: Controls

    func setOfflineMode(_ offline: Bool) async {
        isOfflineMode = offline
        await setState(offline ? .offline : .idle)
    }

    private func setState(_ newState: SyncState) async {
        guard state != newState else { return }
        state = newState
        await bus.publish(.syncStateChanged(newState))
    }

    /// Snapshot for the Settings screen — one hop instead of five.
    struct Status: Sendable {
        var state: SyncState
        var pending: Int
        var lastSyncedAt: Date?
        var nodeID: String
        var lamport: Int
        var conflicts: [String]
    }

    func status() -> Status {
        Status(
            state: state,
            pending: outbox.count,
            lastSyncedAt: lastSyncedAt,
            nodeID: nodeID,
            lamport: lamport,
            conflicts: lastConflicts
        )
    }

    func currentLamport() -> Int { lamport }
}
