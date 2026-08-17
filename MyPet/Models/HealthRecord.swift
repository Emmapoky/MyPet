import Foundation

/// A dated entry in a pet's medical history: a jab, a course of medication, a
/// vet visit, a weigh-in, a diagnosed condition.
///
/// Records are append-mostly. Anything with a `nextDueDate` also feeds the
/// dashboard's "coming up" strip, which is how a lapsed booster gets caught.
struct HealthRecord: Identifiable, Codable, Hashable, Syncable {

    var id: UUID = UUID()
    var petID: UUID
    var kind: HealthRecordKind
    var title: String
    var date: Date

    /// When this is due again — booster date, next check-up, end of a course.
    var nextDueDate: Date?

    var detail: String = ""
    var vetClinic: String = ""

    /// Cost in the household's currency. Kept as a plain `Double` because this
    /// is a care log, not an accounting system.
    var cost: Double?

    /// Weight captured at this visit, when the record is a weigh-in.
    var weightKg: Double?

    // MARK: Sync metadata

    var createdAt: Date = .now
    var updatedAt: Date = .now
    var revision: Int = 1

    /// Days until `nextDueDate`, negative when overdue, `nil` when not scheduled.
    func daysUntilDue(from now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let nextDueDate else { return nil }
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: nextDueDate)
        ).day
    }

    var isOverdue: Bool {
        guard let days = daysUntilDue() else { return false }
        return days < 0
    }

    /// Due inside the next month — the window the dashboard surfaces.
    var isDueSoon: Bool {
        guard let days = daysUntilDue() else { return false }
        return days >= 0 && days <= 30
    }
}

// MARK: - HealthRecordKind

enum HealthRecordKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case vaccination, medication, vetVisit, weighIn, condition, procedure, parasiteControl, note

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vaccination: "Vaccination"
        case .medication: "Medication"
        case .vetVisit: "Vet visit"
        case .weighIn: "Weigh-in"
        case .condition: "Condition"
        case .procedure: "Procedure"
        case .parasiteControl: "Parasite control"
        case .note: "Note"
        }
    }

    var symbolName: String {
        switch self {
        case .vaccination: "syringe.fill"
        case .medication: "pills.fill"
        case .vetVisit: "stethoscope"
        case .weighIn: "scalemass.fill"
        case .condition: "heart.text.square.fill"
        case .procedure: "cross.case.fill"
        case .parasiteControl: "ant.fill"
        case .note: "note.text"
        }
    }

    /// Kinds that normally recur, so the editor can offer a sensible default
    /// `nextDueDate` instead of making the carer work it out.
    var suggestedIntervalDays: Int? {
        switch self {
        case .vaccination: 365
        case .parasiteControl: 90
        case .vetVisit: 180
        case .weighIn: 30
        case .medication, .condition, .procedure, .note: nil
        }
    }
}
