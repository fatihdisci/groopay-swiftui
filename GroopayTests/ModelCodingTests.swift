import XCTest
@testable import Groopay

final class ModelCodingTests: XCTestCase {
    func testExpenseDecodesSnakeCaseAndMinorUnits() throws {
        let id = UUID()
        let groupID = UUID()
        let memberID = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "group_id": "\(groupID.uuidString)",
          "description": "Akşam yemeği",
          "note": "Fiş kasada kaldı",
          "amount": 19.99,
          "currency": "TRY",
          "category": "food",
          "split_type": "equal",
          "paid_by": "\(memberID.uuidString)",
          "expense_date": "2026-06-20",
          "created_by": "\(memberID.uuidString)",
          "created_at": null,
          "updated_at": null,
          "deleted_at": null
        }
        """

        let expense = try JSONDecoder().decode(
            Expense.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(expense.groupId, groupID)
        XCTAssertEqual(expense.paidBy, memberID)
        XCTAssertEqual(expense.amount, 1_999)
        XCTAssertEqual(expense.note, "Fiş kasada kaldı")
        let date = try XCTUnwrap(expense.expenseDate)
        XCTAssertEqual(
            Calendar(identifier: .gregorian).component(.day, from: date),
            20
        )
    }

    func testGhostMemberDecodesWithNilUserID() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "group_id": "\(UUID().uuidString)",
          "user_id": null,
          "display_name": "Misafir",
          "avatar_color": "#4F46E5",
          "role": "member",
          "is_active": true,
          "created_at": null,
          "joined_at": null
        }
        """

        let member = try JSONDecoder().decode(
            Member.self,
            from: Data(json.utf8)
        )

        XCTAssertTrue(member.isGhost)
    }
}
