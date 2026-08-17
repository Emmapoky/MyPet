import Foundation

/// Runs the behaviour model off the main actor and merges its output with the
/// flags already on screen.
///
/// This is the "asynchronous background processing" half of the architecture.
/// Nothing in the UI ever calls `AnomalyDetector` directly: a carer writes a
/// log, the store publishes `.logRecorded`, this service picks it up, re-scores
/// that pet on a background executor and hands back a merged flag set. The
/// dashboard updates because its data changed, not because a screen asked for
/// an analysis.
actor BehaviorAnalysisService {

    private let bus: EventBus
    private var config: DetectionConfig

    /// Per-pet debounce. A carer filling in the quick-entry sheet can touch the
    /// same day's log several times in a few seconds; without this, each keystroke
    /// would kick off a full re-analysis.
    private var pendingTasks: [UUID: Task<Void, Never>] = [:]
    private let debounce: Duration = .milliseconds(400)

    private(set) var lastRunAt: Date?
    private(set) var lastRunDuration: TimeInterval?

    init(bus: EventBus, config: DetectionConfig = .default) {
        self.bus = bus
        self.config = config
    }

    func updateConfig(_ newConfig: DetectionConfig) {
        config = newConfig
    }

    func currentConfig() -> DetectionConfig { config }

    // MARK: Analysis

    /// Scores one pet and returns the merged flag set for it.
    ///
    /// - Parameter existingFlags: every flag currently held for this pet, so
    ///   acknowledgements and dismissals survive a re-run.
    func analyze(
        pet: Pet,
        logs: [BehaviorLog],
        existingFlags: [BehaviorFlag],
        asOf: Date = .now
    ) async -> [BehaviorFlag] {

        await bus.publish(.analysisStarted(petID: pet.id))
        let started = Date.now

        let detector = AnomalyDetector(config: config)
        let petLogs = logs.filter { $0.petID == pet.id }
        let detected = detector.analyze(pet: pet, logs: petLogs, asOf: asOf)

        let merged = merge(detected: detected, existing: existingFlags.filter { $0.petID == pet.id }, asOf: asOf)

        lastRunAt = .now
        lastRunDuration = Date.now.timeIntervalSince(started)

        for flag in merged where flag.status == .active && flag.severity >= .watch {
            await bus.publish(.flagRaised(petID: pet.id, kind: flag.kind, severity: flag.severity))
        }
        await bus.publish(.analysisFinished(petID: pet.id, flagCount: merged.filter { $0.status == .active }.count))

        return merged
    }

    /// Scores every pet. Runs pets concurrently — they are fully independent,
    /// and a household with six animals should not wait for six sequential passes.
    func analyzeAll(
        pets: [Pet],
        logs: [BehaviorLog],
        existingFlags: [BehaviorFlag],
        asOf: Date = .now
    ) async -> [BehaviorFlag] {

        await withTaskGroup(of: [BehaviorFlag].self) { group in
            for pet in pets {
                group.addTask { [self] in
                    await analyze(pet: pet, logs: logs, existingFlags: existingFlags, asOf: asOf)
                }
            }

            var all: [BehaviorFlag] = []
            for await flags in group { all.append(contentsOf: flags) }
            return all.sorted { ($0.severity, $0.score) > ($1.severity, $1.score) }
        }
    }

    /// Debounced re-analysis, used on the write path.
    func scheduleAnalysis(
        for pet: Pet,
        logs: [BehaviorLog],
        existingFlags: [BehaviorFlag],
        completion: @escaping @Sendable ([BehaviorFlag]) -> Void
    ) {
        pendingTasks[pet.id]?.cancel()

        pendingTasks[pet.id] = Task { [self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }

            let flags = await analyze(pet: pet, logs: logs, existingFlags: existingFlags)
            guard !Task.isCancelled else { return }
            completion(flags)
            await clearPending(pet.id)
        }
    }

    private func clearPending(_ petID: UUID) {
        pendingTasks[petID] = nil
    }

    // MARK: Merge

    /// Reconciles a fresh detection pass against what is already on screen.
    ///
    /// The rules, in order of how much they matter:
    ///
    /// - **A dismissed flag stays dismissed** while the same syndrome persists.
    ///   Telling the app "yes, I changed her food, I know" and having it argue
    ///   back every four hours is exactly how an alert system gets ignored.
    /// - **An acknowledged flag keeps its acknowledgement** unless it gets
    ///   *worse*, in which case it goes active again — escalation is news.
    /// - **A flag that stops tripping is resolved**, not deleted, so the history
    ///   of "she was off her food for three days last month" survives to be
    ///   shown to a vet.
    func merge(
        detected: [BehaviorFlag],
        existing: [BehaviorFlag],
        asOf: Date
    ) -> [BehaviorFlag] {

        var result: [BehaviorFlag] = []
        var handledKeys: Set<String> = []

        for var flag in detected {
            handledKeys.insert(flag.dedupeKey)

            guard let previous = existing.first(where: {
                $0.dedupeKey == flag.dedupeKey && $0.status != .resolved
            }) else {
                result.append(flag)
                continue
            }

            // Keep identity stable so SwiftUI animates the card rather than
            // replacing it, and so a notification is not re-fired.
            flag.id = previous.id

            switch previous.status {
            case .dismissed:
                flag.status = .dismissed
                flag.acknowledgedAt = previous.acknowledgedAt

            case .acknowledged:
                if flag.severity > previous.severity {
                    flag.status = .active
                } else {
                    flag.status = .acknowledged
                    flag.acknowledgedAt = previous.acknowledgedAt
                }

            case .active, .resolved:
                flag.status = .active
            }

            result.append(flag)
        }

        // Anything previously active that no longer trips has resolved on its own.
        for var stale in existing where !handledKeys.contains(stale.dedupeKey) {
            guard stale.status != .resolved else {
                result.append(stale)
                continue
            }
            stale.status = .resolved
            result.append(stale)
        }

        return result.sorted { ($0.severity, $0.score) > ($1.severity, $1.score) }
    }
}
