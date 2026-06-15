import XCTest
@testable import Groopay

final class SplitTests: XCTestCase {
    private let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let third = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    func testEqualSplitKeepsEveryMinorUnit() {
        let result = computeSplits(
            amount: 100,
            type: .equal,
            memberIds: [first, second, third]
        )

        XCTAssertEqual(result.values.reduce(0, +), 100)
        XCTAssertEqual(result[first], 34)
        XCTAssertEqual(result[second], 33)
        XCTAssertEqual(result[third], 33)
    }

    func testSubsetOnlyIncludesSelectedMembers() {
        let result = computeSplits(
            amount: 101,
            type: .subset,
            memberIds: [first, second, third],
            subset: [second, third]
        )

        XCTAssertNil(result[first])
        XCTAssertEqual(result[second], 51)
        XCTAssertEqual(result[third], 50)
        XCTAssertEqual(result.values.reduce(0, +), 101)
    }

    func testCustomSplitPreservesTotal() {
        let result = computeSplits(
            amount: 1_000,
            type: .custom,
            memberIds: [first, second],
            custom: [first: 400, second: 600]
        )

        XCTAssertEqual(result, [first: 400, second: 600])
        XCTAssertEqual(result.values.reduce(0, +), 1_000)
    }

    func testCustomRemainderUsesFirstMember() {
        let result = computeSplits(
            amount: 1_001,
            type: .custom,
            memberIds: [first, second],
            custom: [first: 400, second: 600]
        )

        XCTAssertEqual(result[first], 401)
        XCTAssertEqual(result.values.reduce(0, +), 1_001)
    }

    /// B47 regresyonu: aynı girdiyle üç bölüşme tipi BİRBİRİNDEN FARKLI sonuç
    /// üretmeli. handleSave seçili tipi geçirmek yerine eşit'e sabitlerse bu
    /// test kırılır — kasıtlı koruma.
    func testEachSplitTypeProducesDistinctResult() {
        let members = [first, second, third]
        let amount = 900

        let equal = computeSplits(amount: amount, type: .equal, memberIds: members)
        let subset = computeSplits(
            amount: amount,
            type: .subset,
            memberIds: members,
            subset: [first, second]
        )
        let custom = computeSplits(
            amount: amount,
            type: .custom,
            memberIds: members,
            custom: [first: 600, second: 200, third: 100]
        )

        XCTAssertEqual(equal, [first: 300, second: 300, third: 300])
        XCTAssertEqual(subset, [first: 450, second: 450])
        XCTAssertEqual(custom, [first: 600, second: 200, third: 100])

        // Tipler birbirine eşit OLMAMALI (eşit'e sabitlenme regresyonu).
        XCTAssertNotEqual(equal, subset)
        XCTAssertNotEqual(equal, custom)
        XCTAssertNotEqual(subset, custom)

        // Her tip toplamı korur (para birimi tek; kuruş kaçağı yok).
        XCTAssertEqual(equal.values.reduce(0, +), amount)
        XCTAssertEqual(custom.values.reduce(0, +), amount)
        XCTAssertEqual(subset.values.reduce(0, +), amount)
    }

    func testDuplicateMemberIDsAreIgnored() {
        let result = computeSplits(
            amount: 10,
            type: .equal,
            memberIds: [first, first, second]
        )

        XCTAssertEqual(result, [first: 5, second: 5])
    }
}
