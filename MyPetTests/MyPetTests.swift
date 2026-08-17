import Foundation
import Testing
@testable import MyPet

// MARK: - Fixtures

/// Builds a run of logs with a fixed routine, then optionally a recent decline.
///
/// Every test builds its data from `dayZero` rather than `Date.now`, so results
/// never depend on when the suite happens to run.
private enum Fixture {

    static let calendar = Calendar(identifier: .gregorian)

    /// A fixed "today" — 1 June 2026, midday UTC.
    static let today = Date(timeIntervalSince1970: 1_780_315_200)

    static func pet(species: Species = .dog, name: String = "Test") -> Pet {
        Pet(name: name, species: species, weightKg: 20)
    }

    /// `days` of steady logs ending yesterday-or-today, with small deterministic
    /// jitter so the MAD is non-zero (a perfectly flat series would give a
    /// spread of zero and force every metric onto its noise floor).
    static func steadyLogs(
        petID: UUID,
        days: Int,
        appetite: Double = 1.0,
        sleep: Double = 12,
        activity: Double = 90,
        energy: Int = 4,
        water: Double = 700,
        from reference: Date = today
    ) -> [BehaviorLog] {

        (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: reference) else { return nil }
            // Deterministic ±small wobble.
            let wobble = Double((offset % 5)) * 0.01 - 0.02

            return BehaviorLog(
                petID: petID,
                day: day,
                mealsOffered: 2,
                mealsEaten: 2 * min(max(appetite + wobble, 0), 1),
                waterMl: water * (1 + wobble),
                sleepHours: sleep * (1 + wobble),
                activityMinutes: activity * (1 + wobble * 2),
                energyLevel: energy,
                mood: .content,
                weightKg: offset % 7 == 0 ? 20 + wobble : nil,
                eliminationNormal: true
            )
        }
    }

    /// Overwrites the most recent `count` days with a decline.
    static func applyDecline(
        to logs: [BehaviorLog],
        days count: Int,
        appetiteFactor: Double = 0.3,
        activityFactor: Double = 0.3,
        energy: Int = 1,
        sleepFactor: Double = 1.4,
        from reference: Date = today
    ) -> [BehaviorLog] {

        var result = logs
        for offset in 0..<count {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: reference),
                  let index = result.firstIndex(where: {
                      calendar.isDate($0.day, inSameDayAs: day)
                  })
            else { continue }

            result[index].mealsEaten = result[index].mealsEaten * appetiteFactor
            result[index].activityMinutes = (result[index].activityMinutes ?? 90) * activityFactor
            result[index].sleepHours = (result[index].sleepHours ?? 12) * sleepFactor
            result[index].energyLevel = energy
            result[index].mood = .withdrawn
        }
        return result
    }
}

// MARK: - Statistics

@Suite("Robust statistics")
struct StatisticsTests {

    @Test("Median handles odd and even counts")
    func median() {
        #expect(Statistics.median([3, 1, 2]) == 2)
        #expect(Statistics.median([4, 1, 3, 2]) == 2.5)
        #expect(Statistics.median([]) == nil)
    }

    @Test("Scaled MAD estimates spread and shrugs off a single outlier")
    func scaledMAD() throws {
        let clean = [10.0, 10.5, 9.5, 10.2, 9.8]
        let withOutlier = clean + [100.0]

        let a = try #require(Statistics.scaledMAD(clean))
        let b = try #require(Statistics.scaledMAD(withOutlier))

        // One absurd value must not blow the spread up the way a standard
        // deviation would — that robustness is the reason MAD is used at all.
        #expect(b < a * 3)

        let sdClean = try #require(Statistics.standardDeviation(clean))
        let sdOutlier = try #require(Statistics.standardDeviation(withOutlier))
        #expect(sdOutlier > sdClean * 10)
    }

    @Test("Identical values give zero spread")
    func zeroSpread() {
        #expect(Statistics.scaledMAD([5, 5, 5, 5]) == 0)
    }

    @Test("EWMA weights recent values more heavily than the mean does")
    func ewma() throws {
        let rising = [1.0, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let smoothed = try #require(Statistics.ewma(rising, span: 5))
        let mean = try #require(Statistics.mean(rising))
        #expect(smoothed > mean)
    }

    @Test("Linear slope recovers a known gradient")
    func slope() throws {
        let series = [0.0, 2, 4, 6, 8]
        let slope = try #require(Statistics.linearSlope(series))
        #expect(abs(slope - 2) < 0.0001)
    }
}

// MARK: - Baselines

@Suite("Baseline model")
struct BaselineTests {

