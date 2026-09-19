import Foundation
import Observation
import SwiftUI

/// The single source of truth the UI reads, and the only place that mutates
/// domain state.
///
/// Views never talk to a service. They mutate through the store; the store
/// updates its published state immediately (so the UI is never waiting on
/// anything), then fans the work out to the actors — persist, enqueue for sync,
/// re-analyse, reschedule alerts. That ordering is what makes the app feel
/// instant while still doing real background work.
@MainActor
@Observable
final class MyPetStore {

    // MARK: Published domain state

    private(set) var pets: [Pet] = []
    private(set) var logs: [BehaviorLog] = []
    private(set) var tasks: [CareTask] = []
    private(set) var healthRecords: [HealthRecord] = []
    private(set) var flags: [BehaviorFlag] = []

    var config: DetectionConfig = .default {
        didSet {
            guard oldValue != config else { return }
            Task {
                await analysisService.updateConfig(config)
                await runAnalysis()
                persist()
            }
        }
    }

    // MARK: Published infrastructure state

    private(set) var syncStatus: SyncService.Status?
    private(set) var isAnalyzing = false
    private(set) var isSyncing = false
    private(set) var hasLoaded = false
    private(set) var notificationsAuthorized = false
    private(set) var eventFeed: [EventBus.TimestampedEvent] = []
    private(set) var storageDescription = ""

    // MARK: Services

    private let persistence: PersistenceService
    private let bus: EventBus
    private let backend: InMemorySyncBackend
    private let sync: SyncService
    private let notifications: NotificationService
    private let analysisService: BehaviorAnalysisService

    private var nodeID: String
    private var busTask: Task<Void, Never>?

    // MARK: Init

    init(location: PersistenceService.StorageLocation = .applicationSupport) {
        let bus = EventBus()
        let backend = InMemorySyncBackend()
        let nodeID = "device-\(UUID().uuidString.prefix(8))"

        self.persistence = PersistenceService(location: location)
        self.bus = bus
        self.backend = backend
        self.nodeID = nodeID
        self.sync = SyncService(backend: backend, bus: bus, nodeID: nodeID)
        self.notifications = NotificationService()
        self.analysisService = BehaviorAnalysisService(bus: bus, config: .default)
    }

    // MARK: Bootstrap

    /// Loads from disk, seeds demo data on a first run, then brings every
    /// service up to date. Safe to call more than once.
    func bootstrap() async {
        guard !hasLoaded else { return }

        if let snapshot = await persistence.load() {
            apply(snapshot)
        } else {
            let seeded = DemoData.snapshot(nodeID: nodeID)
            apply(seeded)
            persist()
        }

        storageDescription = await persistence.storageDescription
        hasLoaded = true

        observeEvents()

        await analysisService.updateConfig(config)
        await runAnalysis()

        // Check, never request. Throwing a permission modal at someone before
        // they have seen a single screen is how apps get denied permanently —
        // and a denied MyPet gives no medication reminders at all. The ask
        // happens in Settings, or the moment a carer turns on a reminder,
        // when there is a visible reason for it.
        let status = await notifications.refreshAuthorizationStatus()
        notificationsAuthorized = (status == .authorized || status == .provisional)
        await rescheduleAlerts()
        await refreshSyncStatus()
    }

    private func apply(_ snapshot: AppSnapshot) {
        pets = snapshot.pets
        logs = snapshot.logs
        tasks = snapshot.tasks
        healthRecords = snapshot.healthRecords
        flags = snapshot.flags
        config = snapshot.config
        nodeID = snapshot.nodeID
    }

    /// Mirrors the event bus into `eventFeed` so the Settings activity view can
    /// show the async pipeline working. Also the hook a future push-driven
    /// backend would use to trigger a pull.
    private func observeEvents() {
        busTask?.cancel()

        // `self` is captured weakly and re-acquired inside the loop rather than
        // once up front: a `guard let self` before the `for await` would hold a
        // strong reference for the life of the stream and leak the store.
        let bus = self.bus
        busTask = Task { [weak self] in
            let stream = await bus.subscribe()
            for await _ in stream {
                let snapshot = await bus.snapshot()
                guard let self else { return }
                self.eventFeed = snapshot.reversed()
            }
        }
    }

    // MARK: Persistence

