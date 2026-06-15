import SwiftUI

struct GroupDetailView: View {
    let groupID: UUID
    let store: GroupsStore
    @State private var selectedTab = GroupDetailTab.expenses
    @State private var presentedExpense: ExpenseSheet?

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
                        NavigationLink {
                            MembersView(groupID: groupID, store: store)
                        } label: {
                            Image(systemName: "person.2")
                        }

                        NavigationLink {
                            EditGroupView(groupID: groupID, store: store)
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
                .sheet(item: $presentedExpense) { sheet in
                    AddExpenseView(
                        groupID: groupID,
                        store: store,
                        expense: sheet.expense
                    )
                }
            } else {
                ProgressView()
                    .task { await store.load() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var snapshot: GroupSnapshot? {
        store.groups.first { $0.id == groupID }
    }

    private var addExpenseButton: some View {
        Button {
            presentedExpense = .new
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(
                        colors: [.gradientStart, .gradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .purpleTintedShadow(radius: 16, y: 8)
        }
        .padding(24)
    }

    private var detailTabs: some View {
        HStack(spacing: 8) {
            ForEach(GroupDetailTab.allCases) { tab in
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
            BalancesTabView(
                snapshot: snapshot,
                currentMemberID: store.currentMemberID(in: groupID)
            )
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
                    Button {
                        presentedExpense = .edit(expense)
                    } label: {
                        ExpenseCard(
                            expense: expense,
                            payer: snapshot.members.first { $0.id == expense.paidBy }
                        )
                    }
                    .buttonStyle(.plain)
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
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 54)
    }

}

private enum ExpenseSheet: Identifiable {
    case new
    case edit(Expense)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let expense): expense.id.uuidString
        }
    }

    var expense: Expense? {
        switch self {
        case .new: nil
        case .edit(let expense): expense
        }
    }
}

private enum GroupDetailTab: String, CaseIterable, Identifiable {
    case expenses
    case balances

    var id: String { rawValue }
    var title: String { self == .expenses ? "Masraflar" : "Bakiyeler" }
}

private struct ExpenseCard: View {
    let expense: Expense
    let payer: Member?

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
            }

            Spacer()

            Text(formatAmount(expense.amount, currency: expense.currency))
                .font(.display(17, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
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
        .background(
            LinearGradient(
                colors: [
                    Color(cssHex: "#6366F1") ?? .gradientStart,
                    Color(cssHex: "#8B5CF6") ?? .gradientEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
