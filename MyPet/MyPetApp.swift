import SwiftUI

@main
struct MyPetApp: App {

    /// One store for the whole app, injected into the environment. Every view
    /// reads from it; no view constructs a service of its own.
    @State private var store = MyPetStore()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task {
                    await store.bootstrap()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Coming back to the app is the natural moment to re-score:
                    // a day may have rolled over, or another carer's device may
                    // have logged something while this one was backgrounded.
                    guard phase == .active, store.hasLoaded else { return }
                    Task {
                        await store.syncNow()
                        await store.runAnalysis()
                    }
                }
        }
    }
}
