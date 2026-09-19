import SwiftUI

struct RootView: View {

    @Environment(MyPetStore.self) private var store
    @State private var selectedTab: Tab = RootView.initialTab
    @State private var quickLogPet: Pet?
    @State private var quickCaptureText: QuickCaptureRequest?
    private var inbox = QuickCaptureInbox.shared

    /// Five tabs, with the behaviour check in the middle where Dr Yam pictured
    /// it (18 Sep). Settings moved to the gear on Today to make room.
    enum Tab: Hashable {
        case dashboard, pets, check, tasks, insights
    }

    /// Debug builds accept `-MyPetInitialTab check` (Scheme → Arguments) to
    /// open straight onto a tab, handy for screenshots and demos.
    private static var initialTab: Tab {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "MyPetInitialTab") {
        case "pets": return .pets
        case "check": return .check
        case "tasks": return .tasks
        case "insights": return .insights
        default: return .dashboard
        }
        #else
        return .dashboard
        #endif
    }

    struct QuickCaptureRequest: Identifiable {
        let id = UUID()
        var text: String
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                onQuickLog: { quickLogPet = $0 },
                onQuickCapture: { quickCaptureText = QuickCaptureRequest(text: "") }
            )
                .tabItem { Label("Today", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.dashboard)

            PetsView(onQuickLog: { quickLogPet = $0 })
                .tabItem { Label("Pets", systemImage: "pawprint.fill") }
                .tag(Tab.pets)

            BehaviourCheckView()
                .tabItem { Label("Check", systemImage: "camera.viewfinder") }
                .tag(Tab.check)

            TasksView()
                .tabItem { Label("Schedule", systemImage: "checklist") }
                .tag(Tab.tasks)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                .tag(Tab.insights)

        }
        .tint(Theme.brand)
        .sheet(item: $quickLogPet) { pet in
            QuickLogView(pet: pet)
        }
        .sheet(item: $quickCaptureText) { request in
            QuickCaptureView(initialText: request.text)
        }
        .onAppear {
            #if DEBUG
            if let text = UserDefaults.standard.string(forKey: "MyPetQuickCapture") {
                quickCaptureText = QuickCaptureRequest(text: text)
            }
            #endif
        }
        .onChange(of: inbox.pendingText) { _, text in
            // Arrived from Siri or the Shortcuts app.
            guard let text else { return }
            selectedTab = .dashboard
            quickCaptureText = QuickCaptureRequest(text: text)
            inbox.pendingText = nil
        }
        .overlay(alignment: .top) {
            if !store.hasLoaded {
                loadingBanner
            }
        }
    }

    private var loadingBanner: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Loading your household…")
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
