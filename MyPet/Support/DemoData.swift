import Foundation

/// A seeded household used on first launch and in previews.
///
/// Realistic data matters more here than it looks. A detector that learns
/// baselines needs weeks of history before it can say anything, so an app that
/// started empty would show nothing interesting until the marker had used it
/// for a fortnight. This seeds ten weeks of plausible daily logs for three
/// animals — and deliberately builds one genuine, detectable decline into
/// Biscuit's last few days, so the anomaly engine has something to find the
/// first time the app opens.
enum DemoData {

    /// Deterministic PRNG, so the seeded household is identical on every
    /// machine. A demo that looks different each launch is impossible to
    /// discuss with a supervisor.
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) { self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

        mutating func next() -> UInt64 {
            // SplitMix64 — small, fast, good enough for demo jitter.
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    static func snapshot(nodeID: String, asOf: Date = .now, calendar: Calendar = .current) -> AppSnapshot {
        var generator = SeededGenerator(seed: 20260817)
        let today = calendar.startOfDay(for: asOf)

        // MARK: Pets

        var biscuit = Pet(
            name: "Biscuit",
            species: .dog,
            breed: "Golden Retriever",
            sex: .female,
            birthDate: calendar.date(byAdding: .year, value: -5, to: today),
            isNeutered: true,
            weightKg: 28.4,
            targetWeightKg: 28.0,
            accentIndex: 0,
            symbolName: "dog.fill",
            microchipID: "982000123456789",
            vetClinic: "Bandar Sunway Veterinary Clinic",
            vetPhone: "+60 3-5622 1234",
            allergies: "Chicken protein — switch to lamb kibble",
            notes: "Nervous around thunder. Hides under the stairs.",
            carers: ["You", "Wei Ling"]
        )

        var mochi = Pet(
            name: "Mochi",
            species: .cat,
            breed: "British Shorthair",
            sex: .male,
            birthDate: calendar.date(byAdding: .month, value: -32, to: today),
            isNeutered: true,
            weightKg: 5.1,
            targetWeightKg: 4.8,
            accentIndex: 1,
            symbolName: "cat.fill",
            microchipID: "982000987654321",
            vetClinic: "Bandar Sunway Veterinary Clinic",
            vetPhone: "+60 3-5622 1234",
            allergies: "",
            notes: "Eats fast, then begs. Weigh monthly — trending over target.",
            carers: ["You", "Wei Ling"]
        )

        var pip = Pet(
            name: "Pip",
            species: .rabbit,
            breed: "Netherland Dwarf",
            sex: .female,
            birthDate: calendar.date(byAdding: .month, value: -14, to: today),
            isNeutered: true,
            weightKg: 1.15,
            targetWeightKg: 1.1,
            accentIndex: 3,
            symbolName: "hare.fill",
            microchipID: "",
            vetClinic: "Exotic Pet Care PJ",
            vetPhone: "+60 3-7877 5566",
            allergies: "",
            notes: "Gut stasis risk — any drop in eating or droppings is urgent for rabbits.",
            carers: ["You"]
        )

        biscuit.createdAt = calendar.date(byAdding: .day, value: -80, to: today) ?? today
        mochi.createdAt = biscuit.createdAt
        pip.createdAt = calendar.date(byAdding: .day, value: -50, to: today) ?? today

        let pets = [biscuit, mochi, pip]

        // MARK: Logs

        var logs: [BehaviorLog] = []
        logs += generateLogs(
            for: biscuit,
            days: 70,
            today: today,
            calendar: calendar,
            generator: &generator,
            profile: .init(appetite: 0.94, water: 780, sleep: 12.4, activity: 96, energy: 4, weight: 28.4),
            // The story: appetite and energy fall away over the last four days
            // while sleep creeps up. That is a textbook lethargy-plus-appetite
            // presentation, and it is what the dashboard will flag on launch.
            decline: .init(startDaysAgo: 4, appetiteFactor: 0.42, activityFactor: 0.35,
                           energyDrop: 2, sleepFactor: 1.28, moodOverride: .withdrawn)
        )

        logs += generateLogs(
            for: mochi,
            days: 70,
            today: today,
            calendar: calendar,
            generator: &generator,
            profile: .init(appetite: 0.98, water: 220, sleep: 15.1, activity: 42, energy: 3, weight: 4.9),
            // Mochi is healthy day to day, but slowly gaining — the weight-trend
            // rule catches this where day-level scoring never would.
            decline: nil,
            weightDriftPerDay: 0.0055
        )

        logs += generateLogs(
            for: pip,
            days: 45,
            today: today,
            calendar: calendar,
            generator: &generator,
            profile: .init(appetite: 0.96, water: 190, sleep: 11.0, activity: 58, energy: 4, weight: 1.15),
            decline: nil
        )

        // MARK: Care tasks

        let tasks: [CareTask] = [
            CareTask(
                petID: biscuit.id,
                title: "Breakfast",
                category: .feeding,
                times: [TimeOfDay(hour: 7, minute: 30)],
                recurrence: .daily,
                startDate: calendar.date(byAdding: .day, value: -70, to: today) ?? today,
                detail: "One cup lamb kibble"
            ),
            CareTask(
                petID: biscuit.id,
                title: "Dinner",
                category: .feeding,
                times: [TimeOfDay(hour: 18, minute: 30)],
                recurrence: .daily,
                startDate: calendar.date(byAdding: .day, value: -70, to: today) ?? today,
                detail: "One cup lamb kibble"
            ),
            CareTask(
                petID: biscuit.id,
                title: "Joint supplement",
                category: .medication,
                times: [TimeOfDay(hour: 7, minute: 45)],
                recurrence: .daily,
                startDate: calendar.date(byAdding: .day, value: -30, to: today) ?? today,
                detail: "1 chew with breakfast"
            ),
            CareTask(
                petID: biscuit.id,
                title: "Evening walk",
                category: .walk,
                times: [TimeOfDay(hour: 19, minute: 15)],
                recurrence: .daily,
                startDate: calendar.date(byAdding: .day, value: -70, to: today) ?? today,
                detail: "30–40 minutes"
            ),
            CareTask(
                petID: mochi.id,
                title: "Wet food",
                category: .feeding,
                times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 19, minute: 0)],
                recurrence: .daily,
                startDate: calendar.date(byAdding: .day, value: -70, to: today) ?? today,
                detail: "Half a pouch, weight-control formula"
            ),
            CareTask(
                petID: mochi.id,
                title: "Litter tray",
                category: .litter,
                times: [TimeOfDay(hour: 21, minute: 0)],
                recurrence: .daily,
                startDate: calendar.date(byAdding: .day, value: -70, to: today) ?? today,
                detail: "Scoop and top up"
            ),
            CareTask(
                petID: mochi.id,
                title: "Flea treatment",
                category: .medication,
                times: [TimeOfDay(hour: 20, minute: 0)],
                recurrence: .everyNDays(30),
                startDate: calendar.date(byAdding: .day, value: -20, to: today) ?? today,
                detail: "Spot-on, between the shoulder blades"
            ),
            CareTask(
                petID: pip.id,
                title: "Hay and greens",
                category: .feeding,
                times: [TimeOfDay(hour: 8, minute: 15), TimeOfDay(hour: 18, minute: 45)],
                recurrence: .daily,
                startDate: calendar.date(byAdding: .day, value: -45, to: today) ?? today,
                detail: "Unlimited timothy hay, one cup greens"
            ),
            CareTask(
                petID: pip.id,
                title: "Nail check",
                category: .grooming,
                times: [TimeOfDay(hour: 11, minute: 0)],
                recurrence: .weekdays([1]),   // Sundays
                startDate: calendar.date(byAdding: .day, value: -45, to: today) ?? today,
                detail: "Trim if needed"
            )
        ]

        // MARK: Health records

        let records: [HealthRecord] = [
            HealthRecord(
                petID: biscuit.id,
                kind: .vaccination,
                title: "C5 annual booster",
                date: calendar.date(byAdding: .day, value: -300, to: today) ?? today,
                nextDueDate: calendar.date(byAdding: .day, value: 65, to: today),
                detail: "Distemper, hepatitis, parvo, parainfluenza, bordetella",
                vetClinic: "Bandar Sunway Veterinary Clinic",
                cost: 180
            ),
            HealthRecord(
                petID: biscuit.id,
                kind: .condition,
                title: "Early hip dysplasia",
                date: calendar.date(byAdding: .day, value: -35, to: today) ?? today,
                detail: "Mild, left hip. Joint supplement started. Keep walks flat and regular.",
                vetClinic: "Bandar Sunway Veterinary Clinic"
            ),
            HealthRecord(
                petID: biscuit.id,
                kind: .weighIn,
                title: "Routine weigh-in",
                date: calendar.date(byAdding: .day, value: -12, to: today) ?? today,
                nextDueDate: calendar.date(byAdding: .day, value: 18, to: today),
                vetClinic: "Bandar Sunway Veterinary Clinic",
                weightKg: 28.4
            ),
            HealthRecord(
                petID: mochi.id,
                kind: .parasiteControl,
                title: "Spot-on flea and tick",
                date: calendar.date(byAdding: .day, value: -20, to: today) ?? today,
                nextDueDate: calendar.date(byAdding: .day, value: 10, to: today),
                detail: "Monthly, between the shoulder blades",
                cost: 45
            ),
            HealthRecord(
                petID: mochi.id,
                kind: .vetVisit,
                title: "Weight-management review",
                date: calendar.date(byAdding: .day, value: -6, to: today) ?? today,
                nextDueDate: calendar.date(byAdding: .day, value: 84, to: today),
                detail: "Vet flagged gradual gain. Switched to weight-control formula, halved treats.",
                vetClinic: "Bandar Sunway Veterinary Clinic",
                cost: 120,
                weightKg: 5.1
            ),
            HealthRecord(
                petID: pip.id,
                kind: .vaccination,
                title: "RHDV2 vaccination",
                date: calendar.date(byAdding: .day, value: -140, to: today) ?? today,
                nextDueDate: calendar.date(byAdding: .day, value: -3, to: today),   // deliberately overdue
                detail: "Rabbit haemorrhagic disease. Annual.",
                vetClinic: "Exotic Pet Care PJ",
                cost: 95
            ),
            HealthRecord(
                petID: pip.id,
                kind: .note,
                title: "Gut stasis warning signs",
                date: calendar.date(byAdding: .day, value: -45, to: today) ?? today,
                detail: "Rabbits must eat continuously. Any refusal of food, or no droppings for 12 hours, is an emergency — call the exotics vet immediately, do not wait."
            )
        ]

        // Bring each pet's headline weight into line with its final log.
        for index in pets.indices {
            let pet = pets[index]
            if let latest = logs.filter({ $0.petID == pet.id }).sorted(by: { $0.day > $1.day })
                .compactMap(\.weightKg).first {
                switch pet.id {
                case biscuit.id: biscuit.weightKg = latest
                case mochi.id: mochi.weightKg = latest
                case pip.id: pip.weightKg = latest
                default: break
                }
            }
        }

        return AppSnapshot(
            pets: [biscuit, mochi, pip],
            logs: logs.sorted { $0.day > $1.day },
            tasks: tasks,
            healthRecords: records.sorted { $0.date > $1.date },
            flags: [],
            config: .default,
            nodeID: nodeID,
            lamport: 0
        )
    }

    // MARK: - Log generation

    /// The healthy centre of a pet's routine.
    private struct Profile {
        var appetite: Double
        var water: Double
        var sleep: Double
        var activity: Double
        var energy: Int
        var weight: Double
    }

    /// A deliberate decline built into the most recent days.
    private struct Decline {
        var startDaysAgo: Int
        var appetiteFactor: Double
        var activityFactor: Double
        var energyDrop: Int
        var sleepFactor: Double
        var moodOverride: Mood
    }

    private static func generateLogs(
        for pet: Pet,
        days: Int,
        today: Date,
        calendar: Calendar,
        generator: inout SeededGenerator,
        profile: Profile,
        decline: Decline?,
        weightDriftPerDay: Double = 0
    ) -> [BehaviorLog] {

        var results: [BehaviorLog] = []

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }

            // Carers miss days. Roughly one day in nine has no entry, which also
            // exercises the model's gap handling rather than pretending data is
            // ever complete.
            if offset > 0 && Int.random(in: 0..<9, using: &generator) == 0 { continue }

            let inDecline = decline.map { offset < $0.startDaysAgo } ?? false

            // Drawn one at a time rather than through a helper closure: a
            // closure would have to capture `generator` inout, which Swift
            // rightly refuses.
            let appetiteJitter = Double.random(in: -0.06...0.06, using: &generator)
            let activityJitter = Double.random(in: -0.18...0.18, using: &generator)
            let sleepJitter = Double.random(in: -0.9...0.9, using: &generator)
            let waterJitter = Double.random(in: -0.12...0.12, using: &generator)
            let weightJitter = Double.random(in: -0.06...0.06, using: &generator)

            var appetite = profile.appetite + appetiteJitter
            var activity = profile.activity * (1 + activityJitter)
            var sleep = profile.sleep + sleepJitter
            var energy = profile.energy
            var mood: Mood = Bool.random(using: &generator) ? .content : .playful
            let water = profile.water * (1 + waterJitter)

            if inDecline, let decline {
                appetite *= decline.appetiteFactor
                activity *= decline.activityFactor
                sleep *= decline.sleepFactor
                energy = max(1, energy - decline.energyDrop)
                mood = decline.moodOverride
            }

            let mealsOffered = 2
            let mealsEaten = (Double(mealsOffered) * min(max(appetite, 0), 1) * 10).rounded() / 10

            // Weigh-ins are sparse in real life — roughly weekly here, which is
            // exactly the sparsity the weight baseline is designed to survive.
            let weighInToday = offset % 7 == 0
            let weight = weighInToday
                ? ((profile.weight + weightDriftPerDay * Double(days - offset) + weightJitter) * 100).rounded() / 100
                : nil

            results.append(
                BehaviorLog(
                    petID: pet.id,
                    day: day,
                    mealsOffered: mealsOffered,
                    mealsEaten: mealsEaten,
                    waterMl: (water).rounded(),
                    sleepHours: (sleep * 10).rounded() / 10,
                    activityMinutes: activity.rounded(),
                    energyLevel: min(max(energy, 1), 5),
                    mood: mood,
                    weightKg: weight,
                    eliminationNormal: !(inDecline && offset < 2),
                    notes: "",
                    loggedBy: Bool.random(using: &generator) ? "You" : (pet.carers.last ?? "You"),
                    createdAt: day,
                    updatedAt: day
                )
            )
        }

        return results
    }
}
