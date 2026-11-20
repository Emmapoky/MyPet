// Siri and Shortcuts for MyPet (Lingsha's quick-log idea, FR18). Say "Tell MyPet about
// today" or "Everything normal in MyPet", or add them to the Action button or a Home
// Screen shortcut in the Shortcuts app.
//
// App Intents need no special entitlement, so they work with a free Apple account. The
// answer is written to the same small inbox file the notification uses; MyPet reads it the
// next time it opens (notification_log.dart drainInbox) and shows what it filled in.
import AppIntents
import Foundation

@available(iOS 16.0, *)
enum MyPetInbox {
  /// Same file as main.dart's notificationInbox: Application Support/notification_inbox.jsonl.
  static func save(action: String, input: String?) throws {
    let dir = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let file = dir.appendingPathComponent("notification_inbox.jsonl")
    var row: [String: Any] = [
      "at": ISO8601DateFormatter().string(from: Date()),
      "action": action,
      "pets": [String](),  // empty: every pet; "Tell" splits the words by pet name
    ]
    if let input = input { row["input"] = input }
    var line = try JSONSerialization.data(withJSONObject: row)
    line.append(0x0A)
    if FileManager.default.fileExists(atPath: file.path) {
      let h = try FileHandle(forWritingTo: file)
      defer { try? h.close() }
      try h.seekToEnd()
      try h.write(contentsOf: line)
    } else {
      try line.write(to: file)
    }
  }
}

@available(iOS 16.0, *)
struct TellMyPetIntent: AppIntent {
  static var title: LocalizedStringResource = "Tell MyPet about today"
  static var description = IntentDescription(
    "Say how your pet's day went, like \"Mao ate half her dinner and seemed tired\". MyPet fills in the daily log.")

  @Parameter(title: "How was the day", requestValueDialog: "How was your pet's day?")
  var words: String

  func perform() async throws -> some IntentResult & ProvidesDialog {
    try MyPetInbox.save(action: "tell", input: words)
    return .result(dialog: "Got it. MyPet will add it to today's log.")
  }
}

@available(iOS 16.0, *)
struct AllNormalIntent: AppIntent {
  static var title: LocalizedStringResource = "Everything normal today"
  static var description = IntentDescription(
    "Logs today as a normal day for every pet not logged yet: ate, usual energy, toileting normal.")

  func perform() async throws -> some IntentResult & ProvidesDialog {
    try MyPetInbox.save(action: "all_normal", input: nil)
    return .result(dialog: "Done. Today is logged as a normal day.")
  }
}

@available(iOS 16.0, *)
struct MyPetShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: TellMyPetIntent(),
      phrases: [
        "Tell \(.applicationName) about today",
        "Log my pet in \(.applicationName)",
        "Log in \(.applicationName)",
      ],
      shortTitle: "Tell MyPet",
      systemImageName: "mic.fill")
    AppShortcut(
      intent: AllNormalIntent(),
      phrases: [
        "Everything normal in \(.applicationName)",
        "All normal in \(.applicationName)",
      ],
      shortTitle: "All normal today",
      systemImageName: "checkmark.circle.fill")
  }
}
