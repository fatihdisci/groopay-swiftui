import SwiftUI

struct DashboardView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var showPaywall = false
    let store: GroupsStore

    private var isPro: Bool {
        authStore.currentProfile?.userPro == true
    }

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            if store.isLoading && store.groups.isEmpty {
                ProgressView().tint(.primaryTheme)
            } else if store.groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        // Genel Bakiye Kartı (herkese açık)
                        overallBalanceCard

                        if isPro {
                            proContent
                        } else {
                            freeTeaser
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("tab.dashboard")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await store.load() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 46))
                .foregroundStyle(Color.textTertiary)

            Text("Henüz hiç grubun yok")
                .font(.display(18, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text("Gruplar sekmesinden bir grup oluştur veya davet koduyla katıl, panelde özetini gör.")
                .font(.body(14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    // MARK: - Overall Balance (herkese açık)

    private var overallBalanceCard: some View {
        let balances = store.overallBalance

        return VStack(spacing: 10) {
            HStack {
                Text("Genel Durumun")
                    .font(.body(12, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }

            if balances.isEmpty {
                Text("Henüz borç/alacak yok")
                    .font(.body(14))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.vertical, 8)
            } else {
                ForEach(balances.keys.sorted(), id: \.self) { currency in
                    let amount = balances[currency, default: 0]
                    HStack {
                        Text(currency)
                            .font(.body(13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                        Spacer()
                        Text(formatAmount(abs(amount), currency: currency))
                            .font(.display(26, weight: .extraBold))
                            .foregroundStyle(.white)
                        Text(amount >= 0 ? "alacaklısın" : "borçlusun")
                            .font(.body(12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color(cssHex: "#4F46E5") ?? .gradientStart,
                    Color(cssHex: "#5B54E8") ?? .gradientEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .purpleTintedShadow(radius: 18, y: 9)
    }

    // MARK: - Pro Content

    @ViewBuilder
    private var proContent: some View {
        // Kategori Analizi
        categorySection

        // Son Aktivite
        recentActivitySection
    }

    // MARK: - Free Teaser

    private var freeTeaser: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.primaryTheme.opacity(0.08))
                    .frame(width: 56, height: 56)

                Image(systemName: "diamond.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.primaryTheme)
            }

            Text("Panel Pro'ya Özel")
                .font(.display(19, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Text("Kategori analizi, harcama trendleri ve detaylı özetler Pro ile kullanılabilir.")
                .font(.body(14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                showPaywall = true
            } label: {
                Text("Pro'ya Geç")
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 220, minHeight: 44)
                    .background(
                        LinearGradient(
                            colors: [.gradientStart, .gradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    // MARK: - Category Analysis

    private var categorySection: some View {
        let stats = categoryStats()

        return VStack(alignment: .leading, spacing: 14) {
            Text("Harcama Kategorileri")
                .font(.display(17, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            if stats.isEmpty {
                Text("Henüz kategori verisi yok.")
                    .font(.body(14))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(stats.prefix(6)) { stat in
                    categoryBar(stat)
                }
            }
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    private func categoryBar(_ stat: CategoryStat) -> some View {
        let maxAmount = categoryStats().first?.amount ?? 1
        let fraction = maxAmount > 0 ? Double(stat.amount) / Double(maxAmount) : 0

        return VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: stat.category.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(stat.category.color)
                    .frame(width: 20)

                Text(stat.category.title)
                    .font(.body(14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text(formatAmount(stat.amount, currency: stat.currency))
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(stat.category.color.opacity(0.12))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(stat.category.color)
                        .frame(
                            width: max(CGFloat(fraction) * geo.size.width, 6),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        let recent = store.activities.prefix(10)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Son Aktiviteler")
                .font(.display(17, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            if recent.isEmpty {
                Text("Henüz aktivite yok.")
                    .font(.body(14))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent)) { activity in
                        dashboardActivityRow(activity)
                        if activity.id != recent.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    private func dashboardActivityRow(_ activity: Activity) -> some View {
        let presentation = ActivityPresentation(
            activity: activity,
            actorName: actorName(activity)
        )

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(presentation.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: presentation.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(presentation.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(groupName(activity.groupId))
                        .font(.body(11, weight: .medium))
                        .foregroundStyle(Color.primaryTheme)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.surfaceTinted)
                        .clipShape(Capsule())

                    if let time = activity.createdAt {
                        Text(timeAgo(time))
                            .font(.body(11))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            Spacer()

            if let amountStr = activityAmount(activity) {
                Text(amountStr)
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Data helpers

    private struct CategoryStat: Identifiable {
        var id: String { category.id }
        let category: ExpenseCategory
        let amount: Int
        let currency: String
    }

    private func categoryStats() -> [CategoryStat] {
        var map: [String: (amount: Int, currency: String, category: ExpenseCategory)] = [:]

        for snapshot in store.groups {
            for expense in snapshot.expenses where expense.deletedAt == nil {
                let cat = ExpenseCategory.find(expense.category)
                let key = "\(expense.currency.uppercased())-\(cat.id)"

                var current = map[key] ?? (0, expense.currency, cat)
                current.0 += expense.amount
                map[key] = current
            }
        }

        return map.values
            .map { CategoryStat(category: $0.category, amount: $0.amount, currency: $0.currency) }
            .sorted { $0.amount > $1.amount }
    }

    private func groupName(_ groupID: UUID) -> String {
        store.groups.first { $0.id == groupID }?.group.name ?? "Grup"
    }

    private func actorName(_ activity: Activity) -> String? {
        guard let actorID = activity.actorMemberId else { return nil }
        for snapshot in store.groups {
            if let member = snapshot.member(id: actorID) {
                return member.displayName
            }
        }
        return nil
    }

    private func activityAmount(_ activity: Activity) -> String? {
        guard let amount = activity.metadata["amount"]?.intValue,
              let currency = activity.metadata["currency"]?.stringValue else {
            return nil
        }
        return formatAmount(amount, currency: currency)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        switch interval {
        case ..<60:
            return "az önce"
        case ..<3600:
            return "\(Int(interval / 60)) dk önce"
        case ..<86400:
            return "\(Int(interval / 3600)) sa önce"
        case ..<604800:
            return "\(Int(interval / 86400)) g önce"
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(store: PreviewSupport.groupsStore)
    }
    .environment(PreviewSupport.authStore)
}
