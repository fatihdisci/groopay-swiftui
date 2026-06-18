import XCTest
@testable import Groopay

final class ReleaseFeatureTests: XCTestCase {
    private let groupID = UUID()
    private let userID = UUID()
    private let memberID = UUID()
    private let otherMemberID = UUID()

    func testBalanceSummaryKeepsGrossReceivableAndDebtSeparate() {
        let receivable = snapshot(
            id: groupID,
            expenseAmount: 10_000,
            userPaid: true,
            userShare: 4_000,
            currency: "TRY"
        )
        let debt = snapshot(
            id: UUID(),
            expenseAmount: 8_000,
            userPaid: false,
            userShare: 3_000,
            currency: "TRY"
        )

        let summary = BalanceSummary.calculate(groups: [receivable, debt], userID: userID)

        XCTAssertEqual(summary.byCurrency["TRY"]?.receivable, 6_000)
        XCTAssertEqual(summary.byCurrency["TRY"]?.debt, 3_000)
    }

    func testReplacingExpenseAndSplitsRecalculatesBalance() {
        let original = snapshot(
            id: groupID,
            expenseAmount: 10_000,
            userPaid: true,
            userShare: 5_000,
            currency: "TRY"
        )
        let edited = snapshot(
            id: groupID,
            expenseAmount: 18_000,
            userPaid: true,
            userShare: 6_000,
            currency: "TRY"
        )

        XCTAssertEqual(original.memberBalances()[memberID]?["TRY"], 5_000)
        XCTAssertEqual(edited.memberBalances()[memberID]?["TRY"], 12_000)
    }

    func testDeletedExpenseDoesNotAffectBalance() {
        var group = snapshot(
            id: groupID,
            expenseAmount: 10_000,
            userPaid: true,
            userShare: 5_000,
            currency: "EUR"
        )
        group.expenses[0].deletedAt = Date()

        XCTAssertNil(group.memberBalances()[memberID]?["EUR"])
    }

    func testActivityFilterCombinesGroupCurrencyDateAndMine() {
        let group = snapshot(
            id: groupID,
            expenseAmount: 10_000,
            userPaid: true,
            userShare: 5_000,
            currency: "TRY"
        )
        let now = Date()
        let activity = Activity(
            id: UUID(),
            groupId: groupID,
            actorMemberId: memberID,
            actionType: "expense_added",
            metadata: ["currency": .string("TRY")],
            createdAt: now
        )
        let filter = ActivityFilter(
            groupID: groupID,
            currency: "TRY",
            startDate: now,
            endDate: now,
            onlyMine: true
        )

        XCTAssertTrue(filter.matches(activity, groups: [group], userID: userID))
    }

    func testCategoryAmountCanBeSelectedByCurrency() {
        let stat = CategoryStat(
            category: ExpenseCategory.find("food"),
            currencyAmounts: [
                CurrencyAmount(currency: "TRY", amount: 1_000),
                CurrencyAmount(currency: "EUR", amount: 2_000)
            ],
            totalForSorting: 3_000
        )

        XCTAssertEqual(stat.amount(for: "EUR"), 2_000)
        XCTAssertEqual(stat.amount(for: "USD"), 0)
    }

    private func snapshot(
        id: UUID,
        expenseAmount: Int,
        userPaid: Bool,
        userShare: Int,
        currency: String
    ) -> GroupSnapshot {
        let expenseID = UUID()
        let userMember = Member(
            id: memberID,
            groupId: id,
            userId: userID,
            displayName: "Fatih",
            avatarColor: "#4F46E5",
            role: .member,
            isActive: true
        )
        let otherMember = Member(
            id: otherMemberID,
            groupId: id,
            userId: UUID(),
            displayName: "Mert",
            avatarColor: "#10B981",
            role: .member,
            isActive: true
        )
        let payer = userPaid ? memberID : otherMemberID
        let expense = Expense(
            id: expenseID,
            groupId: id,
            description: "Test",
            amount: expenseAmount,
            currency: currency,
            category: "food",
            splitType: .custom,
            paidBy: payer,
            createdBy: payer
        )
        return GroupSnapshot(
            group: Group(
                id: id,
                name: "Test",
                photoURL: nil,
                baseCurrency: currency,
                createdBy: userID,
                isPro: false,
                proPurchasedBy: nil,
                proPurchasedAt: nil,
                isDemo: false,
                archived: false,
                description: nil,
                avatarEmoji: nil,
                avatarColor: "#4F46E5",
                createdAt: nil
            ),
            members: [userMember, otherMember],
            expenses: [expense],
            splits: [
                Split(id: UUID(), expenseId: expenseID, memberId: memberID, shareAmount: userShare),
                Split(
                    id: UUID(),
                    expenseId: expenseID,
                    memberId: otherMemberID,
                    shareAmount: expenseAmount - userShare
                )
            ],
            settlements: []
        )
    }
}
