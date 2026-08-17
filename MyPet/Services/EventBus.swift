import Foundation

/// Something that happened in the domain, worth telling other services about.
///
/// The bus is what makes the app *reactive* rather than a pile of screens that
/// poll. Writing a log publishes `.logRecorded`; the analysis service is
/// listening and re-scores that pet without the view layer ever knowing an
/// analysis was needed.
enum DomainEvent: Sendable, Hashable {
    case petUpserted(UUID)
    case petDeleted(UUID)
    case logRecorded(petID: UUID, day: Date)
    case taskUpserted(UUID)
    case taskCompleted(taskID: UUID, dueAt: Date)
    case healthRecordUpserted(UUID)
    case analysisStarted(petID: UUID)
    case analysisFinished(petID: UUID, flagCount: Int)
    case flagRaised(petID: UUID, kind: FlagKind, severity: FlagSeverity)
    case syncStateChanged(SyncState)
    case remoteChangesApplied(count: Int)

    var petID: UUID? {
        switch self {
        case .petUpserted(let id), .petDeleted(let id): id
        case .logRecorded(let id, _): id
        case .analysisStarted(let id): id
        case .analysisFinished(let id, _): id
        case .flagRaised(let id, _, _): id
        case .taskUpserted, .taskCompleted, .healthRecordUpserted,
             .syncStateChanged, .remoteChangesApplied: nil
        }
    }
}

/// In-process publish/subscribe hub.
///
/// An `actor` so publishing is safe from any isolation domain — the sync
/// service publishes from a background task, the store from the main actor, and
/// neither needs to know about the other.
///
/// Each subscriber gets its own buffered `AsyncStream`. Buffering (rather than
/// dropping) matters because a burst of remote changes during a sync must not
/// lose the events that trigger re-analysis.
actor EventBus {

    private var continuations: [UUID: AsyncStream<DomainEvent>.Continuation] = [:]

    /// Recent events, newest last. Powers the developer-facing activity feed in
    /// Settings, which is how the async pipeline is made visible during a demo.
    private(set) var recentEvents: [TimestampedEvent] = []
    private let recentLimit = 60

    struct TimestampedEvent: Identifiable, Hashable {
        let id = UUID()
        let event: DomainEvent
        let at: Date
    }

    /// Subscribes to every future event. The stream ends when the caller stops
    /// iterating, which unregisters the continuation automatically.
    func subscribe() -> AsyncStream<DomainEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(64)) { continuation in
            let key = UUID()
            continuations[key] = continuation

            continuation.onTermination = { [weak self] _ in
                Task { await self?.unsubscribe(key) }
            }
        }
    }

    private func unsubscribe(_ key: UUID) {
        continuations[key] = nil
    }

    func publish(_ event: DomainEvent) {
        recentEvents.append(TimestampedEvent(event: event, at: .now))
        if recentEvents.count > recentLimit {
            recentEvents.removeFirst(recentEvents.count - recentLimit)
        }

        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    func snapshot() -> [TimestampedEvent] { recentEvents }

    func clearHistory() { recentEvents.removeAll() }
}

// MARK: - Human-readable descriptions

extension DomainEvent {
    /// Used by the activity feed in Settings.
    var label: String {
        switch self {
        case .petUpserted: "Pet saved"
        case .petDeleted: "Pet removed"
        case .logRecorded: "Behaviour logged"
        case .taskUpserted: "Task saved"
        case .taskCompleted: "Task completed"
        case .healthRecordUpserted: "Health record saved"
        case .analysisStarted: "Analysis started"
        case .analysisFinished(_, let count): "Analysis finished · \(count) flag\(count == 1 ? "" : "s")"
        case .flagRaised(_, let kind, let severity): "\(severity.displayName): \(kind.displayName)"
        case .syncStateChanged(let state): "Sync · \(state.displayName)"
        case .remoteChangesApplied(let count): "Applied \(count) remote change\(count == 1 ? "" : "s")"
        }
    }

    var symbolName: String {
        switch self {
        case .petUpserted, .petDeleted: "pawprint.fill"
        case .logRecorded: "square.and.pencil"
        case .taskUpserted, .taskCompleted: "checklist"
        case .healthRecordUpserted: "cross.case.fill"
        case .analysisStarted, .analysisFinished: "brain.head.profile"
        case .flagRaised: "exclamationmark.triangle.fill"
        case .syncStateChanged, .remoteChangesApplied: "arrow.triangle.2.circlepath"
        }
    }
}
