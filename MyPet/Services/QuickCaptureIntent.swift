import AppIntents
import Foundation
import Observation

/// Hands a sentence from Siri or the Shortcuts app to the running app.
///
/// Lingsha's demo ran as a home-screen Shortcut. This keeps that entry point,
/// but the Shortcut now just opens MyPet with the sentence ready to confirm,
/// instead of calling an external AI and writing to the Calendar.
@MainActor
@Observable
final class QuickCaptureInbox {
    static let shared = QuickCaptureInbox()
    var pendingText: String?
    private init() {}
}

struct QuickCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick log for my pet"
    static let description = IntentDescription("Describe your pet's day in one sentence and confirm it in MyPet.")
    static let openAppWhenRun = true

    @Parameter(title: "What happened?", requestValueDialog: "What did your pet do today?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickCaptureInbox.shared.pendingText = text
        return .result()
    }
}

struct MyPetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickCaptureIntent(),
            phrases: [
                "Log my pet in \(.applicationName)",
                "Quick log in \(.applicationName)"
            ],
            shortTitle: "Quick log",
            systemImageName: "pawprint.fill"
        )
    }
}
