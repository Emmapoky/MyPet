import Foundation

/// A recurring care commitment — a feed, a dose, a walk, a grooming session.
///
/// A `CareTask` is a *rule*, not a row per day. It expands into `TaskOccurrence`
/// values on demand for whatever date range the UI or the notification scheduler
/// asks for. That keeps storage small and means changing a schedule
/// retroactively fixes every future occurrence at once.
struct CareTask: Identifiable, Codable, Hashable, Syncable {

    var id: UUID = UUID()
    var petID: UUID
    var title: String
    var category: TaskCategory = .feeding

    /// Times of day this task fires, as hour/minute pairs. Two entries means
    /// twice a day.
    var times: [TimeOfDay] = [TimeOfDay(hour: 8, minute: 0)]

    var recurrence: Recurrence = .daily
    var startDate: Date = Calendar.current.startOfDay(for: .now)

    /// Last day the task applies. `nil` means open-ended — a course of
    /// antibiotics sets this, a daily feed does not.
    var endDate: Date?

    /// Dosage or portion detail, shown in the alert body so a carer does not
    /// have to open the app to know what to give.
    var detail: String = ""

    var isActive: Bool = true

    /// Whether to raise a local notification for each occurrence.
    var remindersEnabled: Bool = true

    /// Due dates of occurrences already completed. Storing the *due* date rather
    /// than the completion date makes "did we do the 8am dose?" an O(1) lookup
    /// and stays correct if the carer ticks it off late.
    var completedOccurrences: Set<Date> = []

    // MARK: Sync metadata

    var createdAt: Date = .now
    var updatedAt: Date = .now
    var revision: Int = 1

    // MARK: Occurrence expansion

    /// Every occurrence of this task that falls inside `interval`, in order.
    ///
    /// Returns an empty array for an inactive task or a range that sits entirely
    /// outside `startDate...endDate`.
    func occurrences(in interval: DateInterval, calendar: Calendar = .current) -> [TaskOccurrence] {
        guard isActive else { return [] }

        var results: [TaskOccurrence] = []
        var day = calendar.startOfDay(for: max(interval.start, startDate))
        let lastDay = calendar.startOfDay(for: interval.end)

        // Hard stop so a malformed recurrence can never spin forever.
        var guardCounter = 0
        let maxIterations = 800

        while day <= lastDay && guardCounter < maxIterations {
            guardCounter += 1
            defer { day = calendar.date(byAdding: .day, value: 1, to: day) ?? lastDay.addingTimeInterval(1) }

            if let endDate, day > calendar.startOfDay(for: endDate) { break }
            guard recurrence.includes(day: day, startingFrom: startDate, calendar: calendar) else { continue }

            for time in times {
                guard let due = calendar.date(
                    bySettingHour: time.hour, minute: time.minute, second: 0, of: day
                ) else { continue }
                guard interval.contains(due) else { continue }

                results.append(
                    TaskOccurrence(
                        taskID: id,
                        petID: petID,
                        title: title,
                        category: category,
                        detail: detail,
                        dueAt: due,
                        isCompleted: completedOccurrences.contains(due)
                    )
                )
            }
        }

        return results.sorted { $0.dueAt < $1.dueAt }
    }

    /// The next occurrence at or after `date`, looking up to 60 days ahead.
    func nextOccurrence(after date: Date = .now, calendar: Calendar = .current) -> TaskOccurrence? {
        let horizon = calendar.date(byAdding: .day, value: 60, to: date) ?? date
        return occurrences(in: DateInterval(start: date, end: horizon), calendar: calendar)
            .first { !$0.isCompleted }
    }
}

// MARK: - TimeOfDay

/// A wall-clock time with no date attached. `DateComponents` would work but is
/// noisy to encode and compare; this keeps the JSON readable.
struct TimeOfDay: Codable, Hashable, Comparable, Identifiable {
    var hour: Int
    var minute: Int

