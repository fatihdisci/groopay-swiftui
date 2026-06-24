import SwiftUI

struct AddExpenseView: View {
    let groupID: UUID
    let store: GroupsStore
    private let editingExpense: Expense?
    private let onDeleted: ((Expense) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.appFeedback) private var feedback

    @State private var amountText: String
    @State private var selectedCurrency: String
    @State private var description: String
    @State private var note: String
    @State private var expenseDate: Date
    @State private var selectedCategoryID: String
    @State private var paidBy: UUID?
    @State private var splitType: SplitType
    @State private var subsetSelection: Set<UUID>
    @State private var customShares: [UUID: Int]
    @State private var customText: [UUID: String]
    @State private var detailsExpanded: Bool
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var fxRate: Double?
    @State private var fxRateAsOf: Date?
    @State private var fxRateError = false
    @State private var fxTask: Task<Void, Never>?

    init(
        groupID: UUID,
        store: GroupsStore,
        expense: Expense? = nil,
        template: Expense? = nil,
        onDeleted: ((Expense) -> Void)? = nil
    ) {
        self.groupID = groupID
        self.store = store
        editingExpense = expense
        self.onDeleted = onDeleted

        let snapshot = store.snapshot(groupID)
        let activeMembers = snapshot?.activeMembers ?? []
        let defaultCurrency = Currency.normalized(snapshot?.group.baseCurrency ?? "TRY")
        let savedPreference = ExpenseEntryPreferences().preference(for: groupID)

        if let sourceExpense = expense ?? template {
            let currency = Currency.normalized(sourceExpense.currency)
            _amountText = State(
                initialValue: Self.editableAmountString(
                    minor: sourceExpense.amount,
                    currency: currency
                )
            )
            _selectedCurrency = State(initialValue: currency)
            _description = State(initialValue: sourceExpense.description)
            _note = State(initialValue: sourceExpense.note ?? "")
            _expenseDate = State(
                initialValue: expense?.expenseDate ?? Date()
            )
            _selectedCategoryID = State(initialValue: sourceExpense.category)
            _paidBy = State(initialValue: sourceExpense.paidBy)
            _splitType = State(initialValue: sourceExpense.splitType)

            let existing = (snapshot?.splits ?? []).filter {
                $0.expenseId == sourceExpense.id
            }
            _subsetSelection = State(
                initialValue: Set(existing.map(\.memberId))
            )
            let shares = Dictionary(
                uniqueKeysWithValues: existing.map { ($0.memberId, $0.shareAmount) }
            )
            _customShares = State(initialValue: shares)
            _customText = State(
                initialValue: shares.mapValues {
                    Self.editableAmountString(minor: $0, currency: currency)
                }
            )
            _detailsExpanded = State(initialValue: true)
        } else {
            _amountText = State(initialValue: "")
            let preferredCurrency = savedPreference.map {
                Currency.normalized($0.currency)
            }
            _selectedCurrency = State(
                initialValue: preferredCurrency.flatMap {
                    Currency.supported.contains($0) ? $0 : nil
                } ?? defaultCurrency
            )
            _description = State(initialValue: "")
            _note = State(initialValue: "")
            _expenseDate = State(initialValue: Date())
            _selectedCategoryID = State(
                initialValue: savedPreference.flatMap { preference in
                    ExpenseCategory.all.contains { $0.id == preference.categoryID }
                        ? preference.categoryID
                        : nil
                } ?? ExpenseCategory.all[0].id
            )
            let preferredPayer = savedPreference?.paidBy
            _paidBy = State(
                initialValue: activeMembers.contains { $0.id == preferredPayer }
                    ? preferredPayer
                    : store.currentMemberID(in: groupID)
                    ?? activeMembers.first?.id
            )
            _splitType = State(initialValue: savedPreference?.splitType ?? .equal)
            _subsetSelection = State(initialValue: Set(activeMembers.map(\.id)))
            _customShares = State(initialValue: [:])
            _customText = State(initialValue: [:])
            _detailsExpanded = State(initialValue: false)
        }
    }