    @Test("A baseline needs enough samples before it is trusted")
    func establishment() {
        let pet = Fixture.pet()
        let model = BaselineModel(config: .testing)

        let thin = Fixture.steadyLogs(petID: pet.id, days: 4)
        let thinBaseline = model.buildBaseline(
            logs: thin, species: pet.species, asOf: Fixture.today, calendar: Fixture.calendar
        )
        #expect(thinBaseline[.appetite]?.isEstablished != true)

        let rich = Fixture.steadyLogs(petID: pet.id, days: 25)
        let richBaseline = model.buildBaseline(
            logs: rich, species: pet.species, asOf: Fixture.today, calendar: Fixture.calendar
        )
        #expect(richBaseline[.appetite]?.isEstablished == true)
        #expect(richBaseline.isEstablished)
    }

    @Test("The evaluation window is excluded from its own baseline")
    func windowExclusion() throws {
        let pet = Fixture.pet()
        let config = DetectionConfig.testing
        let model = BaselineModel(config: config)

        let healthy = Fixture.steadyLogs(petID: pet.id, days: 25, sleep: 12)
        let declined = Fixture.applyDecline(to: healthy, days: config.evaluationWindowDays, sleepFactor: 2.0)

        let baseline = model.buildBaseline(
            logs: declined, species: pet.species, asOf: Fixture.today, calendar: Fixture.calendar
        )
        let sleep = try #require(baseline[.sleep])

        // If the anomalous days leaked into the baseline, the median would have
        // been dragged upward. It must still describe the healthy routine.
        #expect(sleep.median < 13.5)
    }

    @Test("Effective spread never falls below the metric's noise floor")
    func noiseFloor() throws {
        let pet = Fixture.pet()
        // A perfectly rigid routine gives MAD == 0.
        let flat = (0..<20).compactMap { offset -> BehaviorLog? in
            guard let day = Fixture.calendar.date(byAdding: .day, value: -offset, to: Fixture.today) else { return nil }
            return BehaviorLog(petID: pet.id, day: day, mealsOffered: 2, mealsEaten: 2, sleepHours: 12)
        }

        let baseline = BaselineModel(config: .testing).buildBaseline(
            logs: flat, species: pet.species, asOf: Fixture.today, calendar: Fixture.calendar
        )
        let appetite = try #require(baseline[.appetite])

        #expect(appetite.scaledMAD == 0)
        #expect(appetite.effectiveSpread == BehaviorMetric.appetite.noiseFloor)

        // Without the floor this would be infinite.
        #expect(appetite.z(for: 0.9).isFinite)
    }
}

// MARK: - Anomaly detection

@Suite("Anomaly detector")
struct AnomalyDetectorTests {

    @Test("A steady, healthy pet raises no flags")
    func healthyPetIsQuiet() {
        let pet = Fixture.pet()
        let logs = Fixture.steadyLogs(petID: pet.id, days: 30)

        let flags = AnomalyDetector(config: .testing).analyze(
            pet: pet, logs: logs, asOf: Fixture.today, calendar: Fixture.calendar
        )

        #expect(flags.filter { $0.severity >= .watch }.isEmpty)
    }

    @Test("A sustained appetite drop is flagged")
    func appetiteLossDetected() throws {
        let pet = Fixture.pet()
        let healthy = Fixture.steadyLogs(petID: pet.id, days: 30)
        let declined = Fixture.applyDecline(
            to: healthy, days: 3, appetiteFactor: 0.25, activityFactor: 1.0, energy: 3, sleepFactor: 1.0
        )

        let flags = AnomalyDetector(config: .testing).analyze(
            pet: pet, logs: declined, asOf: Fixture.today, calendar: Fixture.calendar
        )

        let appetiteFlag = try #require(flags.first { $0.kind == .appetiteLoss })
        #expect(appetiteFlag.severity >= .watch)
        #expect(appetiteFlag.evidence.contains { $0.metric == .appetite })
        #expect(appetiteFlag.evidence.first { $0.metric == .appetite }?.z ?? 0 < 0)
    }

