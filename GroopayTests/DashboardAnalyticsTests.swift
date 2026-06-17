import XCTest
@testable import Groopay

final class DashboardAnalyticsTests: XCTestCase {
    private let groupID = UUID()
    private let userID = UUID()
    private let payer = UUID()
    private let friend = UUID()
    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    private lazy var now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 17))!

    func testCategoryStatsMergeSameCategoryAcrossCurrencies() {
        let snapshot = makeSnapshot(
            expenses: [
                makeExpense(category: "groceries", amount: 2_180_00, currency: "TRY", daysAgo: 2),
                makeExpense(category: "groceries", amount: 32_00, currency: "USD", daysAgo: 2),
                makeExpense(category: "food", amount: 48_00, currency: "TRY", daysAgo: 2)
            ]
        )

        let stats = DashboardAnalytics.categoryStats(
            groups: [snapshot],
            filter: .month,
            now: now,
            calendar: calendar
        )

        let groceries = stats.first { $0.category.id == "groceries" }
        XCTAssertEqual(groceries?.currencyAmounts.count, 2)
        XCTAssertEqual(groceries?.amount(for: "TRY"), 2_180_00)
        XCTAssertEqual(groceries?.amount(for: "USD"), 32_00)
    }

    func testTimeFilterExcludesOlderExpenses() {
        let snapshot = makeSnapshot(
            expenses: [
                makeExpense(category: "food", amount: 10_00, currency: "TRY", daysAgo: 2),
                makeExpense(category: "food", amount: 20_00, currency: "TRY", daysAgo: 40)
            ]
        )

        let monthStats = DashboardAnalytics.categoryStats(
            groups: [snapshot],
            filter: .month,
            now: now,
            calendar: calendar
        )
        let allStats = DashboardAnalytics.categoryStats(
            groups: [snapshot],
            filter: .all,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(monthStats.first?.amount(for: "TRY"), 10_00)
        XCTAssertEqual(allStats.first?.amount(for: "TRY"), 30_00)
    }

    func testFilteredBalanceIncludesOnlyInPeriodConfirmedSettlements() {
        let expense = makeExpense(category: "food", amount: 10_000, currency: "TRY", daysAgo: 2)
        let snapshot = makeSnapshot(
            expenses: [expense],
            splits: [
                Split(id: UUID(), expenseId: expense.id, memberId: payer, shareAmount: 5_000),
                Split(id: UUID(), expenseId: expense.id, memberId: friend, shareAmount: 5_000)
            ],
            settlements: [
                makeSettlement(amount: 1_000, status: .confirmed, daysAgo: 1),
                makeSettlement(amount: 3_000, status: .confirmed, daysAgo: 45),
                makeSettlement(amount: 9_000, status: .pending, daysAgo: 1)
            ]
        )

        let result = DashboardAnalytics.overallBalance(
            groups: [snapshot],
            userID: userID,
            filter: .month,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(result["TRY"], 4_000)
    }

    func testFilteredActivitiesUseCreatedAt() {
        let recent = Activity(
            id: UUID(),
            groupId: groupID,
            actionType: "expense_insert",
            createdAt: date(daysAgo: 1)
        )
        let old = Activity(
            id: UUID(),
            groupId: groupID,
            actionType: "expense_insert",
            createdAt: date(daysAgo: 40)
        )

        XCTAssertEqual(
            DashboardAnalytics.filteredActivities(
                [recent, old],
                filter: .month,
                now: now,
                calendar: calendar
            ),
            [recent]
        )
    }

    private func makeSnapshot(
        expenses: [Expense],
        splits: [Split] = [],
        settlements: [Settlement] = []
    ) -> GroupSnapshot {
        GroupSnapshot(
            group: Group(
                id: groupID,
                name: "Trip",
                photoURL: nil,
                baseCurrency: "TRY",
                createdBy: userID,
                isPro: false,
                proPurchasedBy: nil,
                proPurchasedAt: nil,
                isDemo: false,
                archived: false,
                description: nil,
                avatarEmoji: nil,
                avatarColor: "#6366F1",
                createdAt: nil
            ),
            members: [
                Member(
                    id: payer,
                    groupId: groupID,
                    userId: userID,
                    displayName: "Fatih",
                    avatarColor: "#6366F1",
                    role: .founder,
                    isActive: true
                ),
                Member(
                    id: friend,
                    groupId: groupID,
                    userId: UUID(),
                    displayName: "Mert",
                    avatarColor: "#10B981",
                    role: .member,
                    isActive: true
                )
            ],
            expenses: expenses,
            splits: splits,
            settlements: settlements
        )
    }

    private func makeExpense(
        category: String,
        amount: Int,
        currency: String,
        daysAgo: Int
    ) -> Expense {
        Expense(
            id: UUID(),
            groupId: groupID,
            description: "Test",
            amount: amount,
            currency: currency,
            category: category,
            splitType: .equal,
            paidBy: payer,
            createdBy: payer,
            createdAt: date(daysAgo: daysAgo)
        )
    }

    private func makeSettlement(
        amount: Int,
        status: SettlementStatus,
        daysAgo: Int
    ) -> Settlement {
        Settlement(
            id: UUID(),
            groupId: groupID,
            fromMember: friend,
            toMember: payer,
            amount: amount,
            currency: "TRY",
            status: status,
            markedBy: friend,
            confirmedBy: status == .confirmed ? payer : nil,
            createdAt: date(daysAgo: daysAgo),
            confirmedAt: status == .confirmed ? date(daysAgo: daysAgo) : nil
        )
    }

    private func date(daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: now)!
    }
}
