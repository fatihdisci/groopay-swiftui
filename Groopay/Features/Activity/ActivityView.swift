import SwiftUI

struct ActivityView: View {
    let store: GroupsStore

    @Environment(AuthStore.self) private var authStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    @State private var searchText = ""
    @State private var debouncedQuery = ""
    @State private var showPaywall = false

    private var isPro: Bool {
        authStore.currentProfile?.userPro ?? false
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            if store.activities.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16, pinnedViews: []) {
                        searchBar
                        ForEach(sections, id: \.key) { section in
                            sectionView(section)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .animation(reduceMotion ? nil : .default, value: debouncedQuery)
                }
            }
        }
        .navigationTitle("Aktivite")
        .navigationBarTitleDisplayMode(.inline)
        .tipsButton()
        .task { await store.load() }
        .refreshable { await store.load() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        // 300ms debounce; yalnızca Pro kullanıcılar arar.
        .task(id: searchText) {
            guard isPro else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            debouncedQuery = searchText
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        ZStack {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.textTertiary)
                TextField("Aktivitede ara", text: $searchText)
                    .font(.body(15))
                    .foregroundStyle(Color.textPrimary)
                    .disabled(!isPro)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        debouncedQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(12)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .blur(radius: isPro ? 0 : 5)

            if !isPro {
                proSearchCTA
            }
        }
    }

    private var proSearchCTA: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("Aramak için Pro'ya geç")
                    .font(.body(13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [.gradientStart, .gradientEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
    }

    // MARK: - Sections (date headers)

    private var filtered: [Activity] {
        let query = debouncedQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: locale)
        guard isPro, !query.isEmpty else { return store.activities }

        return store.activities.filter { activity in
            let presentation = presentation(for: activity)
            let haystack = [
                presentation.title,
                presentation.subtitle ?? "",
                groupName(activity.groupId)
            ]
            .joined(separator: " ")
            .lowercased(with: locale)
            return haystack.contains(query)
        }
    }

    private var sections: [(key: String, items: [Activity])] {
        var order: [String] = []
        var buckets: [String: [Activity]] = [:]
        for activity in filtered {
            let key = Self.dayHeader(for: activity.createdAt, locale: locale)
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(activity)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    private func sectionView(_ section: (key: String, items: [Activity])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.key)
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            VStack(spacing: 0) {
                ForEach(section.items) { activity in
                    ActivityRow(
                        presentation: presentation(for: activity),
                        groupName: groupName(activity.groupId),
                        time: Self.timeString(activity.createdAt, locale: locale)
                    )
                    if activity.id != section.items.last?.id {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
            .purpleTintedShadow()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)
            Text("Henüz aktivite yok")
                .font(.display(20))
                .foregroundStyle(Color.textPrimary)
            Text("Gruplarındaki masraf ve ödemeler burada görünecek.")
                .font(.body(14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Lookups

    private func groupName(_ groupID: UUID) -> String {
        store.groups.first { $0.id == groupID }?.group.name
            ?? String(localized: "Grup", locale: locale)
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

    private func presentation(for activity: Activity) -> ActivityPresentation {
        ActivityPresentation(
            activity: activity,
            actorName: actorName(activity),
            locale: locale
        )
    }

    // MARK: - Date helpers

    private static func dayHeader(for date: Date?, locale: Locale) -> String {
        guard let date else {
            return String(localized: "Tarih yok", locale: locale)
        }
        let calendar = Calendar(identifier: .gregorian)
        if calendar.isDateInToday(date) {
            return String(localized: "Bugün", locale: locale)
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Dün", locale: locale)
        }
        return dayFormatter(locale: locale).string(from: date)
    }

    private static func timeString(_ date: Date?, locale: Locale) -> String {
        guard let date else { return "" }
        return timeFormatter(locale: locale).string(from: date)
    }

    private static func dayFormatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter
    }

    private static func timeFormatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
}

// MARK: - Presentation

struct ActivityPresentation {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String?

    init(
        activity: Activity,
        actorName: String?,
        locale: Locale = LocalizationStore.currentLocale()
    ) {
        let type = activity.actionType.lowercased()
        let who = actorName ?? String(localized: "Birisi", locale: locale)
        let description = activity.metadata["description"]?.stringValue

        if type.contains("expense") {
            icon = "receipt"
            color = .primaryTheme
            let key: String.LocalizationValue
            if type.contains("delete") {
                key = "%@ masraf sildi"
            } else if type.contains("update") {
                key = "%@ masrafı güncelledi"
            } else {
                key = "%@ masraf ekledi"
            }
            title = String(
                format: String(localized: key, locale: locale),
                locale: locale,
                who
            )
            subtitle = description
        } else if type.contains("settle") || type.contains("payment") || type.contains("pay") {
            icon = "checkmark.circle.fill"
            color = .credit
            title = String(
                format: String(localized: "%@ ödeme yaptı", locale: locale),
                locale: locale,
                who
            )
            subtitle = description
        } else if type.contains("join") || type.contains("member") {
            icon = "person.badge.plus"
            color = Color(cssHex: "#8B5CF6") ?? .gradientEnd
            title = String(
                format: String(localized: "%@ gruba katıldı", locale: locale),
                locale: locale,
                who
            )
            subtitle = nil
        } else {
            icon = "bell.fill"
            color = .textSecondary
            title = description ?? activity.actionType
            subtitle = nil
        }
    }
}

private struct ActivityRow: View {
    let presentation: ActivityPresentation
    let groupName: String
    let time: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(presentation.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: presentation.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(presentation.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.title)
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(groupName)
                        .font(.body(11, weight: .medium))
                        .foregroundStyle(Color.primaryTheme)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.surfaceTinted)
                        .clipShape(Capsule())
                    if let subtitle = presentation.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.body(12))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(time)
                .font(.body(11))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

#Preview {
    NavigationStack {
        ActivityView(store: PreviewSupport.groupsStore)
    }
    .environment(PreviewSupport.authStore)
}