    /// Writes current state. Fire-and-forget by design — the UI has already
    /// moved on, and a failed write is recoverable at next launch.
    private func persist() {
        let snapshot = AppSnapshot(
            pets: pets,
            logs: logs,
            tasks: tasks,
            healthRecords: healthRecords,
            flags: flags,
            config: config,
            nodeID: nodeID,
            lamport: 0
        )
        Task { await persistence.save(snapshot) }
    }

    // MARK: - Pets

    func upsert(pet: Pet) {
        var updated = pet
        updated.touch()

        if let index = pets.firstIndex(where: { $0.id == updated.id }) {
            pets[index] = updated
        } else {
            pets.append(updated)
        }
        pets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        persist()
        Task {
            await sync.enqueue(updated, type: .pet)
            await bus.publish(.petUpserted(updated.id))
            await refreshSyncStatus()
        }
    }

    /// Removes a pet and everything attached to it.
    ///
    /// Destructive and irreversible, so the only caller is a confirmation
    /// dialog. Cascading is correct here: orphan logs referencing a deleted pet
    /// would silently distort every aggregate on the dashboard.
    func delete(pet: Pet) {
        pets.removeAll { $0.id == pet.id }
        logs.removeAll { $0.petID == pet.id }
        tasks.removeAll { $0.petID == pet.id }
        healthRecords.removeAll { $0.petID == pet.id }
        flags.removeAll { $0.petID == pet.id }

        persist()
        Task {
            await sync.enqueue(pet, type: .pet, isDeleted: true)
            await bus.publish(.petDeleted(pet.id))
            await rescheduleAlerts()
            await refreshSyncStatus()
        }
    }

    func pet(id: UUID) -> Pet? { pets.first { $0.id == id } }

    // MARK: - Behaviour logs

    /// The log for a pet on a given day, if one exists.
    func log(for petID: UUID, on day: Date, calendar: Calendar = .current) -> BehaviorLog? {
        let target = calendar.startOfDay(for: day)
        return logs.first { $0.petID == petID && $0.day == target }
    }

    /// The existing log for that day, or a fresh one pre-filled from the pet's
    /// recent pattern — so quick entry usually means adjusting two fields, not
    /// filling in eight.
    func draftLog(for pet: Pet, on day: Date = .now, calendar: Calendar = .current) -> BehaviorLog {
        if let existing = log(for: pet.id, on: day, calendar: calendar) { return existing }

        let recent = logs
            .filter { $0.petID == pet.id }
            .sorted { $0.day > $1.day }
            .prefix(7)

        let baselineModel = BaselineModel(config: config)
        let baseline = baselineModel.buildBaseline(
            logs: Array(recent), species: pet.species, asOf: day, calendar: calendar
        )

        return BehaviorLog(
            petID: pet.id,
            day: day,
            mealsOffered: recent.first?.mealsOffered ?? 2,
            mealsEaten: Double(recent.first?.mealsOffered ?? 2),
            waterMl: nil,
            sleepHours: nil,
            activityMinutes: nil,
            energyLevel: 3,
            mood: .content,
            weightKg: nil,
            eliminationNormal: true
        )
    }

    /// Saves a log and kicks off a debounced re-analysis for that pet.
    func record(log: BehaviorLog) {
        var updated = log
        updated.touch()

        if let index = logs.firstIndex(where: { $0.id == updated.id }) {
            logs[index] = updated
        } else if let index = logs.firstIndex(where: {
            $0.petID == updated.petID && $0.day == updated.day
        }) {
            // Same pet, same day — update in place rather than creating a
            // second log the detector would then have to disambiguate.
            updated.id = logs[index].id
            logs[index] = updated
        } else {
            logs.append(updated)
        }
        logs.sort { $0.day > $1.day }

        // Keep the fast-read weight on the pet in step with the latest weigh-in.
        if let weight = updated.weightKg,
           let index = pets.firstIndex(where: { $0.id == updated.petID }) {
            pets[index].weightKg = weight
            pets[index].touch()
        }

        persist()

        guard let pet = pet(id: updated.petID) else { return }
        let currentLogs = logs
        let currentFlags = flags

        Task {
            await rescheduleLogReminders()
            await sync.enqueue(updated, type: .log)
            await bus.publish(.logRecorded(petID: updated.petID, day: updated.day))
            await refreshSyncStatus()

            await analysisService.scheduleAnalysis(
                for: pet,
                logs: currentLogs,
                existingFlags: currentFlags
            ) { newFlags in
                Task { @MainActor [weak self] in
                    self?.applyFlags(newFlags, for: pet.id)
                }
            }
        }
    }

