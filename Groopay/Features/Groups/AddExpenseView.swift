import SwiftUI

struct AddExpenseView: View {
    let groupID: UUID
    let store: GroupsStore
    private let editingExpense: Expense?

    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String
    @State private var selectedCurrency: String
    @State private var description: String
    @State private var selectedCategoryID: String
    @State private var paidBy: UUID?
    @State private var splitType: SplitType
    @State private var subsetSelection: Set<UUID>
    @State private var customShares: [UUID: Int]
    @State private var customText: [UUID: String]
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    init(groupID: UUID, store: GroupsStore, expense: Expense? = nil) {
        self.groupID = groupID
        self.store = store
        editingExpense = expense

        let snapshot = store.snapshot(groupID)
        let activeMembers = snapshot?.activeMembers ?? []
        let defaultCurrency = Currency.normalized(snapshot?.group.baseCurrency ?? "TRY")

        if let expense {
            let currency = Currency.normalized(expense.currency)
            _amountText = State(
                initialValue: Self.editableAmountString(
                    minor: expense.amount,
                    currency: currency
                )
            )
            _selectedCurrency = State(initialValue: currency)
            _description = State(initialValue: expense.description)
            _selectedCategoryID = State(initialValue: expense.category)
            _paidBy = State(initialValue: expense.paidBy)
            _splitType = State(initialValue: expense.splitType)

            let existing = (snapshot?.splits ?? []).filter {
                $0.expenseId == expense.id
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
        } else {
            _amountText = State(initialValue: "")
            _selectedCurrency = State(initialValue: defaultCurrency)
            _description = State(initialValue: "")
            _selectedCategoryID = State(initialValue: ExpenseCategory.all[0].id)
            _paidBy = State(
                initialValue: store.currentMemberID(in: groupID)
                    ?? activeMembers.first?.id
            )
            _splitType = State(initialValue: .equal)
            _subsetSelection = State(initialValue: Set(activeMembers.map(\.id)))
            _customShares = State(initialValue: [:])
            _customText = State(initialValue: [:])
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
                    numpad
                    descriptionField
                    categorySection
                    payerSection(members: members)
                    splitTypeSelector
                    previewSection(members: members)
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
        .alert(
            "Masraf kaydedilemedi",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.clearError() } }
            )
        ) {
            Button("Tamam", role: .cancel) { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "")
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
                Task { await handleSave(members: members) }
            } label: {
                GradientButtonLabel(
                    title: editingExpense == nil ? "Kaydet" : "Güncelle",
                    systemImage: "checkmark",
                    disabled: !valid || isSaving
                )
            }
            .disabled(!valid || isSaving)
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
                note: nil,
                amount: amountMinor,
                currency: selectedCurrency,
                category: selectedCategoryID,
                splitType: splitType,
                paidBy: paidBy,
                splits: splits
            )
        } else {
            success = await store.addExpense(
                groupID: groupID,
                description: description,
                note: nil,
                amount: amountMinor,
                currency: selectedCurrency,
                category: selectedCategoryID,
                splitType: splitType,
                paidBy: paidBy,
                splits: splits
            )
        }

        if success {
            dismiss()
        }
    }

    private func handleDelete() async {
        guard let editingExpense else { return }
        isSaving = true
        defer { isSaving = false }
        if await store.deleteExpense(expenseID: editingExpense.id, groupID: groupID) {
            dismiss()
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