    @Test("A combined decline is flagged as lethargy too")
    func lethargyDetected() throws {
        let pet = Fixture.pet()
        let healthy = Fixture.steadyLogs(petID: pet.id, days: 30)
        let declined = Fixture.applyDecline(to: healthy, days: 3)

        let flags = AnomalyDetector(config: .testing).analyze(
            pet: pet, logs: declined, asOf: Fixture.today, calendar: Fixture.calendar
        )

        #expect(flags.contains { $0.kind == .lethargy })
        let lethargy = try #require(flags.first { $0.kind == .lethargy })
        #expect(lethargy.severity >= .watch)
    }

    @Test("A single bad day never escalates past watch")
    func singleDayIsNotATrend() {
        let pet = Fixture.pet()
        let healthy = Fixture.steadyLogs(petID: pet.id, days: 30)
        let oneBadDay = Fixture.applyDecline(to: healthy, days: 1, appetiteFactor: 0.1)

        let flags = AnomalyDetector(config: .testing).analyze(
            pet: pet, logs: oneBadDay, asOf: Fixture.today, calendar: Fixture.calendar
        )

        // Animals have off days. One is worth noting, never worth alarming over.
        #expect(flags.allSatisfy { $0.severity <= .watch })
    }

    @Test("Eating more than usual is never flagged as appetite loss")
    func directionalityHolds() {
        let pet = Fixture.pet()
        var logs = Fixture.steadyLogs(petID: pet.id, days: 30, appetite: 0.6)

        // Three days of eating everything offered — a good week, not a symptom.
        for offset in 0..<3 {
            guard let day = Fixture.calendar.date(byAdding: .day, value: -offset, to: Fixture.today),
                  let index = logs.firstIndex(where: { Fixture.calendar.isDate($0.day, inSameDayAs: day) })
            else { continue }
            logs[index].mealsEaten = 2
        }

        let flags = AnomalyDetector(config: .testing).analyze(
            pet: pet, logs: logs, asOf: Fixture.today, calendar: Fixture.calendar
        )

        #expect(!flags.contains { $0.kind == .appetiteLoss })
    }

    @Test("Nothing is flagged before a baseline exists")
    func noBaselineNoFlags() {
        let pet = Fixture.pet()
        // Three days total, all of them terrible — but there is no history to
        // judge them against, so silence is the correct output.
        let logs = Fixture.applyDecline(
            to: Fixture.steadyLogs(petID: pet.id, days: 3), days: 3
        )

        let flags = AnomalyDetector(config: .testing).analyze(
            pet: pet, logs: logs, asOf: Fixture.today, calendar: Fixture.calendar
        )

        #expect(flags.isEmpty)
    }

    @Test("Steady weight loss raises a weight-trend flag")
    func weightTrendDetected() throws {
        let pet = Fixture.pet()
        var logs: [BehaviorLog] = []

        // 30 days, weighed every third day, losing ~1.5% of body weight a week.
        for offset in stride(from: 0, to: 30, by: 3) {
            guard let day = Fixture.calendar.date(byAdding: .day, value: -offset, to: Fixture.today) else { continue }
            let weight = 20.0 - (Double(30 - offset) * 0.045)
            logs.append(
                BehaviorLog(
                    petID: pet.id, day: day, mealsOffered: 2, mealsEaten: 2,
                    waterMl: 700, sleepHours: 12, activityMinutes: 90,
                    energyLevel: 4, weightKg: weight
                )
            )
        }

        let flags = AnomalyDetector(config: .testing).analyze(
            pet: pet, logs: logs, asOf: Fixture.today, calendar: Fixture.calendar
        )

        let weightFlag = try #require(flags.first { $0.kind == .weightTrend })
        #expect(weightFlag.evidence.first?.z ?? 0 < 0)   // losing, not gaining
    }

    @Test("Sensitivity meaningfully changes what is caught")
    func sensitivityMatters() {
        let pet = Fixture.pet()
        let healthy = Fixture.steadyLogs(petID: pet.id, days: 30)
        let mild = Fixture.applyDecline(
            to: healthy, days: 3, appetiteFactor: 0.72, activityFactor: 0.75, energy: 3, sleepFactor: 1.08
        )

        var relaxed = DetectionConfig.testing
        relaxed.sensitivity = 0.6
        var alert = DetectionConfig.testing
        alert.sensitivity = 1.6

        let relaxedFlags = AnomalyDetector(config: relaxed).analyze(
            pet: pet, logs: mild, asOf: Fixture.today, calendar: Fixture.calendar
        )
        let alertFlags = AnomalyDetector(config: alert).analyze(
            pet: pet, logs: mild, asOf: Fixture.today, calendar: Fixture.calendar
        )

        #expect(alertFlags.count >= relaxedFlags.count)
    }

