import SwiftUI

struct GroupsView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var store: GroupsStore
    @State private var presentedSheet: GroupsSheet?

    init(store: GroupsStore = GroupsStore()) {
        _store = State(initialValue: store)
    }

    var body: some View {
        GroupsListView(
            store: store,
            onJoin: { presentedSheet = .join },
            onCreate: handleCreateTap
        )
        .navigationTitle("Gruplar")
        .navigationBarTitleDisplayMode(.inline)
        .tipsButton()
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .new:
                NewGroupSheet(store: store)
                    .presentationDetents([.medium])
                    .presentationCornerRadius(24)
                    .presentationDragIndicator(.visible)
            case .join:
                NavigationStack {
                    JoinGroupView(store: store)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $store.presentedPaywall) {
            PaywallView()
        }
        .alert(
            "Bir sorun oluştu",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.clearError() } }
            )
        ) {
            Button("Tamam", role: .cancel) {
                store.clearError()
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func handleCreateTap() {
        let reachedLimit = !authStore.currentProfile.map(\.userPro, default: false)
            && store.createdNonDemoGroupCount >= 5
        if reachedLimit {
            store.presentedPaywall = true
        } else {
            presentedSheet = .new
        }
    }
}

private enum GroupsSheet: String, Identifiable {
    case new
    case join

    var id: String { rawValue }
}

private extension Optional {
    func map<T>(_ transform: (Wrapped) -> T, default defaultValue: T) -> T {
        self.map(transform) ?? defaultValue
    }
}

#Preview {
    NavigationStack {
        GroupsView(store: PreviewSupport.groupsStore)
    }
    .environment(PreviewSupport.authStore)
}
