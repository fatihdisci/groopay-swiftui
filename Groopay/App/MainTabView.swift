import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @State private var groupsStore: GroupsStore
    @State private var realtime = RealtimeManager()

    init(store: GroupsStore = GroupsStore()) {
        _groupsStore = State(initialValue: store)
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                DashboardView(store: groupsStore)
            }
            .tag(MainTab.dashboard)
            .tabItem {
                Label("tab.dashboard", systemImage: "chart.bar.fill")
            }

            NavigationStack(path: $router.groupPath) {
                GroupsView(store: groupsStore)
                    .navigationDestination(for: GroupRoute.self) { route in
                        switch route {
                        case .detail(let groupID):
                            GroupDetailView(groupID: groupID, store: groupsStore)
                        case .members(let groupID):
                            MembersView(groupID: groupID, store: groupsStore)
                        case .edit(let groupID):
                            EditGroupView(groupID: groupID, store: groupsStore)
                        }
                    }
            }
            .tag(MainTab.groups)
            .tabItem {
                Label("tab.groups", systemImage: "person.2.fill")
            }

            NavigationStack {
                ActivityView(store: groupsStore)
            }
            .tag(MainTab.activity)
            .tabItem {
                Label("tab.activity", systemImage: "clock.fill")
            }

            NavigationStack {
                AccountView(store: groupsStore)
            }
            .tag(MainTab.account)
            .tabItem {
                Label("tab.account", systemImage: "person.crop.circle.fill")
            }
        }
        .tint(.primaryTheme)
        .toolbarBackground(Color.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            guard !groupsStore.isUsingPreviewData else { return }
            realtime.attach(groupsStore)
            await groupsStore.load()
        }
        .task(id: groupsStore.groups.map(\.id)) {
            guard !groupsStore.isUsingPreviewData else { return }
            await realtime.sync(groupIDs: groupsStore.groups.map(\.id))
            await PushNotificationService.shared.requestAuthorizationIfNeeded(
                hasGroups: !groupsStore.groups.isEmpty
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .groopayOpenGroup)) { notification in
            guard let groupID = notification.object as? UUID else { return }
            _ = PushNotificationService.consumePendingGroup()
            router.openGroup(groupID)
        }
        .task {
            if let groupID = PushNotificationService.consumePendingGroup() {
                router.openGroup(groupID)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(PreviewSupport.authStore)
        .environment(LocalizationStore())
        .environment(AppRouter())
}
