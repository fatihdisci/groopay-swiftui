import SwiftUI

struct GroupDetailView: View {
    let groupID: UUID
    let store: GroupsStore
    var initialSection: GroupDetailSection? = nil
    @Environment(\.locale) private var locale
    @Environment(\.appFeedback) private var feedback
    @State private var selectedTab = GroupDetailSection.expenses
    @State private var presentedExpense: ExpenseSheet?
    @State private var didApplyInitialTab = false

    var body: some View {
        SwiftUI.Group {
            if let snapshot {
                ZStack(alignment: .bottomTrailing) {
                    Color.background.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 0) {
                            GroupHeader(snapshot: snapshot)
                            detailTabs
                            tabContent(snapshot: snapshot)
                        }
                        .padding(.bottom, 100)
                    }

                    addExpenseButton
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ShareLink(item: summaryText(snapshot)) {
                            Image(systemName: "square.and.arrow.up")
                        }

                        NavigationLink(value: GroupRoute.members(groupID)) {
                            Image(systemName: "person.2")
                        }

                        NavigationLink(value: GroupRoute.edit(groupID)) {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
                .sheet(item: $presentedExpense) { sheet in
                    AddExpenseView(
                        groupID: groupID,
                        store: store,
                        expense: sheet.editingExpense,
                        template: sheet.template,
                        onDeleted: presentUndo(for:)
                    )
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        SkeletonBlock(height: 180, cornerRadius: 0)
                        SkeletonBlock(height: 46, cornerRadius: 23)
                            .padding(.horizontal, 20)
                        SkeletonList(count: 4)
                    }
                }
                .accessibilityHidden(true)
                .task { await store.load() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: snapshot != nil) {
            // Veri yüklendikten sonra bir kez çalışır. Bir initialSection
            // verildiyse (ör. action center "Ödeşme"yi açar) o bölüm uygulanır;
            // verilmediyse kullanıcının bu grupta borcu varsa grup doğrudan
            // Ödeşme sekmesinde açılır. Sonradan elle sekme değiştirilirse
            // override edilmez (didApplyInitialTab koruması).
            guard snapshot != nil, !didApplyInitialTab else { return }
            didApplyInitialTab = true
            if let initialSection {
                selectedTab = initialSection
            } else if currentUserOwes {
                selectedTab = .balances
            }
        }
    }

    private var snapshot: GroupSnapshot? {
        store.groups.first { $0.id == groupID }
    }

    /// Mevcut kullanıcının bu grupta herhangi bir para biriminde borcu var mı?
    private var currentUserOwes: Bool {
        guard let snapshot,
              let memberID = store.currentMemberID(in: groupID) else {
            return false
        }
        let balance = snapshot.ledgerBalances()[memberID] ?? [:]
        return balance.values.contains { $0 < 0 }
    }

    /// Platform-nötr metin özeti (WhatsApp vb. için sade düz yazı).
    private func summaryText(_ snapshot: GroupSnapshot) -> String {
        let transfers = simplifyDebts(balances: snapshot.memberBalances())
        var lines = [
            String(
                format: String(
                    localized: "%@ — Hesap Özeti",
                    locale: locale
                ),
                locale: locale,
                snapshot.group.name
            ),
            ""
        ]

        if transfers.isEmpty {
            lines.append(
                String(
                    localized: "Herkes ödeşti, kimsenin kimseye borcu yok.",
                    locale: locale
                )
            )
        } else {
            for transfer in transfers {
                let debtor = snapshot.member(id: transfer.fromMemberId)?.displayName ?? "?"
                let creditor = snapshot.member(id: transfer.toMemberId)?.displayName ?? "?"
                let amount = formatAmount(transfer.amount, currency: transfer.currency)
                lines.append("\(debtor) → \(creditor): \(amount)")
            }
        }

        lines.append("")
        lines.append(
            String(localized: "Groopay ile hesaplandı.", locale: locale)
        )
        return lines.joined(separator: "\n")
    }

    private var addExpenseButton: some View {
        Button {
            presentedExpense = .new
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                Text("Masraf Ekle")
                    .font(.body(16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(minHeight: 52)
            .background(Color.brand)
            .clipShape(Capsule())
            .purpleTintedShadow(radius: 16, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .accessibilityLabel("Masraf Ekle")
        .accessibilityHint("Bu gruba yeni masraf eklemek için açar")
    }

    private var detailTabs: some View {
        HStack(spacing: 8) {
            ForEach(GroupDetailSection.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(
                            selectedTab == tab
                                ? Color.primaryTheme
                                : Color.textSecondary
                        )
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(
                            selectedTab == tab
                                ? Color.primaryTheme.opacity(0.1)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(6)
        .background(Color.surface)
        .clipShape(Capsule())
        .padding(20)
    }

    @ViewBuilder
    private func tabContent(snapshot: GroupSnapshot) -> some View {
        switch selectedTab {
        case .expenses:
            expensesList(snapshot: snapshot)
        case .balances:
            BalancesTabView(store: store, groupID: groupID)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func expensesList(snapshot: GroupSnapshot) -> some View {
        if snapshot.expenses.isEmpty {
            emptyExpenses
        } else {
            LazyVStack(spacing: 12) {
                ForEach(snapshot.expenses) { expense in
                    let canEdit = expense.createdBy == store.currentMemberID(in: groupID)
                    ExpenseCard(
                        expense: expense,
                        payer: snapshot.members.first { $0.id == expense.paidBy },
                        canEdit: canEdit,
                        onEdit: { presentedExpense = .edit(expense) },
                        onCopy: { presentedExpense = .copy(expense) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if canEdit { presentedExpense = .edit(expense) }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var emptyExpenses: some View {
        VStack(spacing: 12) {
            Image(systemName: "receipt")
                .font(.system(size: 38))
                .foregroundStyle(Color.textTertiary)
            Text("Henüz masraf yok")
                .font(.body(15, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Text("Sağ alttaki + ile ilk masrafı ekle.")
                .font(.body(13))
                .foregroundStyle(Color.textTertiary)
            Button {
                presentedExpense = .new
            } label: {
                Label("İlk Masrafı Ekle", systemImage: "plus")
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 220, minHeight: 48)
                    .background(Color.brand)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 54)
    }

    /// Silme sonrası aksiyonlu "Geri Al" feedback'i. Gerçek restore RPC akışı
    /// korunur.
    private func presentUndo(for expense: Expense) {
        let label = String(
            format: String(localized: "%@ silindi", locale: locale),
            locale: locale,
            expense.description
        )
        feedback.show(
            label,
            style: .info,
            actionTitle: String(localized: "Geri Al", locale: locale),
            action: { restoreDeletedExpense(expenseID: expense.id) },
            duration: .seconds(6)
        )
    }

    private func restoreDeletedExpense(expenseID: UUID) {
        Task { @MainActor in
            if await store.restoreExpense(expenseID: expenseID, groupID: groupID) {
                feedback.success(
                    String(localized: "Masraf geri alındı. Grup bakiyeleri güncellendi.", locale: locale)
                )
            } else {
                feedback.error(
                    store.errorMessage
                        ?? String(localized: "Masraf geri alınamadı.", locale: locale)
                )
                store.clearError()
            }
        }
    }

}

private enum ExpenseSheet: Identifiable {
    case new
    case edit(Expense)
    case copy(Expense)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let expense): expense.id.uuidString
        case .copy(let expense): "copy-\(expense.id.uuidString)"
        }
    }

    var editingExpense: Expense? {
        switch self {
        case .new: nil
        case .edit(let expense): expense
        case .copy: nil
        }
    }

    var template: Expense? {
        switch self {
        case .copy(let expense): expense
        case .new, .edit: nil
        }
    }
}

private struct ExpenseCard: View {
    let expense: Expense
    let payer: Member?
    let canEdit: Bool
    let onEdit: () -> Void
    let onCopy: () -> Void
    @Environment(\.locale) private var locale

    private var category: ExpenseCategory {
        ExpenseCategory.find(expense.category)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                if let payer {
                    Text("\(payer.displayName) ödedi")
                        .font(.body(12))
                        .foregroundStyle(Color.textSecondary)
                }
                if expense.expenseDate != nil || expense.note?.isEmpty == false {
                    HStack(spacing: 8) {
                        if let date = expense.expenseDate {
                            Label(
                                date.formatted(
                                    Date.FormatStyle(date: .abbreviated)
                                        .locale(locale)
                                ),
                                systemImage: "calendar"
                            )
                        }
                        if expense.note?.isEmpty == false {
                            Image(systemName: "note.text")
                                .accessibilityLabel("Not")
                        }
                    }
                    .font(.body(11))
                    .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(formatAmount(expense.amount, currency: expense.currency))
                    .font(.display(17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Menu {
                    Button(action: onCopy) {
                        Label("Kopyala", systemImage: "doc.on.doc")
                    }
                    if canEdit {
                        Button(action: onEdit) {
                            Label("Düzenle", systemImage: "pencil")
                        }
                    }
                } label: {
                    Label("İşlemler", systemImage: "ellipsis")
                            .font(.body(11, weight: .semibold))
                            .foregroundStyle(Color.primaryTheme)
                            .padding(.horizontal, 9)
                            .frame(minHeight: 30)
                            .background(Color.primaryTheme.opacity(0.10))
                            .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Masraf işlemlerini açar")
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow()
    }
}

struct GroupHeader: View {
    let snapshot: GroupSnapshot

    var body: some View {
        VStack(spacing: 10) {
            GradientAvatar(
                name: snapshot.group.name,
                emoji: snapshot.group.avatarEmoji,
                color: snapshot.group.avatarColor,
                size: 64
            )
            .padding(6)
            .background(.white.opacity(0.16))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )

            Text(snapshot.group.name)
                .font(.display(26, weight: .extraBold))
                .foregroundStyle(.white)
            if let description = snapshot.group.description,
               !description.isEmpty {
                Text(description)
                    .font(.body(13))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
            }
            Text("\(snapshot.activeMembers.count) üye")
                .font(.body(13, weight: .medium))
                .foregroundStyle(.white.opacity(0.76))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.brand)
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(
            groupID: PreviewSupport.groupID,
            store: PreviewSupport.groupsStore
        )
    }
}
