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
                    ScrollView { SkeletonList() }
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
                    NavigationLink(value: GroupRoute.detail(snapshot.id, section: nil)) {
                        GroupCard(
                            snapshot: snapshot,
                            status: GroupCardStatus.make(
                                snapshot: snapshot,
                                userID: store.currentUserID
                            )
                        )
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
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.08))
                    .frame(width: 88, height: 88)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.brand)
            }

            VStack(spacing: 6) {
                Text("Henüz grubun yok")
                    .font(.display(21))
                    .foregroundStyle(Color.textPrimary)
                Text("Arkadaşlarınla ortak harcamaları bölüşmek için bir grup oluştur.")
                    .font(.body(14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Ghost üye bilgi kartı
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.themeAccent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Uygulamada olmayan arkadaşlarını da ekleyebilirsin")
                        .font(.body(13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Hayalet üye olarak ekle, borç/alacak takibi yap. Uygulamaya katıldıklarında hesapları otomatik eşleşir.")
                        .font(.body(11))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(14)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.soft))
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 80)
        .padding(.bottom, 120)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if !authStore.hasProAccess {
                limitMessage
            }

            HStack(spacing: 12) {
                Button(action: onJoin) {
                    joinButtonLabel
                        .foregroundStyle(Color.primaryTheme)
                        .background(Color.background)
                        .overlay {
                            RoundedRectangle(cornerRadius: ThemeRadius.button)
                                .stroke(Color.primaryTheme, lineWidth: 1.2)
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.background)
    }

    private var limitMessage: some View {
        let used = min(store.createdActiveNonDemoGroupCount, GroupsStore.freeCreatedGroupLimit)
        let remaining = max(GroupsStore.freeCreatedGroupLimit - used, 0)
        let text = reachedLimit
            ? String(localized: "10/10 grup hakkını kullandın. Pro ile sınırsız grup oluştur.")
            : String(
                format: String(localized: "%lld/10 grup oluşturdun · %lld hakkın kaldı"),
                Int64(used),
                Int64(remaining)
            )

        return HStack(spacing: 8) {
            Image(systemName: reachedLimit ? "lock.fill" : "person.2.badge.plus")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.body(12, weight: .medium))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
        .foregroundStyle(reachedLimit ? Color.warning : Color.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background((reachedLimit ? Color.warning : Color.primaryTheme).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
    }

    private var joinButtonLabel: some View {
        Label(
            "Gruba Katıl",
            systemImage: "rectangle.portrait.and.arrow.right"
        )
        .font(.body(15, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 50)
        .contentShape(Rectangle())
    }

    private var createButtonLabel: some View {
        Label(
            reachedLimit ? "Pro ile Sınırsız Grup" : "Yeni Grup",
            systemImage: reachedLimit ? "lock.fill" : "plus"
        )
        .font(.body(15, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 50)
        .contentShape(Rectangle())
    }

    private var reachedLimit: Bool {
        !authStore.hasProAccess
            && store.createdActiveNonDemoGroupCount >= GroupsStore.freeCreatedGroupLimit
    }
}


private struct GroupCard: View {
    let snapshot: GroupSnapshot
    let status: GroupCardStatus
    @Environment(\.locale) private var locale

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
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text("\(snapshot.activeMembers.count) aktif üye")
                    .font(.body(13))
                    .foregroundStyle(Color.textSecondary)
                statusView
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
    }

    /// Sıfır bakiye → "Ödeştiniz"; aksi halde her para birimi için ayrı satır.
    /// Renk + kelime + SF Symbol birlikte; işaret (+/-) yok.
    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .settled:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Ödeştiniz")
                    .font(.body(12, weight: .semibold))
            }
            .foregroundStyle(Color.credit)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.credit.opacity(0.12))
            .clipShape(Capsule())
        case let .lines(lines):
            // Büyük Dynamic Type'ta yatay taşmayı önlemek için akışkan grid.
            FlowLines(lines: lines)
        }
    }

    private struct FlowLines: View {
        let lines: [GroupBalanceLine]

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(lines) { line in
                    pill(for: line)
                }
            }
        }

        private func pill(for line: GroupBalanceLine) -> some View {
            let color = line.kind == .debt ? Color.debt : Color.credit
            let icon = line.kind == .debt ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
            return HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                if line.kind == .debt {
                    Text("Borcun")
                        .font(.body(11, weight: .medium))
                } else {
                    Text("Alacağın")
                        .font(.body(11, weight: .medium))
                }
                Text(formatAmount(line.amount, currency: line.currency))
                    .font(.body(12, weight: .semibold))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    /// VoiceOver tek anlaşılır özet okur: grup adı + üye sayısı + durum.
    private var accessibilitySummary: Text {
        let name = snapshot.group.name
        let memberInfo = String(
            format: String(localized: "%lld aktif üye", locale: locale),
            locale: locale,
            Int64(snapshot.activeMembers.count)
        )
        switch status {
        case .settled:
            let settled = String(localized: "Ödeştiniz", locale: locale)
            return Text(verbatim: "\(name), \(memberInfo), \(settled)")
        case let .lines(lines):
            let parts = lines.map { line -> String in
                let amount = formatAmount(line.amount, currency: line.currency)
                let direction = line.kind == .debt
                    ? String(localized: "Borcun", locale: locale)
                    : String(localized: "Alacağın", locale: locale)
                return "\(direction) \(amount)"
            }
            return Text(verbatim: "\(name), \(memberInfo), " + parts.joined(separator: ", "))
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
