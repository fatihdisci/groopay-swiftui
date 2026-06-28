import SwiftUI

struct RecurringExpensesView: View {
    let groupID: UUID
    let store: GroupsStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.appFeedback) private var feedback

    @State private var showCreateRuleSheet = false
    @State private var selectedRuleToEdit: RecurringExpenseRule? = nil
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                
                let rules = store.recurringRules(for: groupID)
                
                if isLoading {
                    loadingState
                } else if rules.isEmpty {
                    emptyState
                } else {
                    ruleList(rules)
                }
            }
            .background(Color.background.ignoresSafeArea())
            .task {
                isLoading = true
                await store.loadRecurringRules(for: groupID)
                isLoading = false
            }
            .sheet(isPresented: $showCreateRuleSheet) {
                RuleFormView(groupID: groupID, store: store, rule: nil)
            }
            .sheet(item: $selectedRuleToEdit) { rule in
                RuleFormView(groupID: groupID, store: store, rule: rule)
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("Tekrarlayan Masraflar", comment: "Recurring expenses view title")
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

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView().tint(Color.primaryTheme)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.primaryTheme.opacity(0.8))
                
                Text("Tekrarlayan Masraf Yok", comment: "Empty state title")
                    .font(.display(20, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                
                Text("Kira, abonelik veya aidat gibi periyodik masraflarınız için otomatik harcamalar oluşturun.", comment: "Empty state description")
                    .font(.body(14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showCreateRuleSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Kural Ekle", comment: "Create first recurring rule button")
                }
                .font(.body(15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .frame(minHeight: 48)
                .background(Color.primaryTheme)
                .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
            }
            .purpleTintedShadow()

            Spacer()
        }
    }

    private func ruleList(_ rules: [RecurringExpenseRule]) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(rules) { rule in
                        ruleCard(rule)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            
            // Fixed bottom button
            Button {
                showCreateRuleSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Yeni Kural Ekle", comment: "Add new rule button label")
                }
                .font(.body(15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.primaryTheme)
                .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
            }
            .purpleTintedShadow()
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func ruleCard(_ rule: RecurringExpenseRule) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(rule.description)
                            .font(.body(15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        
                        Text(frequencyTitle(rule.frequency))
                            .font(.body(10, weight: .semibold))
                            .foregroundStyle(Color.primaryTheme)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primaryTheme.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    if let nextExec = rule.nextExecutionDate {
                        Text("Sıradaki: \(formattedDate(nextExec))", comment: "Next execution date label")
                            .font(.body(12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(formatAmount(rule.amount, currency: rule.currency))
                        .font(.display(16, weight: .bold))
                        .foregroundStyle(Color.primaryTheme)
                    
                    Toggle("", isOn: Binding(
                        get: { rule.isActive },
                        set: { newValue in
                            Task {
                                let success = await store.pauseRecurringRule(ruleID: rule.id, groupID: groupID, isActive: newValue)
                                if !success {
                                    feedback.error(store.errorMessage ?? String(localized: "İşlem başarısız.", comment: "Action failed error message"))
                                    store.clearError()
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(Color.primaryTheme)
                }
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow(radius: 6, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRuleToEdit = rule
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    let success = await store.deleteRecurringRule(ruleID: rule.id, groupID: groupID)
                    if success {
                        feedback.success(String(localized: "Kural silindi.", comment: "Rule deleted success feedback"))
                    } else {
                        feedback.error(store.errorMessage ?? String(localized: "Kural silinemedi.", comment: "Rule delete failed error"))
                        store.clearError()
                    }
                }
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }

    private func frequencyTitle(_ freq: RecurringFrequency) -> String {
        switch freq {
        case .weekly: String(localized: "Haftalık", locale: locale)
        case .monthly: String(localized: "Aylık", locale: locale)
        case .yearly: String(localized: "Yıllık", locale: locale)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}

// Create/Edit Form View
struct RuleFormView: View {
    let groupID: UUID
    let store: GroupsStore
    let rule: RecurringExpenseRule?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.appFeedback) private var feedback

    @State private var description = ""
    @State private var note = ""
    @State private var amountText = ""
    @State private var selectedCurrency = "TRY"
    @State private var selectedCategoryID = "groceries"
    @State private var paidBy: UUID?
    @State private var frequency: RecurringFrequency = .monthly
    @State private var startDate = Date()
    @State private var splitType: SplitType = .equal
    @State private var subsetSelection: Set<UUID> = []
    @State private var customShares: [UUID: Int] = [:]
    @State private var customText: [UUID: String] = [:]
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    init(groupID: UUID, store: GroupsStore, rule: RecurringExpenseRule?) {
        self.groupID = groupID
        self.store = store
        self.rule = rule

        let snapshot = store.snapshot(groupID)
        let activeMembers = snapshot?.activeMembers ?? []
        let defaultCurrency = snapshot?.group.baseCurrency ?? "TRY"

        if let rule {
            _description = State(initialValue: rule.description)
            _note = State(initialValue: rule.note ?? "")
            _selectedCurrency = State(initialValue: rule.currency)
            _amountText = State(initialValue: Self.editableAmountString(minor: rule.amount, currency: rule.currency))
            _selectedCategoryID = State(initialValue: rule.category)
            _paidBy = State(initialValue: rule.paidBy)
            _frequency = State(initialValue: rule.frequency)
            _startDate = State(initialValue: rule.startDate ?? Date())
            _splitType = State(initialValue: rule.splitType)
            
            let initialSubset = rule.splitType == .subset ? Set(rule.splits.map(\.memberId)) : Set(activeMembers.map(\.id))
            _subsetSelection = State(initialValue: initialSubset)
            
            var initialCustomShares: [UUID: Int] = [:]
            var initialCustomText: [UUID: String] = [:]
            if rule.splitType == .custom {
                for entry in rule.splits {
                    initialCustomShares[entry.memberId] = entry.shareAmount
                    initialCustomText[entry.memberId] = Self.editableAmountString(minor: entry.shareAmount, currency: rule.currency)
                }
            }
            _customShares = State(initialValue: initialCustomShares)
            _customText = State(initialValue: initialCustomText)
        } else {
            _description = State(initialValue: "")
            _note = State(initialValue: "")
            _selectedCurrency = State(initialValue: defaultCurrency)
            _amountText = State(initialValue: "")
            _selectedCategoryID = State(initialValue: "groceries")
            _paidBy = State(initialValue: activeMembers.first?.id)
            _frequency = State(initialValue: .monthly)
            _startDate = State(initialValue: Date())
            _splitType = State(initialValue: .equal)
            _subsetSelection = State(initialValue: Set(activeMembers.map(\.id)))
            _customShares = State(initialValue: [:])
            _customText = State(initialValue: [:])
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                
                if let snapshot = store.snapshot(groupID) {
                    ScrollView {
                        VStack(spacing: 20) {
                            inputSection(snapshot: snapshot)
                            detailsSection(snapshot: snapshot)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                    }
                    
                    saveBar(members: snapshot.activeMembers)
                }
            }
            .background(Color.background.ignoresSafeArea())
            .confirmationDialog(
                "Kural silinsin mi?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Sil", role: .destructive) {
                    Task { await handleDelete() }
                }
                Button("Vazgeç", role: .cancel) {}
            }
        }
    }

    private var header: some View {
        ZStack {
            Text(rule == nil ? "Kural Ekle" : "Kuralı Düzenle", comment: "Rule form view title")
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

    private func inputSection(snapshot: GroupSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Description
            VStack(alignment: .leading, spacing: 6) {
                Text("Açıklama", comment: "Label for description field")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                TextField("Abonelik, Kira vb.", text: $description)
                    .font(.body(15))
                    .padding(12)
                    .background(Color.surfaceTinted)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Amount & Currency
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tutar", comment: "Label for amount input field")
                        .font(.body(13, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.display(16, weight: .bold))
                        .padding(12)
                        .background(Color.surfaceTinted)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Para Birimi", comment: "Label for currency selector")
                        .font(.body(13, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                    Menu {
                        ForEach(Currency.supported, id: \.self) { curr in
                            Button(curr) {
                                selectedCurrency = curr
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCurrency)
                                .font(.body(15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(12)
                        .background(Color.surfaceTinted)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow(radius: 6, y: 2)
    }

    private func detailsSection(snapshot: GroupSnapshot) -> some View {
        let members = snapshot.activeMembers
        
        return VStack(alignment: .leading, spacing: 16) {
            // Frequency Segmented Control
            VStack(alignment: .leading, spacing: 8) {
                Text("Tekrarlama Sıklığı", comment: "Frequency picker label")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                
                Picker("", selection: $frequency) {
                    Text("Haftalık", comment: "Weekly option").tag(RecurringFrequency.weekly)
                    Text("Aylık", comment: "Monthly option").tag(RecurringFrequency.monthly)
                    Text("Yıllık", comment: "Yearly option").tag(RecurringFrequency.yearly)
                }
                .pickerStyle(.segmented)
            }

            // Start Date Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Başlangıç Tarihi", comment: "Start date picker label")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                
                DatePicker("", selection: $startDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            
            Divider()
            
            // Category Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Kategori", comment: "Category picker label")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ExpenseCategory.all) { cat in
                            let selected = cat.id == selectedCategoryID
                            Button {
                                selectedCategoryID = cat.id
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon)
                                    Text(cat.title)
                                }
                                .font(.body(12, weight: .semibold))
                                .foregroundStyle(selected ? .white : cat.color)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selected ? cat.color : cat.color.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            Divider()

            // Paid By Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Ödeyen", comment: "Payer selector label")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                
                Menu {
                    ForEach(members) { member in
                        Button(member.displayName) {
                            paidBy = member.id
                        }
                    }
                } label: {
                    HStack {
                        if let paidBy, let member = members.first(where: { $0.id == paidBy }) {
                            GradientAvatar(name: member.displayName, color: member.avatarColor, size: 24)
                            Text(member.displayName)
                                .font(.body(14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                        } else {
                            Text("Seçiniz", comment: "Payer empty placeholder")
                                .font(.body(14))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(12)
                    .background(Color.surfaceTinted)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            Divider()

            // Split Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Bölüşüm Şekli", comment: "Split selection label")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                
                Picker("", selection: $splitType) {
                    Text("Eşit", comment: "Equal split").tag(SplitType.equal)
                    Text("Alt-Küme", comment: "Subset split").tag(SplitType.subset)
                    Text("Özel", comment: "Custom split").tag(SplitType.custom)
                }
                .pickerStyle(.segmented)
                .onChange(of: splitType) { _, newValue in
                    if newValue == .custom && customShares.isEmpty {
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

                // Render Split controls
                let splits = computedSplits(members: members)
                
                VStack(spacing: 8) {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            GradientAvatar(name: member.displayName, color: member.avatarColor, size: 28)
                            Text(member.displayName)
                                .font(.body(14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            
                            switch splitType {
                            case .equal:
                                Text(formatAmount(splits[member.id] ?? 0, currency: selectedCurrency))
                                    .font(.body(14, weight: .semibold))
                                    .foregroundStyle(Color.textSecondary)
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
                                            Text(formatAmount(splits[member.id] ?? 0, currency: selectedCurrency))
                                                .font(.body(14, weight: .semibold))
                                                .foregroundStyle(Color.textSecondary)
                                        }
                                        Image(systemName: included ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(included ? Color.primaryTheme : Color.textTertiary)
                                    }
                                }
                            case .custom:
                                TextField("0.00", text: Binding(
                                    get: { customText[member.id] ?? "" },
                                    set: { val in
                                        customText[member.id] = val
                                        customShares[member.id] = parseMoneyInputToMinor(val, currency: selectedCurrency)
                                    }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.body(14, weight: .semibold))
                                .foregroundStyle(Color.primaryTheme)
                                .frame(width: 80)
                                .textFieldStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow(radius: 6, y: 2)
    }

    private var amountMinor: Int {
        parseMoneyInputToMinor(amountText, currency: selectedCurrency)
    }

    private func computedSplits(members: [Member]) -> [UUID: Int] {
        computeSplits(
            amount: amountMinor,
            type: splitType,
            memberIds: members.map(\.id),
            custom: splitType == .custom ? customShares : nil,
            subset: splitType == .subset ? subsetSelection : nil
        )
    }

    private func isValid(splits: [UUID: Int]) -> Bool {
        amountMinor > 0
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && paidBy != nil
            && !splits.isEmpty
            && splits.values.reduce(0, +) == amountMinor
    }

    private func saveBar(members: [Member]) -> some View {
        let splits = computedSplits(members: members)
        let valid = isValid(splits: splits)
        
        return VStack(spacing: 0) {
            if rule != nil {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Kuralı Sil", systemImage: "trash")
                        .font(.body(15, weight: .semibold))
                        .foregroundStyle(Color.debt)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.debt.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
                }
            }
            Button {
                guard valid, !isSaving, let payerId = paidBy else { return }
                Task {
                    isSaving = true
                    let success: Bool

                    if let rule {
                        success = await store.updateRecurringRule(
                            ruleID: rule.id,
                            groupID: groupID,
                            description: description,
                            note: note.isEmpty ? nil : note,
                            amount: amountMinor,
                            currency: selectedCurrency,
                            category: selectedCategoryID,
                            splitType: splitType,
                            paidBy: payerId,
                            frequency: frequency,
                            isActive: rule.isActive,
                            splits: splits
                        )
                    } else {
                        success = await store.createRecurringRule(
                            groupID: groupID,
                            description: description,
                            note: note.isEmpty ? nil : note,
                            amount: amountMinor,
                            currency: selectedCurrency,
                            category: selectedCategoryID,
                            splitType: splitType,
                            paidBy: payerId,
                            frequency: frequency,
                            startDate: startDate,
                            splits: splits
                        )
                    }
                    
                    isSaving = false
                    if success {
                        feedback.success(rule == nil ? String(localized: "Kural oluşturuldu.", comment: "Rule created successfully") : String(localized: "Kural güncellendi.", comment: "Rule updated successfully"))
                        dismiss()
                    } else {
                        feedback.error(store.errorMessage ?? String(localized: "Kural kaydedilemedi.", comment: "Failed to save rule error"))
                        store.clearError()
                    }
                }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark")
                        Text("Kaydet", comment: "Save recurring rule button")
                    }
                }
                .font(.body(15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(valid ? Color.primaryTheme : Color.textTertiary)
                .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
            }
            .disabled(!valid || isSaving)
            .purpleTintedShadow()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func handleDelete() async {
        guard let rule else { return }
        isSaving = true
        defer { isSaving = false }
        let success = await store.deleteRecurringRule(ruleID: rule.id, groupID: groupID)
        if success {
            feedback.success(String(localized: "Kural silindi.", comment: "Rule deleted"))
            dismiss()
        } else {
            feedback.error(store.errorMessage ?? String(localized: "Kural silinemedi.", comment: "Rule delete failed"))
            store.clearError()
        }
    }

    private static func editableAmountString(minor: Int, currency: String) -> String {
        guard minor != 0 else { return "" }
        let decimals = getDecimals(currency)
        let magnitude = abs(minor)
        guard decimals > 0 else { return "\(magnitude)" }
        var scale = 1
        for _ in 0..<decimals { scale *= 10 }
        let whole = magnitude / scale
        let fraction = magnitude % scale
        return String(format: "%d.%0\(decimals)d", whole, fraction)
    }
}
