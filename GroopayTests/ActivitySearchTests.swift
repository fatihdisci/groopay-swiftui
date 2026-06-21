import XCTest
@testable import Groopay

final class ActivitySearchTests: XCTestCase {
    private let groupID = Fixtures.uuid("11111111-1111-1111-1111-111111111111")
    private let locale = Locale(identifier: "en_US")

    private func activities() -> [Activity] {
        [
            Fixtures.activity(id: Fixtures.uuid("77777777-7777-7777-7777-777777777701"), groupId: groupID, description: "Trastevere dinner"),
            Fixtures.activity(id: Fixtures.uuid("77777777-7777-7777-7777-777777777702"), groupId: groupID, description: "Weekly groceries"),
            Fixtures.activity(id: Fixtures.uuid("77777777-7777-7777-7777-777777777703"), groupId: groupID, description: "Airport taxi")
        ]
    }

    private func haystack(_ activity: Activity) -> String {
        activity.metadata["description"]?.stringValue ?? ""
    }

    func testQueryFiltersResultsForEveryone() {
        let result = ActivitySearch.filter(
            activities(),
            query: "dinner",
            locale: locale,
            haystack: haystack
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(haystack(result[0]), "Trastevere dinner")
    }

    func testEmptyQueryIsNoOp() {
        let all = activities()
        XCTAssertEqual(
            ActivitySearch.filter(all, query: "   ", locale: locale, haystack: haystack).count,
            all.count
        )
    }

    func testSearchIsCaseInsensitive() {
        let result = ActivitySearch.filter(
            activities(),
            query: "GROCERIES",
            locale: locale,
            haystack: haystack
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(haystack(result[0]), "Weekly groceries")
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertTrue(
            ActivitySearch.filter(activities(), query: "zzz", locale: locale, haystack: haystack).isEmpty
        )
    }

    func testTurkishLocaleLowercasing() {
        let items = [
            Fixtures.activity(id: Fixtures.uuid("77777777-7777-7777-7777-777777777711"), groupId: groupID, description: "İstanbul taksi")
        ]
        // Türkçe locale'de "İ" → "i" olur; "istanbul" sorgusu eşleşmeli.
        let result = ActivitySearch.filter(
            items,
            query: "istanbul",
            locale: Locale(identifier: "tr_TR"),
            haystack: haystack
        )
        XCTAssertEqual(result.count, 1)
    }
}
