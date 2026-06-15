import XCTest
@testable import Groopay

final class SimplifyTests: XCTestCase {
    private let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let third = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    func testSingleMinorUnitDoesNotCrash() {
        let transfers = simplifyDebts(
            balances: [
                first: ["TRY": -1],
                second: ["TRY": 1],
            ]
        )

        XCTAssertEqual(
            transfers,
            [
                Transfer(
                    fromMemberId: first,
                    toMemberId: second,
                    amount: 1,
                    currency: "TRY"
                )
            ]
        )
    }

    func testSimplifiesMultipleMembers() {
        let transfers = simplifyDebts(
            balances: [
                first: ["TRY": -7_500],
                second: ["TRY": 2_500],
                third: ["TRY": 5_000],
            ]
        )

        XCTAssertEqual(transfers.map(\.amount).reduce(0, +), 7_500)
        XCTAssertEqual(Set(transfers.map(\.currency)), ["TRY"])
        XCTAssertTrue(transfers.allSatisfy { $0.fromMemberId == first })
    }

    func testEachCurrencyIsSimplifiedSeparately() {
        let transfers = simplifyDebts(
            balances: [
                first: ["TRY": -1_000, "EUR": 500],
                second: ["TRY": 1_000, "EUR": -500],
            ]
        )

        XCTAssertEqual(transfers.count, 2)
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: transfers.map { ($0.currency, $0.amount) }),
            ["EUR": 500, "TRY": 1_000]
        )
    }

    func testZeroBalancesReturnNoTransfers() {
        XCTAssertTrue(
            simplifyDebts(
                balances: [
                    first: ["TRY": 0],
                    second: ["TRY": 0],
                ]
            ).isEmpty
        )
    }
}