    var body: some View {
        SwiftUI.Group {
            if let snapshot = store.snapshot(groupID) {
                content(snapshot: snapshot)
            } else {
                ProgressView().tint(.primaryTheme)
            }
        }
    }

    private func content(snapshot: GroupSnapshot) -> some View {
        let members = snapshot.activeMembers

        return VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 22) {
                    amountSection
                    if showFXInfo(snapshot: snapshot) {
                        fxInfoBar(snapshot: snapshot)
                    }
                    numpad
                    if editingExpense == nil {
                        recentSuggestions(snapshot: snapshot)
                    }
                    descriptionField
                    detailsSection(members: members)
                    if editingExpense != nil {
                        deleteButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            saveBar(members: members)
        }
        .background(Color.background.ignoresSafeArea())
        // İşlem sürerken sheet yanlışlıkla kapatılamasın.
        .interactiveDismissDisabled(isSaving)
        // Masraf silme onayı destructive olduğundan alert/dialog olarak kalır.
        .confirmationDialog(
            "Masraf silinsin mi?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                Task { await handleDelete() }
            }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(editingExpense == nil ? "Masraf Ekle" : "Masrafı Düzenle")
                .font(.display(18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.surfaceTinted)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Amount

    private var amountMinor: Int {
        parseMoneyInputToMinor(amountText, currency: selectedCurrency)
    }

    private var amountSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text(amountText.isEmpty ? "0" : amountText)
                    .font(.display(52, weight: .extraBold))
                    .foregroundStyle(Color.primaryTheme)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.primaryTheme.opacity(0.25))
                    .frame(height: 2)
                    .frame(maxWidth: 220)

                Text(formatAmount(amountMinor, currency: selectedCurrency))
                    .font(.body(13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            currencyPills
        }
        .padding(.top, 8)
    }

    private var currencyPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Currency.supported, id: \.self) { currency in
                    let selected = currency == selectedCurrency
                    Button {
                        selectedCurrency = currency
                    } label: {
                        Text(currency)
                            .font(.body(13, weight: .semibold))
                            .foregroundStyle(selected ? .white : Color.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? Color.primaryTheme : Color.surface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    selected ? .clear : Color.textTertiary.opacity(0.3)
                                )
                            )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Numpad (Wise-style)

    private var numpad: some View {
        let keys: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            [".", "0", "\u{232B}"]
        ]
        return VStack(spacing: 10) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleKey(key)
                        } label: {
                            keyLabel(key)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .purpleTintedShadow(radius: 6, y: 2)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyLabel(_ key: String) -> some View {
        if key == "\u{232B}" {
            Image(systemName: "delete.left")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        } else {
            Text(key)
                .font(.display(22, weight: .bold))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func handleKey(_ key: String) {
        let decimals = getDecimals(selectedCurrency)
        switch key {
        case "\u{232B}":
            if !amountText.isEmpty {
                amountText.removeLast()
            }
        case ".":
            guard decimals > 0, !amountText.contains(".") else { return }
            amountText = amountText.isEmpty ? "0." : amountText + "."
        default:
            // Ondalık basamak sınırını aşma.
            if let dotIndex = amountText.firstIndex(of: ".") {
                let fraction = amountText.distance(
                    from: amountText.index(after: dotIndex),
                    to: amountText.endIndex
                )
                if fraction >= decimals { return }
            }
            guard amountText.count < 13 else { return }
            if amountText == "0" {
                amountText = key
            } else {
                amountText += key
            }
        }
    }

    // MARK: - FX Rate (DESIGN.md §6.4)

    /// Grubun baz para birimi seçili para biriminden farklıysa info bar göster.
    private func showFXInfo(snapshot: GroupSnapshot) -> Bool {
        selectedCurrency.uppercased() != snapshot.group.baseCurrency.uppercased()
    }

    /// Kur bilgisi info bar'ı. Yükleme/hata/başarı durumlarını kapsar.
    @ViewBuilder
    private func fxInfoBar(snapshot: GroupSnapshot) -> some View {
        let baseCurrency = snapshot.group.baseCurrency.uppercased()
        let formattedDate: String = {
            let f = DateFormatter()
            f.locale = locale
            f.setLocalizedDateFormatFromTemplate("d MMM yyyy HH:mm")
            return fxRateAsOf.map { f.string(from: $0) } ?? ""
        }()

        HStack(alignment: .top, spacing: ThemeSpacing.xs) {
            Image(systemName: fxRateError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(fxRateError ? Color.warning : Color.themeAccent)
                .padding(.top, 2)

            if let rate = fxRate, let asOf = fxRateAsOf, !fxRateError {
                Text(String(
                    format: String(localized: "1 %@ ≈ %@ %@ · %@ tarihinde kilitlendi · Bu kur yaklaşıktır, kesinleşmiş borç değildir", locale: locale),
                    locale: locale,
                    selectedCurrency.uppercased(),
                    String(format: "%.2f", rate),
                    baseCurrency,
                    formattedDate
                ))
                .font(.body(11, weight: .medium))
                .foregroundStyle(Color.themeTextSecondary)
            } else if fxRateError {
                Text(String(localized: "Kur bilgisi alınamadı · Şu an varsayılan kur kullanılıyor · Daha sonra tekrar dene", locale: locale))
                    .font(.body(11, weight: .medium))
                    .foregroundStyle(Color.warning)
            } else {
                Text(String(localized: "Kur bilgisi yükleniyor…", locale: locale))
                    .font(.body(11, weight: .medium))
                    .foregroundStyle(Color.themeTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ThemeSpacing.md)
        .padding(.vertical, ThemeSpacing.sm)
        .background(Color.themeSurfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.soft))
        .task(id: selectedCurrency) {
            guard showFXInfo(snapshot: snapshot) else { return }
            fxTask?.cancel()
            await fetchFXRate(from: selectedCurrency.uppercased(), to: baseCurrency)
        }
    }

    /// Frankfurter API'den kur çek (debounce 300ms, cache 1 saat).
    private func fetchFXRate(from: String, to: String) async {
        fxRateError = false
        do {
            try await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let result = try await FXRateService.shared.fetchRate(from: from, to: to)
            guard !Task.isCancelled else { return }
            fxRate = result.rate
            fxRateAsOf = result.asOf
        } catch {
            guard !Task.isCancelled else { return }
            fxRateError = true
            fxRate = nil
            fxRateAsOf = nil
        }
    }

    // MARK: - Son kullanılanlar

    /// İlgili grubun geçmişinden en fazla 3 benzersiz açıklama. Geçmiş yoksa
    /// alan hiç gösterilmez. Chip açıklama+kategori+para birimini doldurur;
    /// tutar bilerek doldurulmaz (eski tutarın yanlışlıkla kaydını önler).
    @ViewBuilder
    private func recentSuggestions(snapshot: GroupSnapshot) -> some View {
        let suggestions = RecentExpenseSuggestions.suggestions(from: snapshot.expenses)
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Son kullandıkların")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            Button {
                                applySuggestion(suggestion)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: ExpenseCategory.find(suggestion.category).icon)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(suggestion.description)
                                        .font(.body(13, weight: .medium))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(Color.primaryTheme)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(Color.primaryTheme.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                Text(
                                    String(
                                        format: String(localized: "%@ önerisini uygula", locale: locale),
                                        locale: locale,
                                        suggestion.description
                                    )
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func applySuggestion(_ suggestion: ExpenseSuggestion) {
        description = suggestion.description
        selectedCategoryID = suggestion.category
        if Currency.supported.contains(suggestion.currency) {
            selectedCurrency = suggestion.currency
        }
        // Tutar otomatik DOLDURULMAZ.
    }

    // MARK: - Description

    private var isDescriptionEmpty: Bool {
        description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Açıklama")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)

                Text("Zorunlu")
                    .font(.body(11, weight: .semibold))
                    .foregroundStyle(Color.debt)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.debt.opacity(0.1))
                    .clipShape(Capsule())
            }

            TextField("Kısa açıklama yaz", text: $description)
                .font(.body(16))
                .foregroundStyle(Color.textPrimary)
                .padding(14)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isDescriptionEmpty
                                ? Color.debt.opacity(0.35)
                                : Color.clear,
                            lineWidth: 1
                        )
                )

            if isDescriptionEmpty {
                Label("Kaydetmek için açıklama gerekli.", systemImage: "exclamationmark.circle.fill")
                    .font(.body(12, weight: .medium))
                    .foregroundStyle(Color.debt)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Category

    private func detailsSection(members: [Member]) -> some View {
        DisclosureGroup(isExpanded: $detailsExpanded) {
            VStack(spacing: 22) {
                dateAndNoteSection
                categorySection
                payerSection(members: members)
                splitTypeSelector
                previewSection(members: members)
            }
            .padding(.top, 18)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Color.primaryTheme)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Detaylar")
                        .font(.body(15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(detailsSummary(members: members))
                        .font(.body(12))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .tint(Color.primaryTheme)
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow(radius: 8, y: 3)
    }

    private func detailsSummary(members: [Member]) -> String {
        let category = localizedCategoryTitle(selectedCategoryID)
        let payer = members.first { $0.id == paidBy }?.displayName ?? "—"
        let split = localizedSplitTitle(splitType)
        return "\(selectedCurrency) · \(category) · \(payer) · \(split)"
    }

    private func localizedCategoryTitle(_ id: String) -> String {
        switch ExpenseCategory.find(id).id {
        case "food": String(localized: "Yemek", locale: locale)
        case "transport": String(localized: "Ulaşım", locale: locale)
        case "accommodation": String(localized: "Konaklama", locale: locale)
        case "shopping": String(localized: "Alışveriş", locale: locale)
        case "entertainment": String(localized: "Eğlence", locale: locale)
        case "groceries": String(localized: "Market", locale: locale)
        case "bills": String(localized: "Faturalar", locale: locale)
        default: String(localized: "Diğer", locale: locale)
        }
    }

    private func localizedSplitTitle(_ type: SplitType) -> String {
        switch type {
        case .equal: String(localized: "Eşit", locale: locale)
        case .custom: String(localized: "Özel", locale: locale)
        case .subset: String(localized: "Alt-Küme", locale: locale)
        }
    }

    private var dateAndNoteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tarih")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                DatePicker(
                    "Masraf tarihi",
                    selection: $expenseDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.primaryTheme)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Not")
                        .font(.body(13, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("İsteğe bağlı")
                        .font(.body(11))
                        .foregroundStyle(Color.textTertiary)
                }
                TextField("Masrafla ilgili bir not ekle", text: $note, axis: .vertical)
                    .font(.body(15))
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color.surfaceTinted)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kategori")
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ExpenseCategory.all) { category in
                        let selected = category.id == selectedCategoryID
                        Button {
                            selectedCategoryID = category.id
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(category.title)
                                    .font(.body(13, weight: .semibold))
                            }
                            .foregroundStyle(selected ? .white : category.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                selected ? category.color : category.color.opacity(0.12)
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Payer

    private func payerSection(members: [Member]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ödeyen")
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            Menu {
                ForEach(members) { member in
                    Button {
                        paidBy = member.id
                    } label: {
                        Text(member.displayName)
                        if member.id == paidBy {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if let member = members.first(where: { $0.id == paidBy }) {
                        GradientAvatar(
                            name: member.displayName,
                            color: member.avatarColor,
                            size: 34
                        )
                        Text(member.displayName)
                            .font(.body(15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                    } else {
                        Text("Seç")
                            .font(.body(15, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(12)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Split type

    private var splitTypeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bölüşme")
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            HStack(spacing: 0) {
                ForEach(SplitType.allCasesOrdered, id: \.self) { type in
                    let selected = type == splitType
                    Button {
                        selectSplitType(type)
                    } label: {
                        VStack(spacing: 8) {
                            Text(type.title)
                                .font(.body(14, weight: .semibold))
                                .foregroundStyle(
                                    selected ? Color.primaryTheme : Color.textSecondary
                                )
                            Rectangle()
                                .fill(selected ? Color.primaryTheme : .clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func selectSplitType(_ type: SplitType) {
        splitType = type
        // Özel'e geçişte mevcut eşit bölüşümü başlangıç değeri olarak doldur.
        if type == .custom, customShares.isEmpty {
            let members = store.snapshot(groupID)?.activeMembers ?? []
            let seeded = computeSplits(
                amount: amountMinor,
                type: .equal,
                memberIds: members.map(\.id)
            )
            customShares = seeded
            customText = seeded.mapValues {
                Self.editableAmountString(minor: $0, currency: selectedCurrency)
            }
        }
    }

    // MARK: - Preview

    /// B47 koruması: önizleme ve kaydetme HER ZAMAN bu tek kaynaktan beslenir;
    /// `computeSplits`'e seçili `splitType` geçirilir, asla eşit'e sabitlenmez.
    private func computedSplits(members: [Member]) -> [UUID: Int] {
        computeSplits(
            amount: amountMinor,
            type: splitType,
            memberIds: members.map(\.id),
            custom: splitType == .custom ? customShares : nil,
            subset: splitType == .subset ? subsetSelection : nil
        )
    }

    private func previewSection(members: [Member]) -> some View {
        let splits = computedSplits(members: members)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Önizleme")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                if splitType == .custom {
                    let remainder = amountMinor - customShares.values.reduce(0, +)
                    if remainder != 0, let first = members.first {
                        Text("Kalan \(formatAmount(remainder, currency: selectedCurrency)) → \(first.displayName)")
                            .font(.body(11, weight: .medium))
                            .foregroundStyle(Color.warning)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(members) { member in
                    memberRow(member: member, share: splits[member.id] ?? 0)
                    if member.id != members.last?.id {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func memberRow(member: Member, share: Int) -> some View {
        HStack(spacing: 12) {
            GradientAvatar(
                name: member.displayName,
                color: member.avatarColor,
                size: 34
            )
            Text(member.displayName)
                .font(.body(15, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()

            switch splitType {
            case .equal:
                Text(formatAmount(share, currency: selectedCurrency))
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            case .custom:
                TextField(
                    "0",
                    text: Binding(
                        get: { customText[member.id] ?? "" },
                        set: {
                            customText[member.id] = $0
                            customShares[member.id] = parseMoneyInputToMinor(
                                $0,
                                currency: selectedCurrency
                            )
                        }
                    )
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body(15, weight: .semibold))
                .foregroundStyle(Color.primaryTheme)
                .frame(width: 100)
            case .subset:
                let included = subsetSelection.contains(member.id)
                Button {
                    if included {
                        subsetSelection.remove(member.id)
                    } else {
                        subsetSelection.insert(member.id)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if included {
                            Text(formatAmount(share, currency: selectedCurrency))
                                .font(.body(15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                        }
                        Image(systemName: included ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(
                                included ? Color.primaryTheme : Color.textTertiary
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Masrafı Sil", systemImage: "trash")
                .font(.body(15, weight: .semibold))
                .foregroundStyle(Color.debt)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.debt.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
        }
    }

    // MARK: - Save

    private func saveBar(members: [Member]) -> some View {
        let splits = computedSplits(members: members)
        let valid = isValid(splits: splits)
        return VStack(spacing: 0) {
            Button {
                guard !isSaving else { return }
                Task { await handleSave(members: members) }
            } label: {
                GradientButtonLabel(
                    title: editingExpense == nil ? "Kaydet" : "Güncelle",
                    systemImage: "checkmark",
                    disabled: !valid || isSaving
                )
                .overlay {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                }
            }
            .disabled(!valid || isSaving)
            .accessibilityValue(
                isSaving
                    ? Text(String(localized: "İşlem sürüyor", locale: locale))
                    : Text("")
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func isValid(splits: [UUID: Int]) -> Bool {
        amountMinor > 0
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && paidBy != nil
            && !splits.isEmpty
            && splits.values.reduce(0, +) == amountMinor
    }

    private func handleSave(members: [Member]) async {
        guard let paidBy else { return }
        // B47: seçili tipe göre hesaplanan splits — eşit'e sabitlenmiyor.
        let splits = computedSplits(members: members)
        guard isValid(splits: splits) else { return }

        isSaving = true
        defer { isSaving = false }

        let success: Bool
        if let editingExpense {
            success = await store.updateExpense(
                expenseID: editingExpense.id,
                groupID: groupID,
                description: description,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amountMinor,
                currency: selectedCurrency,
                category: selectedCategoryID,
                splitType: splitType,
                paidBy: paidBy,
                splits: splits,
                date: expenseDate
            )
        } else {
            success = await store.addExpense(
                groupID: groupID,
                description: description,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amountMinor,
                currency: selectedCurrency,
                category: selectedCategoryID,
                splitType: splitType,
                paidBy: paidBy,
                splits: splits,
                date: expenseDate
            )
        }

        if success {
            // Endowment bildirimi: bu kullanıcının ilk masrafıysa ve yeni ekleniyorsa
            if editingExpense == nil {
                let isFirstExpense = store.groups.allSatisfy { $0.expenses.count <= 1 }
                    && store.groups.reduce(0) { $0 + $1.expenses.count } <= 1
                if isFirstExpense {
                    Task {
                        await EndowmentNotificationScheduler.scheduleIfNeeded(
                            afterFirstExpense: Date()
                        )
                    }
                }
            }

            ExpenseEntryPreferences().save(
                ExpenseEntryPreference(
                    currency: selectedCurrency,
                    categoryID: selectedCategoryID,
                    paidBy: paidBy,
                    splitType: splitType
                ),
                for: groupID
            )
            let payerName = members.first { $0.id == paidBy }?.displayName ?? "?"
            let groupName = store.snapshot(groupID)?.group.name ?? "?"
            let formattedAmount = formatAmount(amountMinor, currency: selectedCurrency)
            let message = editingExpense == nil
                ? String(
                    format: String(localized: "%@ — %@, %@ kişisine kaydedildi · %@", locale: locale),
                    locale: locale,
                    description,
                    formattedAmount,
                    payerName,
                    groupName
                )
                : String(
                    format: String(localized: "%@ — %@ güncellendi · %@", locale: locale),
                    locale: locale,
                    description,
                    formattedAmount,
                    groupName
                )
            dismiss()
            feedback.success(message)
        } else {
            feedback.error(
                store.errorMessage
                    ?? String(localized: "Masraf kaydedilemedi · Bilgileri kontrol et · Eksik alanları doldurup tekrar dene", locale: locale)
            )
            store.clearError()
        }
    }

    private func handleDelete() async {
        guard let editingExpense else { return }
        isSaving = true
        defer { isSaving = false }
        if await store.deleteExpense(expenseID: editingExpense.id, groupID: groupID) {
            // Silme başarılı: GroupDetail "Masraf silindi — Geri Al" feedback'ini
            // onDeleted üzerinden gösterir.
            onDeleted?(editingExpense)
            dismiss()
        } else {
            feedback.error(
                store.errorMessage
                    ?? String(localized: "Masraf silinemedi · İnternet bağlantını kontrol et · Tekrar dene", locale: locale)
            )
            store.clearError()
        }
    }

    // MARK: - Helpers

    private static func editableAmountString(minor: Int, currency: String) -> String {
        guard minor != 0 else { return "" }
        let decimals = getDecimals(currency)
        let negative = minor < 0
        let magnitude = abs(minor)

        guard decimals > 0 else {
            return "\(negative ? "-" : "")\(magnitude)"
        }

        var scale = 1
        for _ in 0..<decimals { scale *= 10 }
        let whole = magnitude / scale
        let fraction = magnitude % scale
        let fractionString = String(
            format: "%0\(decimals)d",
            fraction
        )
        return "\(negative ? "-" : "")\(whole).\(fractionString)"
    }
}

private extension SplitType {
    static var allCasesOrdered: [SplitType] { [.equal, .custom, .subset] }

    var title: LocalizedStringResource {
        switch self {
        case .equal: "Eşit"
        case .custom: "Özel"
        case .subset: "Alt-Küme"
        }
    }

}

#Preview("Yeni Masraf") {
    AddExpenseView(
        groupID: PreviewSupport.groupID,
        store: PreviewSupport.groupsStore
    )
}