    func deleteLog(_ log: BehaviorLog) {
        logs.removeAll { $0.id == log.id }
        persist()
        Task { await runAnalysis() }
    }

    /// Logs for one pet, newest first.
    func logs(for petID: UUID) -> [BehaviorLog] {
        logs.filter { $0.petID == petID }.sorted { $0.day > $1.day }
    }

    /// How many of the last `days` days have a log — the "are we actually
    /// feeding the model" number shown on each pet card.
    func loggingStreak(for petID: UUID, days: Int = 7, asOf: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: asOf)
        let petLogs = Set(logs.filter { $0.petID == petID }.map(\.day))

        var count = 0
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if petLogs.contains(day) { count += 1 }
        }
        return count
    }

    // MARK: - Care tasks

    func upsert(task: CareTask) {
        var updated = task
        updated.touch()

        if let index = tasks.firstIndex(where: { $0.id == updated.id }) {
            tasks[index] = updated
        } else {
            tasks.append(updated)
        }

        persist()
        Task {
            await sync.enqueue(updated, type: .task)
            await bus.publish(.taskUpserted(updated.id))
            await rescheduleAlerts()
            await refreshSyncStatus()
        }
    }

    func delete(task: CareTask) {
        tasks.removeAll { $0.id == task.id }
        persist()
        Task {
            await sync.enqueue(task, type: .task, isDeleted: true)
            await rescheduleAlerts()
        }
    }

    /// Ticks an occurrence off, or un-ticks it if it was already done.
    func toggleCompletion(of occurrence: TaskOccurrence) {
        guard let index = tasks.firstIndex(where: { $0.id == occurrence.taskID }) else { return }

        if tasks[index].completedOccurrences.contains(occurrence.dueAt) {
            tasks[index].completedOccurrences.remove(occurrence.dueAt)
        } else {
            tasks[index].completedOccurrences.insert(occurrence.dueAt)
        }
        tasks[index].touch()

        let updated = tasks[index]
        persist()

        Task {
            await sync.enqueue(updated, type: .task)
            await bus.publish(.taskCompleted(taskID: updated.id, dueAt: occurrence.dueAt))
            await rescheduleAlerts()
            await refreshSyncStatus()
        }
    }

    /// Every occurrence due on `day`, across all pets, in time order.
    func occurrences(on day: Date = .now, calendar: Calendar = .current) -> [TaskOccurrence] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let interval = DateInterval(start: start, end: end)

        return tasks
            .flatMap { $0.occurrences(in: interval, calendar: calendar) }
            .sorted { $0.dueAt < $1.dueAt }
    }

    func occurrences(for petID: UUID, on day: Date = .now, calendar: Calendar = .current) -> [TaskOccurrence] {
        occurrences(on: day, calendar: calendar).filter { $0.petID == petID }
    }

    /// Anything past due and not ticked off, worst first.
    func overdueOccurrences(now: Date = .now, calendar: Calendar = .current) -> [TaskOccurrence] {
        occurrences(on: now, calendar: calendar)
            .filter { $0.isOverdue(now: now) }
            .sorted { lhs, rhs in
                if lhs.category.isCritical != rhs.category.isCritical { return lhs.category.isCritical }
                return lhs.dueAt < rhs.dueAt
            }
    }

    /// The next few things due, for the dashboard's "up next" strip.
    func upcomingOccurrences(limit: Int = 4, now: Date = .now, calendar: Calendar = .current) -> [TaskOccurrence] {
        guard let end = calendar.date(byAdding: .day, value: 2, to: now) else { return [] }
        return tasks
            .flatMap { $0.occurrences(in: DateInterval(start: now, end: end), calendar: calendar) }
            .filter { !$0.isCompleted }
            .sorted { $0.dueAt < $1.dueAt }
            .prefix(limit)
            .map { $0 }
    }

    func tasks(for petID: UUID) -> [CareTask] {
        tasks.filter { $0.petID == petID }.sorted { $0.title < $1.title }
    }

    // MARK: - Health records

    func upsert(record: HealthRecord) {
        var updated = record
        updated.touch()

        if let index = healthRecords.firstIndex(where: { $0.id == updated.id }) {
            healthRecords[index] = updated
        } else {
            healthRecords.append(updated)
        }
        healthRecords.sort { $0.date > $1.date }

        if updated.kind == .weighIn, let weight = updated.weightKg,
           let index = pets.firstIndex(where: { $0.id == updated.petID }) {
            pets[index].weightKg = weight
            pets[index].touch()
        }

        persist()
        Task {
            await sync.enqueue(updated, type: .healthRecord)
            await bus.publish(.healthRecordUpserted(updated.id))
            await refreshSyncStatus()
        }
    }

    func delete(record: HealthRecord) {
        healthRecords.removeAll { $0.id == record.id }
        persist()
        Task { await sync.enqueue(record, type: .healthRecord, isDeleted: true) }
    }

    func records(for petID: UUID) -> [HealthRecord] {
        healthRecords.filter { $0.petID == petID }.sorted { $0.date > $1.date }
    }

    /// Boosters and check-ups coming due or already overdue, across all pets.
    func upcomingHealthDue(limit: Int = 5) -> [HealthRecord] {
        healthRecords
            .filter { $0.isDueSoon || $0.isOverdue }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Flags

    /// Active flags across all pets, worst first.
    var activeFlags: [BehaviorFlag] {
        flags
            .filter { $0.status == .active || $0.status == .acknowledged }
            .sorted { ($0.severity, $0.score) > ($1.severity, $1.score) }
    }

    func flags(for petID: UUID, includeResolved: Bool = false) -> [BehaviorFlag] {
        flags
            .filter { $0.petID == petID && (includeResolved || $0.status != .resolved) }
            .sorted { ($0.severity, $0.score) > ($1.severity, $1.score) }
    }

    /// Worst active severity for a pet, or `nil` when nothing is flagged.
    func worstSeverity(for petID: UUID) -> FlagSeverity? {
        flags
            .filter { $0.petID == petID && $0.status == .active }
            .map(\.severity)
            .max()
    }

    func acknowledge(flag: BehaviorFlag) {
        guard let index = flags.firstIndex(where: { $0.id == flag.id }) else { return }
        flags[index].status = .acknowledged
        flags[index].acknowledgedAt = .now
        persist()
    }

    func dismiss(flag: BehaviorFlag) {
        guard let index = flags.firstIndex(where: { $0.id == flag.id }) else { return }
        flags[index].status = .dismissed
        flags[index].acknowledgedAt = .now
        persist()
        Task { await notifications.forgetFlag(flag) }
    }

    func reactivate(flag: BehaviorFlag) {
        guard let index = flags.firstIndex(where: { $0.id == flag.id }) else { return }
        flags[index].status = .active
        flags[index].acknowledgedAt = nil
        persist()
    }

    private func applyFlags(_ newFlags: [BehaviorFlag], for petID: UUID) {
        flags.removeAll { $0.petID == petID }
        flags.append(contentsOf: newFlags)
        flags.sort { ($0.severity, $0.score) > ($1.severity, $1.score) }
        persist()

        let snapshot = flags
        let currentPets = pets
        Task { await notifications.notifyIfNeeded(flags: snapshot, pets: currentPets) }
    }

    // MARK: - Analysis

    /// Re-scores every pet. Called on launch, on foreground, after a sync, and
    /// from the pull-to-refresh gesture.
    func runAnalysis() async {
        guard !pets.isEmpty else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }

        let result = await analysisService.analyzeAll(
            pets: pets, logs: logs, existingFlags: flags
        )

        flags = result
        persist()
        await notifications.notifyIfNeeded(flags: result, pets: pets)
    }

    /// The learned baseline for one pet, used by the Insights screen to draw
    /// the "normal band" behind each metric.
    func baseline(for pet: Pet, asOf: Date = .now) -> PetBaseline {
        BaselineModel(config: config).buildBaseline(
            logs: logs.filter { $0.petID == pet.id },
            species: pet.species,
            asOf: asOf
        )
    }

    // MARK: - Sync

    func syncNow() async {
        isSyncing = true
        defer { isSyncing = false }

        let outcome = await sync.sync()
        guard outcome.totalApplied > 0 else {
            await refreshSyncStatus()
            return
        }

        for pet in outcome.pets { mergeRemote(pet: pet) }
        for log in outcome.logs { mergeRemote(log: log) }
        for task in outcome.tasks { mergeRemote(task: task) }
        for record in outcome.healthRecords { mergeRemote(record: record) }
        for id in outcome.deletedPetIDs {
            pets.removeAll { $0.id == id }
            logs.removeAll { $0.petID == id }
        }

        persist()
        await runAnalysis()
        await rescheduleAlerts()
        await refreshSyncStatus()
    }

    private func mergeRemote(pet: Pet) {
        if let index = pets.firstIndex(where: { $0.id == pet.id }) { pets[index] = pet } else { pets.append(pet) }
        pets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func mergeRemote(log: BehaviorLog) {
        if let index = logs.firstIndex(where: { $0.id == log.id }) { logs[index] = log } else { logs.append(log) }
        logs.sort { $0.day > $1.day }
    }

    private func mergeRemote(task: CareTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) { tasks[index] = task } else { tasks.append(task) }
    }

    private func mergeRemote(record: HealthRecord) {
        if let index = healthRecords.firstIndex(where: { $0.id == record.id }) {
            healthRecords[index] = record
        } else {
            healthRecords.append(record)
        }
        healthRecords.sort { $0.date > $1.date }
    }

    func setOfflineMode(_ offline: Bool) async {
        await sync.setOfflineMode(offline)
        await refreshSyncStatus()
    }

    func setBackendFailing(_ failing: Bool) async {
        await backend.setShouldFail(failing)
    }

    private func refreshSyncStatus() async {
        syncStatus = await sync.status()
    }

    /// Injects an edit as though another carer's phone had made it, then syncs.
    /// This is the demo hook that makes the distributed layer visible: pick a
    /// pet, bump its weight "from another device", and watch it merge in.
    func simulatePeerEdit(on pet: Pet) async {
        var edited = pet
        edited.weightKg = (pet.weightKg * 100 + 30).rounded() / 100
        edited.notes = "Weighed at the vet by another carer."
        edited.updatedAt = .now
        edited.revision += 1

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let payload = try? encoder.encode(edited) else { return }

        let envelope = SyncEnvelope(
            entityType: .pet,
            entityID: edited.id,
            revision: edited.revision,
            lamport: 0,   // the backend stamps the authoritative value
            nodeID: "peer-device",
            updatedAt: edited.updatedAt,
            isDeleted: false,
            payload: payload
        )

        await backend.simulatePeerEdit(envelope)
        await syncNow()
    }

    // MARK: - Notifications

    func requestNotificationAuthorization() async {
        notificationsAuthorized = await notifications.requestAuthorization()
        await rescheduleAlerts()
    }

    private func rescheduleAlerts() async {
        await notifications.rescheduleTaskAlerts(tasks: tasks, pets: pets)
        await rescheduleLogReminders()
    }

    private func rescheduleLogReminders() async {
        let loggedToday = Set(pets.filter { log(for: $0.id, on: .now) != nil }.map(\.id))
        await notifications.rescheduleLogReminders(pets: pets, loggedToday: loggedToday)
    }

    func pendingNotificationSummaries() async -> [String] {
        await notifications.pendingSummaries()
    }

    // MARK: - Demo controls

    /// Replaces all state with the seeded household. Destructive, so it is
    /// behind a confirmation dialog in Settings.
    func reseedDemoData() async {
        let snapshot = DemoData.snapshot(nodeID: nodeID)
        apply(snapshot)
        persist()
        await runAnalysis()
        await rescheduleAlerts()
    }

    /// Wipes everything, including the file on disk. Also destructive, also
    /// behind a confirmation.
    func resetEverything() async {
        pets = []
        logs = []
        tasks = []
        healthRecords = []
        flags = []
        await persistence.reset()
        await notifications.cancelAll()
        await backend.reset()
        await refreshSyncStatus()
    }

    /// Injects three days of declining appetite and energy into a pet's
    /// history, so the detector can be seen firing without waiting a week.
    func injectAnomaly(for pet: Pet, calendar: Calendar = .current) async {
        let today = calendar.startOfDay(for: .now)

        for offset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            var log = draftLog(for: pet, on: day, calendar: calendar)

            log.day = day
            log.mealsOffered = 2
            log.mealsEaten = offset == 0 ? 0.3 : 0.6      // eating a third to a fifth
            log.energyLevel = 1
            log.mood = .withdrawn
            log.notes = "Simulated decline (demo)."

            if let existing = self.log(for: pet.id, on: day, calendar: calendar) {
                log.id = existing.id
            }

            if let index = logs.firstIndex(where: { $0.petID == pet.id && $0.day == day }) {
                logs[index] = log
            } else {
                logs.append(log)
            }
        }

        logs.sort { $0.day > $1.day }
        persist()
        await runAnalysis()
    }
}
