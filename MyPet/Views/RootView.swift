import SwiftUI

struct RootView: View {

    @Environment(MyPetStore.self) private var store
    @State private var selectedTab: Tab = .dashboard
    @State private var quickLogPet: Pet?

    enum Tab: Hashable {
        case dashboard, pets, tasks, insights, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(onQuickLog: { quickLogPet = $0 })
                .tabItem { Label("Today", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.dashboard)

            PetsView(onQuickLog: { quickLogPet = $0 })
                .tabItem { Label("Pets", systemImage: "pawprint.fill") }
                .tag(Tab.pets)

            TasksView()
                .tabItem { Label("Schedule", systemImage: "checklist") }
                .tag(Tab.tasks)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
                .tag(Tab.insights)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Theme.petAccents[0])
        .sheet(item: $quickLogPet) { pet in
            QuickLogView(pet: pet)
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
