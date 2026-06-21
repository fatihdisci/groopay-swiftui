import XCTest
@testable import Groopay

final class DashboardActionCenterTests: XCTestCase {
    private let groupID = Fixtures.uuid("11111111-1111-1111-1111-111111111111")
    private let userID = Fixtures.uuid("22222222-2222-2222-2222-222222222222")
    private let meID = Fixtures.uuid("33333333-3333-3333-3333-333333333301")
    private let otherID = Fixtures.uuid("33333333-3333-3333-3333-333333333302")
    private let exp1 = Fixtures.uuid("44444444-4444-4444-4444-444444444401")
    private let settlementID = Fixtures.uuid("99999999-9999-9999-9999-999999999901")

    private func snapshot(
        expenses: [Expense] = [],
        splits: [Split] = [],
        settlements: [Settlement] = []
    ) -> GroupSnapshot {
        GroupSnapshot(
            group: Fixtures.group(id: groupID, name: "Hafta Sonu"),
            members: [
                Fixtures.member(id: meID, groupId: groupID, userId: userID, name: "Ben"),
                Fixtures.member(id: otherID, groupId: groupID, name: "Mert")
            ],
            expenses: expenses,
            splits: splits,
            settlements: settlements
        )
    }

    private func debtSnapshot() -> GroupSnapshot {
        snapshot(
            expenses: [Fixtures.expense(id: exp1, groupId: groupID, amount: 100, paidBy: otherID)],
            splits: [
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555501"), expenseId: exp1, memberId: meID, amount: 50),
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555502"), expenseId: exp1, memberId: otherID, amount: 50)
            ]
        )
    }

    func testDebtProducesActionItem() {
        let items = DashboardActionItem.build(groups: [debtSnapshot()], userID: userID)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first, .debt(
            groupID: groupID,
            groupName: "Hafta Sonu",
            currency: "TRY",
            amount: 50
        ))
    }

    func testPendingApprovalProducesActionItem() {
        // Mert "ödedim" dedi → ben (alıcı) onaylamalıyım.
        let snap = snapshot(
            settlements: [
                Fixtures.settlement(id: settlementID, groupId: groupID, from: otherID, to: meID, amount: 50, status: .pending)
            ]
        )
        let items = DashboardActionItem.build(groups: [snap], userID: userID)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first, .pendingApproval(
            groupID: groupID,
            groupName: "Hafta Sonu",
            settlementID: settlementID,
            fromName: "Mert",
            currency: "TRY",
            amount: 50
        ))
    }

    func testEmptyWhenSettledAndNoApprovals() {
        let items = DashboardActionItem.build(groups: [snapshot()], userID: userID)
        XCTAssertTrue(items.isEmpty)
    }

    func testDuplicateGroupsAreDeduped() {
        // Aynı snapshot iki kez → borç bir kez, onay bir kez görünmeli.
        let snap = snapshot(
            expenses: [Fixtures.expense(id: exp1, groupId: groupID, amount: 100, paidBy: otherID)],
            splits: [
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555501"), expenseId: exp1, memberId: meID, amount: 50),
                Fixtures.split(id: Fixtures.uuid("55555555-5555-5555-5555-555555555502"), expenseId: exp1, memberId: otherID, amount: 50)
            ],
            settlements: [
                Fixtures.settlement(id: settlementID, groupId: groupID, from: otherID, to: meID, amount: 50, status: .pending)
            ]
        )
        let items = DashboardActionItem.build(groups: [snap, snap], userID: userID)
        XCTAssertEqual(items.filter { if case .debt = $0 { return true } else { return false } }.count, 1)
        XCTAssertEqual(items.filter { if case .pendingApproval = $0 { return true } else { return false } }.count, 1)
    }

    func testNilUserProducesNoItems() {
        XCTAssertTrue(DashboardActionItem.build(groups: [debtSnapshot()], userID: nil).isEmpty)
    }
}
