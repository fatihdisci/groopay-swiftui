import SwiftUI

struct MainTabView: View {
    @State private var groupsStore = GroupsStore()
    @State private var realtime = RealtimeManager()

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
            realtime.attach(groupsStore)
            await groupsStore.load()
        }
        .task(id: groupsStore.groups.map(\.id)) {
            await realtime.sync(groupIDs: groupsStore.groups.map(\.id))
        }
    }
}

#Preview {
    MainTabView()
        .environment(PreviewSupport.authStore)
}