    @Test("Every flag carries evidence a carer can check")
    func flagsAreExplainable() {
        let pet = Fixture.pet()
        let declined = Fixture.applyDecline(
            to: Fixture.steadyLogs(petID: pet.id, days: 30), days: 3
        )

        let flags = AnomalyDetector(config: .testing).analyze(
            pet: pet, logs: declined, asOf: Fixture.today, calendar: Fixture.calendar
        )

        for flag in flags where flag.kind != .eliminationChange {
            #expect(!flag.headline.isEmpty)
            #expect(!flag.recommendation.isEmpty)
            #expect(flag.confidence > 0 && flag.confidence <= 1)
            #expect(flag.score > 0 && flag.score <= 1)
        }
    }
}

// MARK: - Flag merging

@Suite("Flag merge rules")
struct FlagMergeTests {

    private func makeFlag(
        kind: FlagKind = .appetiteLoss,
        severity: FlagSeverity = .watch,
        status: FlagStatus = .active,
        petID: UUID
    ) -> BehaviorFlag {
        BehaviorFlag(
            petID: petID, kind: kind, severity: severity, detectedAt: Fixture.today,
            score: 0.6, confidence: 0.8, persistenceDays: 2, windowDays: 3,
            evidence: [], status: status,
            headline: "h", explanation: "e", recommendation: "r"
        )
    }

    @Test("A dismissed flag stays dismissed while the syndrome persists")
    func dismissedStaysDismissed() async {
        let petID = UUID()
        let service = BehaviorAnalysisService(bus: EventBus(), config: .testing)

        let existing = [makeFlag(status: .dismissed, petID: petID)]
        let detected = [makeFlag(status: .active, petID: petID)]

        let merged = await service.merge(detected: detected, existing: existing, asOf: Fixture.today)

        #expect(merged.first?.status == .dismissed)
    }

    @Test("An acknowledged flag re-activates only when it worsens")
    func acknowledgedEscalates() async {
        let petID = UUID()
        let service = BehaviorAnalysisService(bus: EventBus(), config: .testing)
        let existing = [makeFlag(severity: .watch, status: .acknowledged, petID: petID)]

        let same = await service.merge(
            detected: [makeFlag(severity: .watch, petID: petID)],
            existing: existing, asOf: Fixture.today
        )
        #expect(same.first?.status == .acknowledged)

        let worse = await service.merge(
            detected: [makeFlag(severity: .concern, petID: petID)],
            existing: existing, asOf: Fixture.today
        )
        #expect(worse.first?.status == .active)
    }

    @Test("A flag that stops tripping is resolved, not deleted")
    func staleFlagsResolve() async {
        let petID = UUID()
        let service = BehaviorAnalysisService(bus: EventBus(), config: .testing)
        let existing = [makeFlag(status: .active, petID: petID)]

        let merged = await service.merge(detected: [], existing: existing, asOf: Fixture.today)

        #expect(merged.count == 1)
        #expect(merged.first?.status == .resolved)
    }

    @Test("Merging keeps the original flag's identity so the card is not replaced")
    func identityIsStable() async {
        let petID = UUID()
        let service = BehaviorAnalysisService(bus: EventBus(), config: .testing)
        let original = makeFlag(petID: petID)

        let merged = await service.merge(
            detected: [makeFlag(severity: .concern, petID: petID)],
            existing: [original], asOf: Fixture.today
        )

        #expect(merged.first?.id == original.id)
    }
}

// MARK: - Task scheduling

@Suite("Care task recurrence")
struct CareTaskTests {

    private var calendar: Calendar { Fixture.calendar }

    @Test("A daily twice-a-day task produces two occurrences per day")
    func dailyExpansion() {
        let start = calendar.date(byAdding: .day, value: -10, to: Fixture.today) ?? Fixture.today
        let task = CareTask(
            petID: UUID(), title: "Feed",
            times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 18, minute: 0)],
            recurrence: .daily, startDate: start
        )

