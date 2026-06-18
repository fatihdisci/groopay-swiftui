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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
    }

    private var groupList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(store.groups) { snapshot in
                    NavigationLink(value: GroupRoute.detail(snapshot.id)) {
                        GroupCard(snapshot: snapshot, balance: selfBalance(snapshot))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 108)
        }
    }

    /// Mevcut kullanıcının bu gruptaki net bakiyesi (sıfır olanlar elenir).
    /// Negatif = borçlu, pozitif = alacaklı.
    private func selfBalance(_ snapshot: GroupSnapshot) -> [String: Int] {
        guard let memberID = store.currentMemberID(in: snapshot.id) else { return [:] }
        return (snapshot.ledgerBalances()[memberID] ?? [:]).filter { $0.value != 0 }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 110)
        .padding(.bottom, 120)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(action: onJoin) {
                joinButtonLabel
                    .foregroundStyle(Color.primaryTheme)
                    .background(Color.background)
                    .overlay {
                        RoundedRectangle(cornerRadius: ThemeRadius.button)
                            .stroke(Color.primaryTheme.opacity(0.35), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
            }

            Button(action: onCreate) {
                createButtonLabel
                    .foregroundStyle(reachedLimit ? Color.textTertiary : Color.primaryTheme)
                    .background(Color.background)
                    .overlay {
                        RoundedRectangle(cornerRadius: ThemeRadius.button)
                            .stroke(
                                reachedLimit ? Color.textTertiary.opacity(0.35) : Color.primaryTheme,
                                lineWidth: 1.2
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.background)
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
    let balance: [String: Int]

    /// Yalnızca kullanıcının borçlu olduğu (negatif) bakiyeler, para birimine
    /// göre ayrı ayrı. Borç yoksa boştur.
    private var debts: [(currency: String, amount: Int)] {
        balance
            .filter { $0.value < 0 }
            .map { (currency: $0.key, amount: $0.value) }
            .sorted { abs($0.amount) > abs($1.amount) }
    }

    var body: some View {
        HStack(spacing: 14) {
            GradientAvatar(
                name: snapshot.group.name,
                emoji: snapshot.group.avatarEmoji,
                color: snapshot.group.avatarColor
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.group.name)
                    .font(.display(17))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text("\(snapshot.activeMembers.count) aktif üye")
                    .font(.body(13))
                    .foregroundStyle(Color.textSecondary)
                debtPills
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

    /// Borç varsa her para birimi için ayrı bir pill; borç yoksa hiçbir şey
    /// gösterilmez.
    @ViewBuilder
    private var debtPills: some View {
        if !debts.isEmpty {
            HStack(spacing: 6) {
                ForEach(debts, id: \.currency) { debt in
                    HStack(spacing: 5) {
                        Text(formatAmount(abs(debt.amount), currency: debt.currency))
                            .font(.body(12, weight: .semibold))
                        Text("borçlusun")
                            .font(.body(11, weight: .medium))
                    }
                    .foregroundStyle(Color.debt)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.debt.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
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
