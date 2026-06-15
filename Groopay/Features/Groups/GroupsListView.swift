import SwiftUI

struct GroupsListView: View {
    @Environment(AuthStore.self) private var authStore
    let store: GroupsStore
    let onJoin: () -> Void
    let onCreate: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.background.ignoresSafeArea()

            SwiftUI.Group {
                if store.isLoading && store.groups.isEmpty {
                    ProgressView()
                        .tint(.primaryTheme)
                } else if store.groups.isEmpty {
                    emptyState
                } else {
                    groupList
                }
            }

            bottomBar
        }
    }

    private var groupList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(store.groups) { snapshot in
                    NavigationLink {
                        GroupDetailView(
                            groupID: snapshot.id,
                            store: store
                        )
                    } label: {
                        GroupCard(snapshot: snapshot)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 108)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 54))
                .foregroundStyle(Color.textTertiary)
            Text("Henüz grubun yok")
                .font(.display(21))
                .foregroundStyle(Color.textPrimary)
            Text("Yeni bir grup oluştur veya davet koduyla katıl.")
                .font(.body(14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 90)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if #available(iOS 26.0, *) {
                Button(action: onJoin) {
                    joinButtonLabel
                }
                .buttonStyle(.glass)
                .tint(.primaryTheme)

                Button(action: onCreate) {
                    createButtonLabel
                }
                .buttonStyle(.glassProminent)
                .tint(reachedLimit ? .textTertiary : .primaryTheme)
            } else {
                Button(action: onJoin) {
                    joinButtonLabel
                        .foregroundStyle(Color.primaryTheme)
                        .background(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: ThemeRadius.button)
                                .stroke(
                                    Color.primaryTheme.opacity(0.35),
                                    lineWidth: 1
                                )
                        }
                        .clipShape(
                            RoundedRectangle(cornerRadius: ThemeRadius.button)
                        )
                }

                Button(action: onCreate) {
                    createButtonLabel
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: reachedLimit
                                    ? [.textTertiary, .textTertiary]
                                    : [.gradientStart, .gradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: ThemeRadius.button)
                        )
                        .purpleTintedShadow(radius: 12, y: 5)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var joinButtonLabel: some View {
        Label(
            "Gruba Katıl",
            systemImage: "rectangle.portrait.and.arrow.right"
        )
        .font(.body(14, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 50)
        .contentShape(Rectangle())
    }

    private var createButtonLabel: some View {
        Label(
            reachedLimit ? "Pro ile Sınırsız" : "Yeni Grup",
            systemImage: reachedLimit ? "lock.fill" : "plus"
        )
        .font(.body(15, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 50)
        .contentShape(Rectangle())
    }

    private var reachedLimit: Bool {
        !(authStore.currentProfile?.userPro ?? false)
            && store.createdNonDemoGroupCount >= 5
    }
}


private struct GroupCard: View {
    let snapshot: GroupSnapshot

    var body: some View {
        HStack(spacing: 14) {
            GradientAvatar(
                name: snapshot.group.name,
                emoji: snapshot.group.avatarEmoji,
                color: snapshot.group.avatarColor
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot.group.name)
                    .font(.display(17))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text("\(snapshot.activeMembers.count) aktif üye")
                    .font(.body(13))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow()
    }
}

#Preview {
    NavigationStack {
        GroupsListView(
            store: PreviewSupport.groupsStore,
            onJoin: {},
            onCreate: {}
        )
    }
    .environment(PreviewSupport.authStore)
}
