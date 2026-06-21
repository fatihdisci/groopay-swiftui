import XCTest
@testable import Groopay

final class GroupCardStatusTests: XCTestCase {
    private let groupID = Fixtures.uuid("11111111-1111-1111-1111-111111111111")
    private let userID = Fixtures.uuid("22222222-2222-2222-2222-222222222222")
    private let meID = Fixtures.uuid("33333333-3333-3333-3333-333333333301")
    private let otherID = Fixtures.uuid("33333333-3333-3333-3333-333333333302")
    private let exp1 = Fixtures.uuid("44444444-4444-4444-4444-444444444401")
    private let exp2 = Fixtures.uuid("44444444-4444-4444-4444-444444444402")

    private func snapshot(
        expenses: [Expense],
        splits: [Split],
        settlements: [Settlement] = []
    ) -> GroupSnapshot {
        GroupSnapshot(
            group: Fixtures.group(id: groupID),
            members: [
                Fixtures.member(id: meID, groupId: groupID, userId: userID, name: "Ben"),
                Fixtures.member(id: otherID, groupId: groupID, name: "Diğer")
            ],
            expenses: expenses,
            splits: splits,
            settlements: settlements
        )
    }

    func testDebtStatus() {
        // Diğer üye 100 ödedi, eşit bölündü → ben 50 borçluyum.
        let snap = snapshot(
            expenses: [Fixtures.expense(id: exp1, groupId: groupID, amount: 100, paidBy: otherID)],
            splits: [
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555501"), expenseId: exp1, memberId: meID, amount: 50),
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555502"), expenseId: exp1, memberId: otherID, amount: 50)
            ]
        )

        let status = GroupCardStatus.make(snapshot: snap, userID: userID)
        XCTAssertEqual(status, .lines([
            GroupBalanceLine(currency: "TRY", amount: 50, kind: .debt)
        ]))
    }

    func testCreditStatus() {
        // Ben 100 ödedim, eşit bölündü → 50 alacaklıyım.
        let snap = snapshot(
            expenses: [Fixtures.expense(id: exp1, groupId: groupID, amount: 100, paidBy: meID)],
            splits: [
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555501"), expenseId: exp1, memberId: meID, amount: 50),
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555502"), expenseId: exp1, memberId: otherID, amount: 50)
            ]
        )

        let status = GroupCardStatus.make(snapshot: snap, userID: userID)
        XCTAssertEqual(status, .lines([
            GroupBalanceLine(currency: "TRY", amount: 50, kind: .credit)
        ]))
    }

    func testZeroStatusIsSettled() {
        // İki masraf birbirini dengeler → net sıfır.
        let snap = snapshot(
            expenses: [
                Fixtures.expense(id: exp1, groupId: groupID, amount: 100, paidBy: meID),
                Fixtures.expense(id: exp2, groupId: groupID, amount: 100, paidBy: otherID)
            ],
            splits: [
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555501"), expenseId: exp1, memberId: meID, amount: 50),
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555502"), expenseId: exp1, memberId: otherID, amount: 50),
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555503"), expenseId: exp2, memberId: meID, amount: 50),
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555504"), expenseId: exp2, memberId: otherID, amount: 50)
            ]
        )

        let status = GroupCardStatus.make(snapshot: snap, userID: userID)
        XCTAssertEqual(status, .settled)
    }

    func testMixedCurrenciesShowsBothLinesDebtFirst() {
        // TRY: diğer ödedi, ben 50 borçluyum. USD: ben ödedim, 50 alacaklıyım.
        let snap = snapshot(
            expenses: [
                Fixtures.expense(id: exp1, groupId: groupID, amount: 100, currency: "TRY", paidBy: otherID),
                Fixtures.expense(id: exp2, groupId: groupID, amount: 100, currency: "USD", paidBy: meID)
            ],
            splits: [
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555501"), expenseId: exp1, memberId: meID, amount: 50, currency: "TRY"),
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555502"), expenseId: exp1, memberId: otherID, amount: 50, currency: "TRY"),
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555503"), expenseId: exp2, memberId: meID, amount: 50, currency: "USD"),
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555504"), expenseId: exp2, memberId: otherID, amount: 50, currency: "USD")
            ]
        )

        let status = GroupCardStatus.make(snapshot: snap, userID: userID)
        XCTAssertEqual(status, .lines([
            GroupBalanceLine(currency: "TRY", amount: 50, kind: .debt),
            GroupBalanceLine(currency: "USD", amount: 50, kind: .credit)
        ]))
    }

    func testNoMembershipIsSettled() {
        let snap = snapshot(expenses: [], splits: [])
        let status = GroupCardStatus.make(snapshot: snap, userID: nil)
        XCTAssertEqual(status, .settled)
    }
}
