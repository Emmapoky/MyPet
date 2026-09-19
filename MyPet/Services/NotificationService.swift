import Foundation
import UserNotifications

/// Schedules the local notifications behind feeding and medication alerts, and
/// the alerts raised by the behaviour detector.
///
/// Two rules shape everything here:
///
/// 1. **iOS allows only 64 pending notifications per app.** With several pets on
///    twice-daily medication that ceiling arrives fast, so we schedule a rolling
///    horizon rather than every future occurrence, and re-arm on each launch.
/// 2. **Alert fatigue is a real failure mode.** A carer who mutes MyPet because
///    it nags gets *no* medication reminders, which is strictly worse than a
///    quieter app. Only `concern` and above produce a behaviour notification,
///    and each flag notifies at most once.
actor NotificationService {

    /// Days ahead to schedule. Comfortably inside the 64-notification budget
    /// for a realistic household while surviving a few days without a launch.
    private let horizonDays = 3

    private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Flags already notified, so re-running the detector does not re-alert.
    private var notifiedFlagKeys: Set<String> = []

    private var center: UNUserNotificationCenter { .current() }

    // MARK: Authorisation

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .authorized : .denied
            return granted
        } catch {
            authorizationStatus = .denied
            return false
        }
    }

    func refreshAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        return authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    // MARK: Care task alerts

    /// Replaces all pending task notifications with the next `horizonDays`
    /// worth, derived from the current task rules.
    ///
    /// Rebuilding wholesale rather than diffing is intentional: a schedule edit
    /// invalidates an unknown subset of pending requests, and a stale
    /// medication reminder is a genuine safety problem. Cancelling everything
    /// and re-deriving is cheap and cannot leave a ghost behind.
    func rescheduleTaskAlerts(tasks: [CareTask], pets: [Pet], now: Date = .now) async {
        guard isAuthorized else { return }

        let existing = await center.pendingNotificationRequests()
        let taskIdentifiers = existing.map(\.identifier).filter { $0.hasPrefix(Identifier.taskPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: taskIdentifiers)

        guard let horizonEnd = Calendar.current.date(byAdding: .day, value: horizonDays, to: now) else { return }
        let interval = DateInterval(start: now, end: horizonEnd)
        let petsByID = Dictionary(uniqueKeysWithValues: pets.map { ($0.id, $0) })

        var scheduled = 0
        let budget = 48   // leaves headroom under the 64 cap for flag alerts

        for task in tasks where task.isActive && task.remindersEnabled {
            guard let pet = petsByID[task.petID] else { continue }

            for occurrence in task.occurrences(in: interval) where !occurrence.isCompleted {
                guard scheduled < budget else { break }
                guard occurrence.dueAt > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(pet.name) · \(task.title)"
                content.body = task.detail.isEmpty
                    ? "Due now (\(task.category.displayName.lowercased()))"
                    : task.detail
                content.sound = task.category.isCritical ? .defaultCritical : .default
                content.threadIdentifier = pet.id.uuidString
                content.userInfo = ["petID": pet.id.uuidString, "taskID": task.id.uuidString]

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: occurrence.dueAt
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

                let request = UNNotificationRequest(
                    identifier: Identifier.task(taskID: task.id, dueAt: occurrence.dueAt),
                    content: content,
                    trigger: trigger
                )

                try? await center.add(request)
                scheduled += 1
            }
        }
    }

    // MARK: Daily logging reminder

    /// The "users stop logging" risk (rated *increased* at Meeting 3). Dr Yam's
    /// answer on 18 Sep: we cannot force anyone to log, but we can remind them.
    /// One gentle nudge at 8 PM on any day not everyone has been logged, for
    /// the next few days. Rebuilt after every log so a finished day stays quiet.
    func rescheduleLogReminders(pets: [Pet], loggedToday: Set<UUID>, now: Date = .now) async {
        guard isAuthorized else { return }

        let existing = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: existing.map(\.identifier).filter { $0.hasPrefix(Identifier.logPrefix) }
        )
        guard !pets.isEmpty else { return }

        let calendar = Calendar.current
        for dayOffset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let fireAt = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day),
                  fireAt > now
            else { continue }

            let missing = dayOffset == 0 ? pets.filter { !loggedToday.contains($0.id) } : pets
            guard !missing.isEmpty else { continue }

            let content = UNMutableNotificationContent()
            content.title = "How were your pets today?"
            content.body = missing.count == 1
                ? "\(missing[0].name) hasn't been logged yet. It takes about 3 taps."
                : "\(missing.map(\.name).joined(separator: " and ")) haven't been logged yet. About 3 taps each."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt),
                repeats: false
            )
            try? await center.add(UNNotificationRequest(
                identifier: "\(Identifier.logPrefix)\(Int(fireAt.timeIntervalSince1970))",
                content: content,
                trigger: trigger
            ))
        }
    }

    // MARK: Behaviour flag alerts

    /// Raises at most one notification per flag, only for `concern` and above.
    func notifyIfNeeded(flags: [BehaviorFlag], pets: [Pet]) async {
        guard isAuthorized else { return }
        let petsByID = Dictionary(uniqueKeysWithValues: pets.map { ($0.id, $0) })

        for flag in flags where flag.severity.warrantsNotification && flag.status == .active {
            let key = "\(flag.dedupeKey)-\(flag.severity.rawValue)"
            guard !notifiedFlagKeys.contains(key) else { continue }
            guard let pet = petsByID[flag.petID] else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(pet.name): \(flag.kind.displayName)"
            content.body = flag.headline
            content.sound = .default
            content.threadIdentifier = pet.id.uuidString
            content.userInfo = ["petID": pet.id.uuidString, "flagID": flag.id.uuidString]

            // Two seconds out rather than immediate, so a burst of flags from
            // one analysis pass arrives as a group instead of a machine-gun.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(
                identifier: Identifier.flag(flagID: flag.id),
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
            notifiedFlagKeys.insert(key)
        }
    }

    /// Lets a resolved flag re-notify if the same syndrome returns later.
    func forgetFlag(_ flag: BehaviorFlag) {
        notifiedFlagKeys = notifiedFlagKeys.filter { !$0.hasPrefix(flag.dedupeKey) }
    }

    // MARK: Diagnostics

    func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    /// Next few pending alerts, shown in Settings so the scheduler's behaviour
    /// is inspectable rather than a black box.
    func pendingSummaries(limit: Int = 8) async -> [String] {
        let requests = await center.pendingNotificationRequests()
        return requests
            .compactMap { request -> (Date, String)? in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let date = trigger.nextTriggerDate() else { return nil }
                return (date, "\(request.content.title) — \(date.formatted(date: .abbreviated, time: .shortened))")
            }
            .sorted { $0.0 < $1.0 }
            .prefix(limit)
            .map(\.1)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        notifiedFlagKeys.removeAll()
    }

    private enum Identifier {
        static let taskPrefix = "task."
        static let flagPrefix = "flag."
        static let logPrefix = "logreminder."

        static func task(taskID: UUID, dueAt: Date) -> String {
            "\(taskPrefix)\(taskID.uuidString).\(Int(dueAt.timeIntervalSince1970))"
        }

        static func flag(flagID: UUID) -> String {
            "\(flagPrefix)\(flagID.uuidString)"
        }
    }
}
