import XCTest
@testable import Groopay

final class RecentExpenseSuggestionsTests: XCTestCase {
    private let groupID = Fixtures.uuid("11111111-1111-1111-1111-111111111111")
    private let me = Fixtures.uuid("33333333-3333-3333-3333-333333333301")

    private func expense(
        _ idSuffix: String,
        description: String,
        category: String = "food",
        currency: String = "TRY",
        daysAgo: TimeInterval,
        deleted: Bool = false
    ) -> Expense {
        var e = Fixtures.expense(
            id: Fixtures.uuid("44444444-4444-4444-4444-4444444444\(idSuffix)"),
            groupId: groupID,
            amount: 1000,
            currency: currency,
            paidBy: me,
            category: category,
            description: description,
            date: Date(timeIntervalSince1970: 1_700_000_000 - daysAgo * 86_400)
        )
        if deleted { e.deletedAt = Date() }
        return e
    }

    func testReturnsUpToThreeUniqueNewestFirst() {
        let expenses = [
            expense("01", description: "Akşam yemeği", daysAgo: 1),
            expense("02", description: "Market", daysAgo: 2),
            expense("03", description: "Taksi", daysAgo: 3),
            expense("04", description: "Kahve", daysAgo: 4)
        ]
        let result = RecentExpenseSuggestions.suggestions(from: expenses)
        XCTAssertEqual(result.map(\.description), ["Akşam yemeği", "Market", "Taksi"])
    }

    func testCaseInsensitiveDeduplicationKeepsNewest() {
        let expenses = [
            expense("01", description: "Market", category: "groceries", daysAgo: 1),
            expense("02", description: "market", category: "food", daysAgo: 2),
            expense("03", description: "Taksi", daysAgo: 3)
        ]
        let result = RecentExpenseSuggestions.suggestions(from: expenses)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].description, "Market")
        XCTAssertEqual(result[0].category, "groceries") // en yeni kayıt kazanır
        XCTAssertEqual(result[1].description, "Taksi")
    }

    func testSkipsDeletedAndEmptyDescriptions() {
        let expenses = [
            expense("01", description: "Silinen", daysAgo: 1, deleted: true),
            expense("02", description: "   ", daysAgo: 2),
            expense("03", description: "Geçerli", daysAgo: 3)
        ]
        let result = RecentExpenseSuggestions.suggestions(from: expenses)
        XCTAssertEqual(result.map(\.description), ["Geçerli"])
    }

    func testEmptyWhenNoHistory() {
        XCTAssertTrue(RecentExpenseSuggestions.suggestions(from: []).isEmpty)
    }

    func testCarriesCategoryAndCurrency() {
        let expenses = [
            expense("01", description: "Öğle", category: "food", currency: "eur", daysAgo: 1)
        ]
        let result = RecentExpenseSuggestions.suggestions(from: expenses)
        XCTAssertEqual(result.first?.category, "food")
        XCTAssertEqual(result.first?.currency, "EUR")
    }
}
