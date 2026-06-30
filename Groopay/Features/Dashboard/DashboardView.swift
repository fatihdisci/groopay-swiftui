import SwiftUI

struct DashboardView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(AppRouter.self) private var router
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showPaywall = false
    @State private var selectedTimeFilter: TimeFilter = .month
    @State private var selectedDonutCurrency: String?
    @State private var selectedDonutSegment: Int?
    @State private var isRecentActivityExpanded = false
    @State private var activitySearchText = ""
    @State private var debouncedActivitySearchText = ""
    @State private var activityFilter = ActivityFilter()
    let store: GroupsStore

    private var isPro: Bool {
        authStore.hasProAccess
    }

    /// Kullanıcı en az bir masraf eklemiş mi? Endowment etkisi için teaser metnini değiştirir.
    private var hasAnyExpense: Bool {
        store.groups.contains { !$0.expenses.isEmpty }
    }

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            if store.isLoading && store.groups.isEmpty {
                dashboardSkeleton
            } else if store.groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        // 1) Bakiyem (herkese açık)
                        overallBalanceCard

                        // 2) Yapmam gerekenler (herkese açık)
                        actionCenterSection

                        // 3) Kategori dağılımı (herkese açık)
                        timeFilterPicker
                        donutSection
                        categorySection

                        // 4) Gelişmiş analitik (Pro)
                        if isPro {
                            proAnalyticsContent
                        } else {
                            lockedAnalyticsPreview
                        }

                        // 5) Son aktiviteler (herkese açık)
                        recentActivitySection
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle(AppLocalization.string("tab.dashboard", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .tipsButton()
        .refreshable { await store.load() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: selectedTimeFilter) { _, _ in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                selectedDonutSegment = nil
                selectedDonutCurrency = defaultDonutCurrency
                activitySearchText = ""
                debouncedActivitySearchText = ""
            }
        }
        .task(id: activitySearchText) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            debouncedActivitySearchText = activitySearchText
        }
    }

    // MARK: - Skeleton (ilk yükleme)

    private var dashboardSkeleton: some View {
        ScrollView {
            VStack(spacing: 18) {
                SkeletonBlock(height: 120, cornerRadius: 20)
                SkeletonBlock(height: 90, cornerRadius: 16)
                SkeletonBlock(height: 220, cornerRadius: 16)
                SkeletonBlock(height: 160, cornerRadius: 16)
            }
            .padding(20)
        }
        .accessibilityHidden(true)
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

            Button {
                router.selectedTab = .groups
            } label: {
                emptyStateButton("Gruplara Git", systemImage: "person.2.fill")
            }
            .padding(.top, 8)
        }
    }

    private func emptyStateButton(
        _ title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.body(15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: 220, minHeight: 48)
            .background(Color.brand)
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
    }

    // MARK: - Overall Balance (herkese açık)

    private var overallBalanceCard: some View {
        let summary = store.balanceSummary

        return VStack(spacing: 10) {
            HStack {
                Text("Genel Durumun")
                    .font(.body(12, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }

            if summary.byCurrency.isEmpty {
                Text("Henüz borç/alacak yok")
                    .font(.body(14))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.vertical, 8)
            } else {
                ForEach(summary.rows) { row in
                    VStack(spacing: 7) {
                        HStack {
                            Text(row.currency)
                                .font(.body(13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.82))
                            Spacer()
                        }
                        HStack(spacing: 12) {
                            balanceMetric(
                                title: "Toplam Alacak",
                                amount: row.amounts.receivable,
                                currency: row.currency,
                                icon: "arrow.down.left",
                                color: .credit
                            )
                            balanceMetric(
                                title: "Toplam Borç",
                                amount: row.amounts.debt,
                                currency: row.currency,
                                icon: "arrow.up.right",
                                color: .debt
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.brand)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .purpleTintedShadow(radius: 18, y: 9)
    }

    private func balanceMetric(
        title: LocalizedStringResource,
        amount: Int,
        currency: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(.white.opacity(0.72))
            Text(formatAmount(amount, currency: currency))
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Advanced Analytics (Pro Content)

    @ViewBuilder
    private var proAnalyticsContent: some View {
        spendingTrendSection
        detailedAnalysisSection
    }

    // MARK: - Yapmam Gerekenler (Action Center)

    private var actionCenterSection: some View {
        let items = DashboardActionItem.build(
            groups: store.groups,
            userID: store.currentUserID
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text("Yapmam Gerekenler")
                .font(.display(17, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if items.isEmpty {
                actionCenterEmptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        actionCard(item)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    private var actionCenterEmptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.credit)
            Text("Şu an yapman gereken bir işlem yok")
                .font(.body(14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func actionCard(_ item: DashboardActionItem) -> some View {
        Button {
            router.openGroup(item.groupID, section: .balances)
        } label: {
            switch item {
            case let .debt(_, groupName, currency, amount):
                actionRow(
                    icon: "arrow.down.circle.fill",
                    tint: .debt,
                    title: String(
                        format: AppLocalization.string("%@ grubunda borcun var", locale: locale),
                        locale: locale,
                        groupName
                    ),
                    detail: String(
                        format: AppLocalization.string("Borcun %@", locale: locale),
                        locale: locale,
                        formatAmount(amount, currency: currency)
                    )
                )
            case let .pendingApproval(_, groupName, _, fromName, currency, amount):
                actionRow(
                    icon: "checkmark.seal.fill",
                    tint: .warning,
                    title: String(
                        format: AppLocalization.string("%@ ödeme yaptı diyor", locale: locale),
                        locale: locale,
                        fromName
                    ),
                    detail: String(
                        format: AppLocalization.string("%1$@ • %2$@ onayını bekliyor", locale: locale),
                        locale: locale,
                        groupName,
                        formatAmount(amount, currency: currency)
                    )
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func actionRow(
        icon: String,
        tint: Color,
        title: String,
        detail: String
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                Text(detail)
                    .font(.body(12, weight: .medium))
                    .foregroundStyle(tint)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(12)
        .frame(minHeight: 56)
        .background(Color.surfaceTinted)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title), \(detail)"))
        .accessibilityHint("Grubun Ödeşme bölümünü açar")
        .accessibilityAddTraits(.isButton)
    }

    private var timeFilterPicker: some View {
        Picker("Zaman Filtresi", selection: $selectedTimeFilter) {
            ForEach(TimeFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Locked Analytics

    private var lockedAnalyticsPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primaryTheme)
                    .frame(width: 34, height: 34)
                    .background(Color.primaryTheme.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Harcama Trendi ve Detaylı Analiz")
                        .font(.display(17, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Trendler, en hareketli ay, popüler kategori, en çok ödeyen ve ödeşme özeti Pro ile açılır.")
                        .font(.body(12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                ForEach(lockedPreviewBars, id: \.self) { height in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primaryTheme.opacity(height > 0.55 ? 0.32 : 0.16))
                        .frame(height: 58 * height)
                        .frame(maxHeight: 58, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .bottom)
            .padding(12)
            .background(Color.surfaceTinted)
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))

            Button {
                showPaywall = true
            } label: {
                Text("Pro ile Aç")
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    private var lockedPreviewBars: [CGFloat] {
        hasAnyExpense
            ? [0.35, 0.58, 0.42, 0.76, 0.49, 0.68]
            : [0.38, 0.52, 0.45, 0.62, 0.50, 0.58]
    }

    private var spendingTrendSection: some View {
        let currency = analyticsCurrency
        let points = spendingTrendPoints(currency: currency)
        let maxAmount = points.map(\.amount).max() ?? 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Harcama Trendi")
                    .font(.display(17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(currency ?? "")
                    .font(.body(12, weight: .semibold))
                    .foregroundStyle(Color.primaryTheme)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.surfaceTinted)
                    .clipShape(Capsule())
            }

            if points.isEmpty || currency == nil {
                Text("Trend için henüz veri yok.")
                    .font(.body(14))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, 8)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(points) { point in
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.primaryTheme)
                                .frame(
                                    height: maxAmount > 0
                                        ? max(CGFloat(point.amount) / CGFloat(maxAmount) * 92, 8)
                                        : 8
                                )
                            Text(point.label)
                                .font(.body(10, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                if let last = points.last {
                    Text(
                        String(
                            format: AppLocalization.string("Son dönem: %@", locale: locale),
                            locale: locale,
                            formatAmount(last.amount, currency: currency ?? "")
                        )
                    )
                    .font(.body(12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    private var detailedAnalysisSection: some View {
        let currency = analyticsCurrency
        let details = detailedAnalytics(currency: currency)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Detaylı Analiz")
                    .font(.display(17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(currency ?? "")
                    .font(.body(12, weight: .semibold))
                    .foregroundStyle(Color.primaryTheme)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.surfaceTinted)
                    .clipShape(Capsule())
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                detailMetricCard(
                    title: "En Hareketli Ay",
                    value: details.busiestMonth ?? "-",
                    icon: "calendar"
                )
                detailMetricCard(
                    title: "Popüler Kategori",
                    value: details.popularCategory ?? "-",
                    icon: "chart.pie.fill"
                )
                detailMetricCard(
                    title: "En Çok Ödeyen",
                    value: details.topPayer ?? "-",
                    icon: "person.fill.checkmark"
                )
                detailMetricCard(
                    title: "Ödeşme Özeti",
                    value: details.settlementSummary,
                    icon: "checkmark.seal.fill"
                )
            }
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    private func detailMetricCard(
        title: LocalizedStringResource,
        value: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primaryTheme)
                .frame(width: 28, height: 28)
                .background(Color.primaryTheme.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(title)
                .font(.body(11, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(value)
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
        .padding(12)
        .background(Color.surfaceTinted)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
    }

    // MARK: - Category Analysis

    private var donutSection: some View {
        let stats = categoryStats(filter: selectedTimeFilter)
        let currencies = donutCurrencies(from: stats)
        let currency = selectedDonutCurrency ?? defaultDonutCurrency ?? currencies.first
        let segments = donutSegments(stats: stats, currency: currency)
        let total = segments.reduce(0) { $0 + $1.value }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Harcama Dağılımı")
                    .font(.display(17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if currencies.count > 1 {
                    Menu {
                        ForEach(currencies, id: \.self) { item in
                            Button(item) {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                    selectedDonutCurrency = item
                                    selectedDonutSegment = nil
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currency ?? "")
                                .font(.body(12, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Color.primaryTheme)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.surfaceTinted)
                        .clipShape(Capsule())
                    }
                }
            }

            if segments.isEmpty {
                Text("Henüz kategori verisi yok.")
                    .font(.body(14))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, 8)
            } else {
                DonutChart(
                    segments: segments,
                    centerText: formatAmount(total, currency: currency ?? ""),
                    selectedSegment: $selectedDonutSegment
                )
                .frame(maxWidth: .infinity)

                if let selectedDonutSegment,
                   segments.indices.contains(selectedDonutSegment) {
                    let segment = segments[selectedDonutSegment]
                    let percent = total > 0
                        ? Int((Double(segment.value) / Double(total) * 100).rounded())
                        : 0
                    HStack(spacing: 10) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 10, height: 10)
                        Text(segment.label)
                            .font(.body(14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(formatAmount(segment.value, currency: currency ?? ""))
                            .font(.body(13, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                        Text(
                            String(
                                format: AppLocalization.string("Toplamın %lld%%'i", locale: locale),
                                locale: locale,
                                Int64(percent)
                            )
                        )
                        .font(.body(12, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .padding(18)
        .background(Color.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    private var categorySection: some View {
        let stats = categoryStats(filter: selectedTimeFilter)
        let currencies = donutCurrencies(from: stats)
        let currency = selectedDonutCurrency ?? defaultDonutCurrency ?? currencies.first
        let visibleStats = stats
            .filter { stat in currency.map { stat.amount(for: $0) > 0 } ?? false }
            .sorted { $0.amount(for: currency ?? "") > $1.amount(for: currency ?? "") }
        let maximum = visibleStats.map { $0.amount(for: currency ?? "") }.max() ?? 1

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Harcama Kategorileri")
                    .font(.display(17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(currency ?? "")
                    .font(.body(12, weight: .semibold))
                    .foregroundStyle(Color.primaryTheme)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.surfaceTinted)
                    .clipShape(Capsule())
            }

            if visibleStats.isEmpty {
                Text("Henüz kategori verisi yok.")
                    .font(.body(14))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(visibleStats.prefix(6)) { stat in
                        categoryBar(stat, currency: currency ?? "", maxAmount: maximum)
                            .transition(.slide.combined(with: .opacity))
                    }
                }
            }
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    private func categoryBar(_ stat: CategoryStat, currency: String, maxAmount: Int) -> some View {
        let amount = stat.amount(for: currency)
        let fraction = maxAmount > 0
            ? Double(amount) / Double(maxAmount)
            : 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: stat.category.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(stat.category.color)
                    .frame(width: 20)

                Text(stat.category.title)
                    .font(.body(14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)

                Spacer()
            }

            HStack(spacing: 6) {
                    Text(formatAmount(amount, currency: currency))
                        .font(.body(12, weight: .semibold))
                    Text(currency.uppercased())
                        .font(.body(10, weight: .semibold))
                        .foregroundStyle(stat.category.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(stat.category.color.opacity(0.12))
                        .clipShape(Capsule())
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.surfaceTinted)
                .clipShape(Capsule())

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
        let filtered = filteredActivities()
        let searched = searchedActivities(from: filtered)
        let visible = Array(searched.prefix(10))

        return VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    isRecentActivityExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isRecentActivityExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.primaryTheme)
                        .frame(width: 18)
                    Text("Son Aktiviteler")
                        .font(.display(17, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text(
                        verbatim: debouncedActivitySearchText.isEmpty
                            ? "\(filtered.count)"
                            : "\(searched.count)/\(filtered.count)"
                    )
                        .font(.body(13, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isRecentActivityExpanded {
                VStack(spacing: 12) {
                    AppSearchField(
                        text: $activitySearchText,
                        placeholder: "Arama",
                        onClear: { debouncedActivitySearchText = "" }
                    )

                    HStack {
                        ActivityFilterButton(
                            filter: $activityFilter,
                            groups: store.groups
                        )
                        Spacer()
                    }

                    if visible.isEmpty {
                        Text(searched.isEmpty && !debouncedActivitySearchText.isEmpty ? "Sonuç yok" : "Henüz aktivite yok.")
                            .font(.body(14))
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(visible) { activity in
                                dashboardActivityRow(activity)
                                if activity.id != visible.last?.id {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
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
            actorName: actorName(activity),
            locale: locale
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .layoutPriority(1)

                HStack(spacing: 6) {
                    Text(groupName(activity.groupId))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primaryTheme)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.surfaceTinted)
                        .clipShape(Capsule())

                    if let time = activity.createdAt {
                        Text(timeAgo(time))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            Spacer()

            if let amountStr = activityAmount(activity) {
                Text(amountStr)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Data helpers

    private var analyticsCurrency: String? {
        selectedDonutCurrency ?? defaultDonutCurrency
    }

    private func spendingTrendPoints(currency: String?) -> [SpendingTrendPoint] {
        guard let currency else { return [] }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM")

        let grouped = filteredDashboardExpenses(currency: currency)
            .reduce(into: [Date: Int]()) { result, expense in
                guard let date = expense.expenseDate ?? expense.createdAt,
                      let month = calendar.dateInterval(of: .month, for: date)?.start else {
                    return
                }
                result[month, default: 0] += expense.amount
            }

        return grouped
            .sorted { $0.key < $1.key }
            .suffix(6)
            .map { date, amount in
                SpendingTrendPoint(
                    label: formatter.string(from: date),
                    amount: amount
                )
            }
    }

    private func detailedAnalytics(currency: String?) -> DetailedAnalytics {
        guard let currency else {
            return DetailedAnalytics(
                busiestMonth: nil,
                popularCategory: nil,
                topPayer: nil,
                settlementSummary: AppLocalization.string("Veri yok", locale: locale)
            )
        }

        let expenses = filteredDashboardExpenses(currency: currency)
        let calendar = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.locale = locale
        monthFormatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")

        let busiestMonth = expenses
            .reduce(into: [Date: Int]()) { result, expense in
                guard let date = expense.expenseDate ?? expense.createdAt,
                      let month = calendar.dateInterval(of: .month, for: date)?.start else {
                    return
                }
                result[month, default: 0] += expense.amount
            }
            .max { $0.value < $1.value }
            .map { monthFormatter.string(from: $0.key) }

        let popularCategory = expenses
            .reduce(into: [String: Int]()) { result, expense in
                result[expense.category, default: 0] += expense.amount
            }
            .max { $0.value < $1.value }
            .map { categoryTitle(ExpenseCategory.find($0.key)) }

        let payerTotals = expenses
            .reduce(into: [UUID: Int]()) { result, expense in
                result[expense.paidBy, default: 0] += expense.amount
            }
        let topPayer = payerTotals
            .max { $0.value < $1.value }
            .flatMap { payerID, amount -> String? in
                guard let name = memberName(payerID) else { return nil }
                return "\(name) · \(formatAmount(amount, currency: currency))"
            }

        let settlements = store.groups
            .flatMap(\.settlements)
            .filter {
                $0.status == .confirmed
                    && $0.currency.uppercased() == currency.uppercased()
            }
        let settlementTotal = settlements.reduce(0) { $0 + $1.amount }
        let settlementSummary = settlements.isEmpty
            ? AppLocalization.string("Henüz ödeşme yok", locale: locale)
            : String(
                format: AppLocalization.string("%1$lld ödeme · %2$@", locale: locale),
                locale: locale,
                Int64(settlements.count),
                formatAmount(settlementTotal, currency: currency)
            )

        return DetailedAnalytics(
            busiestMonth: busiestMonth,
            popularCategory: popularCategory,
            topPayer: topPayer,
            settlementSummary: settlementSummary
        )
    }

    private func filteredDashboardExpenses(currency: String) -> [Expense] {
        let since = selectedTimeFilter.since()
        return store.groups
            .flatMap(\.expenses)
            .filter { expense in
                guard expense.deletedAt == nil else { return false }
                guard expense.currency.uppercased() == currency.uppercased() else {
                    return false
                }
                guard let since else { return true }
                guard let date = expense.expenseDate ?? expense.createdAt else {
                    return false
                }
                return date >= since
            }
    }

    private func memberName(_ memberID: UUID) -> String? {
        for snapshot in store.groups {
            if let member = snapshot.member(id: memberID) {
                return member.displayName
            }
        }
        return nil
    }

    private var defaultDonutCurrency: String? {
        let totals = categoryStats(filter: selectedTimeFilter)
            .flatMap(\.currencyAmounts)
            .reduce(into: [String: Int]()) { result, item in
                result[item.currency.uppercased(), default: 0] += item.amount
            }
        return totals.max { $0.value < $1.value }?.key
    }

    private func categoryStats(filter: TimeFilter) -> [CategoryStat] {
        DashboardAnalytics.categoryStats(
            groups: store.groups,
            filter: filter
        )
    }

    private func donutCurrencies(from stats: [CategoryStat]) -> [String] {
        let totals = stats
            .flatMap(\.currencyAmounts)
            .reduce(into: [String: Int]()) { result, item in
                result[item.currency.uppercased(), default: 0] += item.amount
            }
        return totals.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        .map(\.key)
    }

    private func donutSegments(
        stats: [CategoryStat],
        currency: String?
    ) -> [DonutChart.Segment] {
        guard let currency else { return [] }
        return stats.compactMap { stat -> DonutChart.Segment? in
            let amount = stat.amount(for: currency)
            guard amount > 0 else { return nil }
            return DonutChart.Segment(
                color: stat.category.color,
                label: categoryTitle(stat.category),
                value: amount
            )
        }
    }

    private func filteredActivities() -> [Activity] {
        DashboardAnalytics.filteredActivities(
            store.activities,
            filter: selectedTimeFilter
        )
        .filter {
            activityFilter.matches(
                $0,
                groups: store.groups,
                userID: store.currentUserID
            )
        }
        .sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
    }

    private func searchedActivities(from activities: [Activity]) -> [Activity] {
        ActivitySearch.filter(
            activities,
            query: debouncedActivitySearchText,
            locale: locale
        ) { activity in
            let presentation = ActivityPresentation(
                activity: activity,
                actorName: actorName(activity),
                locale: locale
            )
            return [
                presentation.title,
                presentation.subtitle ?? "",
                groupName(activity.groupId)
            ]
            .joined(separator: " ")
        }
    }

    private func groupName(_ groupID: UUID) -> String {
        store.groups.first { $0.id == groupID }?.group.name
            ?? AppLocalization.string("Grup", locale: locale)
    }

    private func categoryTitle(_ category: ExpenseCategory) -> String {
        switch category.id {
        case "food":
            return AppLocalization.string("Yemek", locale: locale)
        case "transport":
            return AppLocalization.string("Ulaşım", locale: locale)
        case "accommodation":
            return AppLocalization.string("Konaklama", locale: locale)
        case "shopping":
            return AppLocalization.string("Alışveriş", locale: locale)
        case "entertainment":
            return AppLocalization.string("Eğlence", locale: locale)
        case "groceries":
            return AppLocalization.string("Market", locale: locale)
        case "bills":
            return AppLocalization.string("Faturalar", locale: locale)
        default:
            return AppLocalization.string("Diğer", locale: locale)
        }
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
        guard let rawAmount = activity.metadata["amount"]?.intValue,
              let currency = activity.metadata["currency"]?.stringValue else {
            return nil
        }
        // metadata'daki amount backend'ten major birimde (ondalık) geldiği için
        // formatAmount'ın beklediği minor birime çeviriyoruz.
        let decimals = getDecimals(currency)
        let minor: Int
        if decimals > 0 {
            var result = rawAmount
            for _ in 0..<decimals {
                let multiplied = result.multipliedReportingOverflow(by: 10)
                guard !multiplied.overflow else { return nil }
                result = multiplied.partialValue
            }
            minor = result
        } else {
            minor = rawAmount
        }
        return formatAmount(minor, currency: currency)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        switch interval {
        case ..<60:
            return AppLocalization.string("az önce", locale: locale)
        case ..<3600:
            return String(
                format: AppLocalization.string("%lld dk önce", locale: locale),
                locale: locale,
                Int64(interval / 60)
            )
        case ..<86400:
            return String(
                format: AppLocalization.string("%lld sa önce", locale: locale),
                locale: locale,
                Int64(interval / 3600)
            )
        case ..<604800:
            return String(
                format: AppLocalization.string("%lld g önce", locale: locale),
                locale: locale,
                Int64(interval / 86400)
            )
        default:
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
            return formatter.string(from: date)
        }
    }
}

private struct SpendingTrendPoint: Identifiable {
    var id: String { label }
    let label: String
    let amount: Int
}

private struct DetailedAnalytics {
    let busiestMonth: String?
    let popularCategory: String?
    let topPayer: String?
    let settlementSummary: String
}

enum TimeFilter: String, CaseIterable, Identifiable {
    case week
    case month
    case all

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .week: "Bu Hafta"
        case .month: "Bu Ay"
        case .all: "Tüm Zamanlar"
        }
    }

    func since(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start
        case .month:
            return calendar.dateInterval(of: .month, for: now)?.start
        case .all:
            return nil
        }
    }
}

struct CurrencyAmount: Hashable {
    let currency: String
    let amount: Int
}

struct CategoryStat: Identifiable {
    var id: String { category.id }
    let category: ExpenseCategory
    let currencyAmounts: [CurrencyAmount]
    let totalForSorting: Int

    func amount(for currency: String) -> Int {
        currencyAmounts.first {
            $0.currency.uppercased() == currency.uppercased()
        }?.amount ?? 0
    }
}

enum DashboardAnalytics {
    static func overallBalance(
        groups: [GroupSnapshot],
        userID: UUID?,
        filter: TimeFilter,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [String: Int] {
        guard let userID else { return [:] }
        var result: [String: Int] = [:]

        for snapshot in groups {
            guard let member = snapshot.currentMember(userID: userID) else {
                continue
            }
            let expenses = filteredExpenses(
                snapshot.expenses,
                filter: filter,
                now: now,
                calendar: calendar
            )
            let expenseIDs = Set(expenses.map(\.id))
            let splits = snapshot.splits.filter {
                expenseIDs.contains($0.expenseId)
            }
            let settlements = filteredSettlements(
                snapshot.settlements,
                filter: filter,
                now: now,
                calendar: calendar
            )
            let balance = computeBalance(
                expenses: expenses,
                splits: splits,
                settlements: settlements,
                for: member.id
            )

            for (currency, amount) in balance {
                result[currency, default: 0] += amount
            }
        }

        return result.filter { $0.value != 0 }
    }

    static func categoryStats(
        groups: [GroupSnapshot],
        filter: TimeFilter,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CategoryStat] {
        var amountsByCategory: [String: (category: ExpenseCategory, amounts: [String: Int])] = [:]

        for snapshot in groups {
            for expense in filteredExpenses(
                snapshot.expenses,
                filter: filter,
                now: now,
                calendar: calendar
            ) {
                let category = ExpenseCategory.find(expense.category)
                var entry = amountsByCategory[category.id] ?? (category, [:])
                entry.amounts[expense.currency.uppercased(), default: 0] += expense.amount
                amountsByCategory[category.id] = entry
            }
        }

        return amountsByCategory.values
            .map { entry in
                let currencyAmounts = entry.amounts
                    .map { CurrencyAmount(currency: $0.key, amount: $0.value) }
                    .sorted { lhs, rhs in
                        if lhs.amount == rhs.amount {
                            return lhs.currency < rhs.currency
                        }
                        return lhs.amount > rhs.amount
                    }
                return CategoryStat(
                    category: entry.category,
                    currencyAmounts: currencyAmounts,
                    totalForSorting: currencyAmounts.reduce(0) { $0 + $1.amount }
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalForSorting == rhs.totalForSorting {
                    return lhs.category.id < rhs.category.id
                }
                return lhs.totalForSorting > rhs.totalForSorting
            }
    }

    static func filteredActivities(
        _ activities: [Activity],
        filter: TimeFilter,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Activity] {
        guard let since = filter.since(now: now, calendar: calendar) else {
            return activities
        }
        return activities.filter { activity in
            guard let createdAt = activity.createdAt else { return false }
            return createdAt >= since
        }
    }

    private static func filteredExpenses(
        _ expenses: [Expense],
        filter: TimeFilter,
        now: Date,
        calendar: Calendar
    ) -> [Expense] {
        expenses.filter { expense in
            guard expense.deletedAt == nil else { return false }
            guard let since = filter.since(now: now, calendar: calendar) else {
                return true
            }
            guard let createdAt = expense.createdAt else { return false }
            return createdAt >= since
        }
    }

    private static func filteredSettlements(
        _ settlements: [Settlement],
        filter: TimeFilter,
        now: Date,
        calendar: Calendar
    ) -> [Settlement] {
        settlements.filter { settlement in
            guard settlement.status == .confirmed else { return false }
            guard let since = filter.since(now: now, calendar: calendar) else {
                return true
            }
            guard let date = settlement.confirmedAt ?? settlement.createdAt else {
                return false
            }
            return date >= since
        }
    }
}

private struct FlowPills<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 116), spacing: 8, alignment: .leading)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(store: PreviewSupport.groupsStore)
    }
    .environment(PreviewSupport.authStore)
    .environment(AppRouter())
}