    var id: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.id < rhs.id }

    var displayString: String {
        let comps = DateComponents(hour: hour, minute: minute)
        guard let date = Calendar.current.date(from: comps) else { return "\(hour):\(minute)" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Builds a `TimeOfDay` from a `Date`, discarding everything but h:mm.
    init(from date: Date, calendar: Calendar = .current) {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        self.hour = comps.hour ?? 0
        self.minute = comps.minute ?? 0
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Today's date at this time — used to seed date pickers.
    func asDate(calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }
}

// MARK: - Recurrence

enum Recurrence: Codable, Hashable {
    /// Fires once, on `startDate`.
    case once
    case daily
    /// Every `n` days counted from `startDate`.
    case everyNDays(Int)
    /// On the given weekdays, using `Calendar`'s 1 = Sunday convention.
    case weekdays(Set<Int>)

    /// Whether `day` is one this recurrence fires on.
    func includes(day: Date, startingFrom start: Date, calendar: Calendar = .current) -> Bool {
        let startDay = calendar.startOfDay(for: start)
        let target = calendar.startOfDay(for: day)
        guard target >= startDay else { return false }

        switch self {
        case .once:
            return target == startDay

        case .daily:
            return true

        case .everyNDays(let n):
            guard n > 0 else { return false }
            let elapsed = calendar.dateComponents([.day], from: startDay, to: target).day ?? 0
            return elapsed % n == 0

        case .weekdays(let days):
            return days.contains(calendar.component(.weekday, from: target))
        }
    }

    var displayName: String {
        switch self {
        case .once: "Once"
        case .daily: "Every day"
        case .everyNDays(let n): n == 2 ? "Every other day" : "Every \(n) days"
        case .weekdays(let days):
            days.count == 7 ? "Every day" : days.sorted().map(Self.shortWeekdayName).joined(separator: " ")
        }
    }

    static func shortWeekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let index = weekday - 1
        return symbols.indices.contains(index) ? symbols[index] : "?"
    }
}

// MARK: - TaskCategory

enum TaskCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case feeding, medication, walk, grooming, litter, training, vet, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .feeding: "Feeding"
        case .medication: "Medication"
        case .walk: "Walk"
        case .grooming: "Grooming"
        case .litter: "Litter / cage"
        case .training: "Training"
        case .vet: "Vet"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .feeding: "fork.knife"
        case .medication: "pills.fill"
        case .walk: "figure.walk"
        case .grooming: "comb.fill"
        case .litter: "trash.fill"
        case .training: "graduationcap.fill"
        case .vet: "cross.case.fill"
        case .other: "checkmark.circle.fill"
        }
    }

    /// Missing a dose matters more than missing a brush. Drives alert wording
    /// and how prominently an overdue task is surfaced on the dashboard.
    var isCritical: Bool {
        switch self {
        case .medication, .feeding, .vet: true
        case .walk, .grooming, .litter, .training, .other: false
        }
    }
}

// MARK: - TaskOccurrence

/// One concrete firing of a `CareTask` at a specific moment. Derived, never
/// stored — the only persisted part is the due date inside
/// `CareTask.completedOccurrences`.
struct TaskOccurrence: Identifiable, Hashable {
    var taskID: UUID
    var petID: UUID
    var title: String
    var category: TaskCategory
    var detail: String
    var dueAt: Date
    var isCompleted: Bool

    /// Stable across recomputation: same task, same due date, same identity.
    var id: String { "\(taskID.uuidString)-\(dueAt.timeIntervalSince1970)" }

    func isOverdue(now: Date = .now) -> Bool { !isCompleted && dueAt < now }

    /// Overdue by more than the grace period. Feeding and medication get a
    /// tighter grace than the rest.
    func isSeriouslyOverdue(now: Date = .now) -> Bool {
        guard !isCompleted else { return false }
        let grace: TimeInterval = category.isCritical ? 30 * 60 : 3 * 60 * 60
        return now.timeIntervalSince(dueAt) > grace
    }
}