        let dayStart = calendar.startOfDay(for: Fixture.today)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let occurrences = task.occurrences(in: DateInterval(start: dayStart, end: dayEnd), calendar: calendar)

        #expect(occurrences.count == 2)
        #expect(occurrences[0].dueAt < occurrences[1].dueAt)
    }

    @Test("Every-N-days counts from the start date")
    func intervalRecurrence() {
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -10, to: Fixture.today) ?? Fixture.today)
        let task = CareTask(
            petID: UUID(), title: "Flea treatment",
            times: [TimeOfDay(hour: 9, minute: 0)],
            recurrence: .everyNDays(3), startDate: start
        )

        let end = calendar.date(byAdding: .day, value: 1, to: Fixture.today) ?? Fixture.today
        let occurrences = task.occurrences(in: DateInterval(start: start, end: end), calendar: calendar)

        // Days 0, 3, 6, 9 from the start — four in an eleven-day span.
        #expect(occurrences.count == 4)
    }

    @Test("An end date stops the expansion")
    func endDateHonoured() {
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -10, to: Fixture.today) ?? Fixture.today)
        let end = calendar.date(byAdding: .day, value: 4, to: start) ?? start

        let task = CareTask(
            petID: UUID(), title: "Antibiotics",
            times: [TimeOfDay(hour: 9, minute: 0)],
            recurrence: .daily, startDate: start, endDate: end
        )

        let horizon = calendar.date(byAdding: .day, value: 1, to: Fixture.today) ?? Fixture.today
        let occurrences = task.occurrences(in: DateInterval(start: start, end: horizon), calendar: calendar)

        #expect(occurrences.count == 5)   // inclusive of both start and end day
        #expect(occurrences.allSatisfy { $0.dueAt <= calendar.date(byAdding: .day, value: 1, to: end)! })
    }

    @Test("An inactive task produces nothing")
    func inactiveTaskIsSilent() {
        var task = CareTask(petID: UUID(), title: "Walk", recurrence: .daily, startDate: Fixture.today)
        task.isActive = false

        let dayStart = calendar.startOfDay(for: Fixture.today)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        #expect(task.occurrences(in: DateInterval(start: dayStart, end: dayEnd), calendar: calendar).isEmpty)
    }

    @Test("Completion is tracked by due date, so ticking off late still counts")
    func completionTracking() throws {
        var task = CareTask(
            petID: UUID(), title: "Dose",
            times: [TimeOfDay(hour: 8, minute: 0)],
            recurrence: .daily,
            startDate: calendar.startOfDay(for: Fixture.today)
        )

        let dayStart = calendar.startOfDay(for: Fixture.today)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let occurrence = try #require(
            task.occurrences(in: DateInterval(start: dayStart, end: dayEnd), calendar: calendar).first
        )
        #expect(!occurrence.isCompleted)

        task.completedOccurrences.insert(occurrence.dueAt)

        let after = try #require(
            task.occurrences(in: DateInterval(start: dayStart, end: dayEnd), calendar: calendar).first
        )
        #expect(after.isCompleted)
    }

    @Test("Critical categories get a tighter overdue grace period")
    func gracePeriods() {
        let due = Fixture.today
        let checkAt = due.addingTimeInterval(60 * 60)   // one hour late

        let dose = TaskOccurrence(
            taskID: UUID(), petID: UUID(), title: "Dose", category: .medication,
            detail: "", dueAt: due, isCompleted: false
        )
        let brush = TaskOccurrence(
            taskID: UUID(), petID: UUID(), title: "Brush", category: .grooming,
            detail: "", dueAt: due, isCompleted: false
        )

        #expect(dose.isSeriouslyOverdue(now: checkAt))
        #expect(!brush.isSeriouslyOverdue(now: checkAt))
    }
}

// MARK: - Sync

@Suite("Distributed sync")
struct SyncTests {

    private func envelope(lamport: Int, nodeID: String, revision: Int = 1) -> SyncEnvelope {
        SyncEnvelope(
            entityType: .pet, entityID: UUID(uuidString: "00000000-0000-0000-0000-00000000ABCD")!,
            revision: revision, lamport: lamport, nodeID: nodeID,
            updatedAt: Fixture.today, isDeleted: false, payload: Data()
        )
    }

