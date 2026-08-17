import Foundation
import SwiftUI

/// Everything a household needs to know about one animal.
///
/// `Pet` is the root aggregate of the domain: care tasks, behaviour logs, health
/// records and behaviour flags all hang off a `Pet.id`. It carries the sync
/// metadata (`revision`, `updatedAt`) that `SyncService` uses to resolve
/// conflicts when two carers edit the same pet from different devices.
struct Pet: Identifiable, Codable, Hashable, Syncable {

    // MARK: Identity

    var id: UUID = UUID()
    var name: String
    var species: Species
    var breed: String = ""
    var sex: Sex = .unknown
    var birthDate: Date?
    var isNeutered: Bool = false

    // MARK: Physical

    /// Current weight in kilograms. Weigh-ins also land in `HealthRecord`, but
    /// this field is the fast read for the dashboard.
    var weightKg: Double = 0

    /// The weight the vet considers healthy, used to colour the weight readout.
    var targetWeightKg: Double?

    // MARK: Presentation

    /// Index into `Theme.petAccents` — keeps `Pet` free of any `Color`, which is
    /// not `Codable`, while still letting each pet own a colour.
    var accentIndex: Int = 0

    /// SF Symbol name used as the pet's avatar when no photo is set.
    var symbolName: String = "pawprint.fill"

    // MARK: Care context

    var microchipID: String = ""
    var vetClinic: String = ""
    var vetPhone: String = ""
    var allergies: String = ""
    var notes: String = ""

    /// Carers who share this pet. In a real deployment these are account IDs;
    /// here they are display names, and they make the multi-carer story visible.
    var carers: [String] = ["You"]

    // MARK: Sync metadata

    var createdAt: Date = .now
    var updatedAt: Date = .now
    var revision: Int = 1

    // MARK: Derived

    var accent: Color { Theme.petAccents[accentIndex % Theme.petAccents.count] }

    /// Age in whole years and months, or `nil` when no birth date is recorded.
    var age: (years: Int, months: Int)? {
        guard let birthDate else { return nil }
        let parts = Calendar.current.dateComponents([.year, .month], from: birthDate, to: .now)
        return (parts.year ?? 0, parts.month ?? 0)
    }

    var ageDescription: String {
        guard let age else { return "Age unknown" }
        if age.years == 0 { return age.months == 1 ? "1 month old" : "\(age.months) months old" }
        if age.months == 0 { return age.years == 1 ? "1 year old" : "\(age.years) years old" }
        return "\(age.years)y \(age.months)m"
    }

    /// How far the pet sits from its target weight, as a signed fraction.
    /// `+0.1` means 10% over target. `nil` when no target is set.
    var weightDeviationFraction: Double? {
        guard let targetWeightKg, targetWeightKg > 0 else { return nil }
        return (weightKg - targetWeightKg) / targetWeightKg
    }
}

// MARK: - Species

enum Species: String, Codable, CaseIterable, Identifiable, Hashable {
    case dog, cat, rabbit, bird, reptile, smallMammal, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dog: "Dog"
        case .cat: "Cat"
        case .rabbit: "Rabbit"
        case .bird: "Bird"
        case .reptile: "Reptile"
        case .smallMammal: "Small mammal"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .dog: "dog.fill"
        case .cat: "cat.fill"
        case .rabbit: "hare.fill"
        case .bird: "bird.fill"
        case .reptile: "lizard.fill"
        case .smallMammal: "tortoise.fill"
        case .other: "pawprint.fill"
        }
    }

    /// Typical daily sleep, used only to seed a baseline before the pet has
    /// enough of its own history. Individual baselines replace these fast.
    var typicalSleepHours: Double {
        switch self {
        case .dog: 12.5
        case .cat: 15.0
        case .rabbit: 11.0
        case .bird: 11.0
        case .reptile: 13.0
        case .smallMammal: 12.0
        case .other: 12.0
        }
    }

    /// Typical daily active minutes, same seeding role as `typicalSleepHours`.
    var typicalActivityMinutes: Double {
        switch self {
        case .dog: 90
        case .cat: 45
        case .rabbit: 60
        case .bird: 60
        case .reptile: 20
        case .smallMammal: 40
        case .other: 50
        }
    }
}

// MARK: - Sex

enum Sex: String, Codable, CaseIterable, Identifiable, Hashable {
    case male, female, unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        case .unknown: "Unknown"
        }
    }
}

// MARK: - Syncable

/// The contract `SyncService` needs from any record it replicates: stable
/// identity plus a monotonically increasing revision and a wall-clock stamp.
protocol Syncable: Identifiable, Codable where ID == UUID {
    var id: UUID { get }
    var updatedAt: Date { get set }
    var revision: Int { get set }
}

extension Syncable {
    /// Stamps a local edit so the sync layer can order it against remote edits.
    mutating func touch(now: Date = .now) {
        updatedAt = now
        revision += 1
    }
}
