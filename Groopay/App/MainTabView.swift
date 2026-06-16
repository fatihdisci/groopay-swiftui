import SwiftUI

struct MainTabView: View {
    @State private var groupsStore: GroupsStore
    @State private var realtime = RealtimeManager()

    init(store: GroupsStore = GroupsStore()) {
        _groupsStore = State(initialValue: store)
    }

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(store: groupsStore)
            }
            .tabItem {
                Label("tab.dashboard", systemImage: "chart.bar.fill")
            }

            NavigationStack {
                GroupsView(store: groupsStore)
            }
            .tabItem {
                Label("tab.groups", systemImage: "person.2.fill")
            }

            NavigationStack {
                ActivityView(store: groupsStore)
            }
            .tabItem {
                Label("tab.activity", systemImage: "clock.fill")
            }

            NavigationStack {
                AccountView(store: groupsStore)
            }
            .tabItem {
                Label("tab.account", systemImage: "person.crop.circle.fill")
            }
        }
        .tint(.primaryTheme)
        .task {
            guard !groupsStore.isUsingPreviewData else { return }
            realtime.attach(groupsStore)
            await groupsStore.load()
        }
        .task(id: groupsStore.groups.map(\.id)) {
            guard !groupsStore.isUsingPreviewData else { return }
            await realtime.sync(groupIDs: groupsStore.groups.map(\.id))
        }
    }
}

#Preview {
    MainTabView()
        .environment(PreviewSupport.authStore)
        .environment(LocalizationStore())
}