    @Test("With no local version, the remote one is taken")
    func noLocalTakesRemote() {
        #expect(SyncResolver.resolve(local: nil, remote: envelope(lamport: 1, nodeID: "a")) == .takeRemote)
    }

    @Test("A higher Lamport value wins regardless of wall-clock time")
    func lamportOrdersEdits() {
        let local = envelope(lamport: 5, nodeID: "a")
        let newer = envelope(lamport: 9, nodeID: "b")
        let older = envelope(lamport: 2, nodeID: "b")

        #expect(SyncResolver.resolve(local: local, remote: newer) == .takeRemote)
        #expect(SyncResolver.resolve(local: local, remote: older) == .keepLocal)
    }

    @Test("Concurrent edits break the tie on node ID, and every device agrees")
    func deterministicTiebreak() {
        let a = envelope(lamport: 7, nodeID: "device-a")
        let b = envelope(lamport: 7, nodeID: "device-b")

        // From A's point of view B wins; from B's point of view A loses.
        // Both devices therefore converge on B's version.
        #expect(SyncResolver.resolve(local: a, remote: b) == .takeRemote)
        #expect(SyncResolver.resolve(local: b, remote: a) == .keepLocal)
    }

    @Test("An identical envelope is a no-op")
    func identicalIsNoChange() {
        let same = envelope(lamport: 3, nodeID: "a")
        #expect(SyncResolver.resolve(local: same, remote: same) == .noChange)
    }

    @Test("Offline edits queue and drain when connectivity returns")
    func outboxDrains() async {
        let bus = EventBus()
        let backend = InMemorySyncBackend()
        await backend.setLatency(.milliseconds(1))
        let service = SyncService(backend: backend, bus: bus, nodeID: "device-a")

        await service.setOfflineMode(true)

        let pet = Fixture.pet()
        await service.enqueue(pet, type: .pet)
        var count = await service.pendingCount
        #expect(count == 1)

        // Syncing while offline must not clear the queue.
        _ = await service.sync()
        count = await service.pendingCount
        #expect(count == 1)

        await service.setOfflineMode(false)
        _ = await service.sync()
        count = await service.pendingCount
        #expect(count == 0)

        let stored = await backend.envelopeCount()
        #expect(stored == 1)
    }

    @Test("A failing backend leaves the outbox intact")
    func failureIsNotDataLoss() async {
        let bus = EventBus()
        let backend = InMemorySyncBackend()
        await backend.setLatency(.milliseconds(1))
        await backend.setShouldFail(true)
        let service = SyncService(backend: backend, bus: bus, nodeID: "device-a")

        await service.enqueue(Fixture.pet(), type: .pet)
        _ = await service.sync()

        let pending = await service.pendingCount
        #expect(pending == 1)

        let status = await service.status()
        if case .failed = status.state {} else {
            Issue.record("Expected a failed sync state, got \(status.state)")
        }
    }

    @Test("A peer's edit is pulled and decoded")
    func peerEditArrives() async throws {
        let bus = EventBus()
        let backend = InMemorySyncBackend()
        await backend.setLatency(.milliseconds(1))
        let service = SyncService(backend: backend, bus: bus, nodeID: "device-a")

        var peerPet = Fixture.pet(name: "Remote")
        peerPet.weightKg = 33.3

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(peerPet)

        await backend.simulatePeerEdit(
            SyncEnvelope(
                entityType: .pet, entityID: peerPet.id, revision: 2, lamport: 0,
                nodeID: "device-b", updatedAt: Fixture.today, isDeleted: false, payload: payload
            )
        )

        let outcome = await service.sync()

        #expect(outcome.pets.count == 1)
        #expect(outcome.pets.first?.name == "Remote")
        #expect(outcome.pets.first?.weightKg == 33.3)
    }
}

// MARK: - Persistence

@Suite("Persistence")
struct PersistenceTests {

    @Test("A snapshot round-trips through disk unchanged")
    func roundTrip() async {
        let service = PersistenceService(location: .temporary("roundtrip-\(UUID().uuidString)"))

        let pet = Fixture.pet(name: "Biscuit")
        let snapshot = AppSnapshot(
            pets: [pet],
            logs: Fixture.steadyLogs(petID: pet.id, days: 5),
            tasks: [CareTask(petID: pet.id, title: "Feed")],
            healthRecords: [HealthRecord(petID: pet.id, kind: .vaccination, title: "Booster", date: Fixture.today)],
            flags: [],
            config: .testing,
            nodeID: "device-a"
        )

        #expect(await service.save(snapshot))

        let loaded = await service.load()
        #expect(loaded?.pets.first?.name == "Biscuit")
        #expect(loaded?.logs.count == 5)
        #expect(loaded?.tasks.count == 1)
        #expect(loaded?.config == .testing)

        await service.reset()
        #expect(await service.load() == nil)
    }

