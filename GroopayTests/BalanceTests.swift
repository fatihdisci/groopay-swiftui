import XCTest
@testable import Groopay

final class BalanceTests: XCTestCase {
    private let groupID = UUID()
    private let payer = UUID()
    private let friend = UUID()

    func testExpenseAndSplitsProduceOppositeBalances() {
        let expense = makeExpense(
            id: UUID(),
            payer: payer,
            amount: 10_000,
            currency: "TRY"
        )
        let splits = [
            Split(id: UUID(), expenseId: expense.id, memberId: payer, shareAmount: 5_000),
            Split(id: UUID(), expenseId: expense.id, memberId: friend, shareAmount: 5_000),
        ]

        XCTAssertEqual(
            computeBalance(
                expenses: [expense],
                splits: splits,
                settlements: [],
                for: payer
            ),
            ["TRY": 5_000]
        )
        XCTAssertEqual(
            computeBalance(
                expenses: [expense],
                splits: splits,
                settlements: [],
                for: friend
            ),
            ["TRY": -5_000]
        )
    }

    func testCurrenciesAreNeverCombined() {
        let tryExpense = makeExpense(
            id: UUID(),
            payer: payer,
            amount: 10_000,
            currency: "TRY"
        )
        let eurExpense = makeExpense(
            id: UUID(),
            payer: payer,
            amount: 5_000,
            currency: "EUR"
        )

        let result = computeBalance(
            expenses: [tryExpense, eurExpense],
            splits: [
                Split(id: UUID(), expenseId: tryExpense.id, memberId: friend, shareAmount: 10_000),
                Split(id: UUID(), expenseId: eurExpense.id, memberId: friend, shareAmount: 5_000),
            ],
            settlements: [],
            for: payer
        )

        XCTAssertEqual(result, ["TRY": 10_000, "EUR": 5_000])
    }

    func testOnlyConfirmedSettlementChangesBalance() {
        let confirmed = makeSettlement(status: .confirmed, amount: 2_000)
        let pending = makeSettlement(status: .pending, amount: 9_000)

        XCTAssertEqual(
            computeBalance(
                expenses: [],
                splits: [],
                settlements: [confirmed, pending],
                for: payer
            ),
            ["TRY": 2_000]
        )
        XCTAssertEqual(
            computeBalance(
                expenses: [],
                splits: [],
                settlements: [confirmed, pending],
                for: friend
            ),
            ["TRY": -2_000]
        )
    }

    func testSoftDeletedExpenseIsIgnored() {
        let expense = makeExpense(
            id: UUID(),
            payer: payer,
            amount: 10_000,
            currency: "TRY",
            deletedAt: Date()
        )

        XCTAssertEqual(
            computeBalance(
                expenses: [expense],
                splits: [
                    Split(
                        id: UUID(),
                        expenseId: expense.id,
                        memberId: friend,
                        shareAmount: 10_000
                    )
                ],
                settlements: [],
                for: payer
            ),
            [:]
        )
    }

    private func makeExpense(
        id: UUID,
        payer: UUID,
        amount: Int,
        currency: String,
        deletedAt: Date? = nil
    ) -> Expense {
        Expense(
            id: id,
            groupId: groupID,
            description: "Test",
            amount: amount,
            currency: currency,
            category: "other",
            splitType: .equal,
            paidBy: payer,
            createdBy: payer,
            deletedAt: deletedAt
        )
    }

    private func makeSettlement(
        status: SettlementStatus,
        amount: Int
    ) -> Settlement {
        Settlement(
            id: UUID(),
            groupId: groupID,
            fromMember: payer,
            toMember: friend,
            amount: amount,
            currency: "TRY",
            status: status,
            markedBy: payer
        )
    }
}
