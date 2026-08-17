import Foundation

/// One day of observations for one pet — the raw material the anomaly engine
/// learns each pet's normal from.
///
/// Exactly one log exists per (pet, day). The quick-entry sheet upserts into the
/// existing day rather than appending, so a carer can add the morning meal and
/// come back at night to add sleep without creating a duplicate.
struct BehaviorLog: Identifiable, Codable, Hashable, Syncable {

    var id: UUID = UUID()
    var petID: UUID

    /// Normalised to the start of the day in the current calendar. Always set
    /// through `init` or `Calendar.startOfDay` so day lookups are exact.
    var day: Date

    // MARK: Intake

    /// Meals put in front of the pet today.
    var mealsOffered: Int = 2

    /// Meals actually finished. Fractional on purpose — "ate about half" is the
    /// single most useful early signal a carer can give us.
    var mealsEaten: Double = 2

    /// Water drunk in millilitres. Optional in practice; `nil` means not observed.
    var waterMl: Double?

    // MARK: Rest and movement

    /// Hours asleep across the whole day, naps included.
    var sleepHours: Double?

    /// Minutes of walks, play or self-directed activity.
    var activityMinutes: Double?

    // MARK: Subjective ratings (1...5)

    /// 1 = flat and unresponsive, 5 = bouncing off the walls.
    var energyLevel: Int = 3

    /// Carer's read on the animal's mood today.
    var mood: Mood = .content

    // MARK: Body

    /// Optional weigh-in. Most days this is `nil`; the baseline handles gaps.
    var weightKg: Double?

    /// Toileting within the pet's normal pattern.
    var eliminationNormal: Bool = true

    /// Free-text carer note. Never fed to the detector — it is for the vet.
    var notes: String = ""

    /// Which carer entered this. Drives the "logged by" line and, in a real
    /// deployment, the per-device sync origin.
    var loggedBy: String = "You"

    // MARK: Sync metadata

    var createdAt: Date = .now
    var updatedAt: Date = .now
    var revision: Int = 1

    init(
        id: UUID = UUID(),
        petID: UUID,
        day: Date,
        mealsOffered: Int = 2,
        mealsEaten: Double = 2,
        waterMl: Double? = nil,
        sleepHours: Double? = nil,
        activityMinutes: Double? = nil,
        energyLevel: Int = 3,
        mood: Mood = .content,
        weightKg: Double? = nil,
        eliminationNormal: Bool = true,
        notes: String = "",
        loggedBy: String = "You",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        revision: Int = 1
    ) {
        self.id = id
        self.petID = petID
        self.day = Calendar.current.startOfDay(for: day)
        self.mealsOffered = mealsOffered
        self.mealsEaten = mealsEaten
        self.waterMl = waterMl
        self.sleepHours = sleepHours
        self.activityMinutes = activityMinutes
        self.energyLevel = energyLevel
        self.mood = mood
        self.weightKg = weightKg
        self.eliminationNormal = eliminationNormal
        self.notes = notes
        self.loggedBy = loggedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revision = revision
    }

    // MARK: Derived

    /// Fraction of offered food actually eaten, clamped to `0...1`.
    /// This — not raw meal count — is what the appetite baseline is built on,
    /// because it stays comparable when a carer changes feeding frequency.
    var appetiteRatio: Double {
        guard mealsOffered > 0 else { return 1 }
        return min(max(mealsEaten / Double(mealsOffered), 0), 1)
    }

    /// Reads one metric out of this log, or `nil` when it was not observed.
    /// The single accessor the feature extractor uses, so adding a metric means
    /// touching exactly one switch.
    func value(for metric: BehaviorMetric) -> Double? {
        switch metric {
        case .appetite: appetiteRatio
        case .water: waterMl
        case .sleep: sleepHours
        case .activity: activityMinutes
        case .energy: Double(energyLevel)
        case .weight: weightKg
        }
    }
}

// MARK: - Mood

enum Mood: String, Codable, CaseIterable, Identifiable, Hashable {
    case playful, content, clingy, withdrawn, restless, irritable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .playful: "Playful"
        case .content: "Content"
        case .clingy: "Clingy"
        case .withdrawn: "Withdrawn"
        case .restless: "Restless"
        case .irritable: "Irritable"
        }
    }

    var emoji: String {
        switch self {
        case .playful: "🎾"
        case .content: "😌"
        case .clingy: "🫂"
        case .withdrawn: "🫥"
        case .restless: "😰"
        case .irritable: "😾"
        }
    }

    /// Moods that, on their own, are worth noticing. Used as a supporting
    /// signal in the distress syndrome — never as a flag on its own, because a
    /// single grumpy afternoon is not a clinical event.
    var isConcerning: Bool {
        switch self {
        case .withdrawn, .restless, .irritable: true
        case .playful, .content, .clingy: false
        }
    }
}

// MARK: - BehaviorMetric

/// The numeric channels the anomaly engine tracks. Each one knows its own
/// units, its display formatting, and — crucially — which direction of change
/// is clinically worrying.
enum BehaviorMetric: String, Codable, CaseIterable, Identifiable, Hashable {
    case appetite, water, sleep, activity, energy, weight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appetite: "Appetite"
        case .water: "Water"
        case .sleep: "Sleep"
        case .activity: "Activity"
        case .energy: "Energy"
        case .weight: "Weight"
        }
    }

    var unit: String {
        switch self {
        case .appetite: "of meals"
        case .water: "ml"
        case .sleep: "h"
        case .activity: "min"
        case .energy: "/ 5"
        case .weight: "kg"
        }
    }

    var symbolName: String {
        switch self {
        case .appetite: "fork.knife"
        case .water: "drop.fill"
        case .sleep: "moon.zzz.fill"
        case .activity: "figure.walk"
        case .energy: "bolt.fill"
        case .weight: "scalemass.fill"
        }
    }

    /// Which direction of deviation from baseline matters clinically.
    var concerningDirection: Direction {
        switch self {
        case .appetite: .below   // eating less is the classic first symptom
        case .water: .both       // polydipsia and dehydration both matter
        case .sleep: .both       // sleeping much more or much less
        case .activity: .below   // lethargy
        case .energy: .below     // lethargy
        case .weight: .both      // loss is worse, but gain matters too
        }
    }

    /// Metrics carers record most days versus occasionally. Sparse metrics get
    /// a longer baseline window so a monthly weigh-in still builds a baseline.
    var isSparse: Bool { self == .weight }

    /// Smallest deviation worth treating as real, in the metric's own units.
    /// Guards against a pet with an unusually rigid routine (tiny MAD) firing
    /// on clinically meaningless wobble.
    var noiseFloor: Double {
        switch self {
        case .appetite: 0.08   // 8% of a day's food
        case .water: 40        // 40 ml
        case .sleep: 0.6       // 36 minutes
        case .activity: 8      // 8 minutes
        case .energy: 0.4      // just under half a rating point
        case .weight: 0.15     // 150 g
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .appetite: "\(Int((value * 100).rounded()))%"
        case .water: "\(Int(value.rounded())) ml"
        case .sleep: String(format: "%.1f h", value)
        case .activity: "\(Int(value.rounded())) min"
        case .energy: String(format: "%.1f / 5", value)
        case .weight: String(format: "%.2f kg", value)
        }
    }

    enum Direction: String, Codable, Hashable {
        case below, above, both

        /// Whether a signed z-score counts as concerning in this direction.
        func admits(_ z: Double) -> Bool {
            switch self {
            case .below: z < 0
            case .above: z > 0
            case .both: true
            }
        }
    }
}