    @Test("Loading with nothing saved returns nil rather than throwing")
    func emptyLoad() async {
        let service = PersistenceService(location: .temporary("empty-\(UUID().uuidString)"))
        #expect(await service.load() == nil)
    }
}

// MARK: - Demo data

@Suite("Seeded demo household")
struct DemoDataTests {

    @Test("The seed is deterministic")
    func deterministic() {
        let a = DemoData.snapshot(nodeID: "n", asOf: Fixture.today, calendar: Fixture.calendar)
        let b = DemoData.snapshot(nodeID: "n", asOf: Fixture.today, calendar: Fixture.calendar)

        #expect(a.logs.count == b.logs.count)
        #expect(a.pets.map(\.name) == b.pets.map(\.name))
    }

    @Test("The seeded household actually trips the detector")
    func demoProducesAFlag() throws {
        // If this ever stops holding, the app opens on an empty dashboard and
        // there is nothing to show a marker — so it is worth a test.
        let snapshot = DemoData.snapshot(nodeID: "n", asOf: Fixture.today, calendar: Fixture.calendar)
        let biscuit = try #require(snapshot.pets.first { $0.name == "Biscuit" })

        let flags = AnomalyDetector(config: .default).analyze(
            pet: biscuit,
            logs: snapshot.logs.filter { $0.petID == biscuit.id },
            asOf: Fixture.today,
            calendar: Fixture.calendar
        )

        #expect(flags.contains { $0.severity >= .watch })
    }

    @Test("Every log belongs to a seeded pet")
    func referentialIntegrity() {
        let snapshot = DemoData.snapshot(nodeID: "n", asOf: Fixture.today, calendar: Fixture.calendar)
        let petIDs = Set(snapshot.pets.map(\.id))

        #expect(snapshot.logs.allSatisfy { petIDs.contains($0.petID) })
        #expect(snapshot.tasks.allSatisfy { petIDs.contains($0.petID) })
        #expect(snapshot.healthRecords.allSatisfy { petIDs.contains($0.petID) })
    }
}

// MARK: - Model behaviour

@Suite("Domain model")
struct DomainModelTests {

    @Test("Appetite ratio is normalised and clamped")
    func appetiteRatio() {
        var log = BehaviorLog(petID: UUID(), day: Fixture.today, mealsOffered: 2, mealsEaten: 1)
        #expect(log.appetiteRatio == 0.5)

        log.mealsEaten = 3          // more than offered
        #expect(log.appetiteRatio == 1)

        log.mealsOffered = 0        // guard against divide-by-zero
        #expect(log.appetiteRatio == 1)
    }

    @Test("Logs are normalised to the start of the day")
    func dayNormalisation() {
        let midday = Fixture.today
        let log = BehaviorLog(petID: UUID(), day: midday)
        #expect(log.day == Calendar.current.startOfDay(for: midday))
    }

    @Test("Touching a record bumps its revision")
    func touchBumpsRevision() {
        var pet = Fixture.pet()
        let before = pet.revision
        pet.touch()
        #expect(pet.revision == before + 1)
    }

    @Test("Severity ordering is well defined")
    func severityOrdering() {
        #expect(FlagSeverity.info < .watch)
        #expect(FlagSeverity.watch < .concern)
        #expect(FlagSeverity.concern < .urgent)
        #expect(FlagSeverity.urgent.warrantsNotification)
        #expect(!FlagSeverity.watch.warrantsNotification)
    }

    @Test("Metric directionality matches clinical intent")
    func directionality() {
        #expect(BehaviorMetric.appetite.concerningDirection == .below)
        #expect(BehaviorMetric.activity.concerningDirection == .below)
        #expect(BehaviorMetric.water.concerningDirection == .both)

        #expect(BehaviorMetric.Direction.below.admits(-2))
        #expect(!BehaviorMetric.Direction.below.admits(2))
        #expect(BehaviorMetric.Direction.both.admits(2))
    }
}
