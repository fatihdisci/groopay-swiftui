import XCTest
@testable import Groopay

/// Onboarding 2. aşamadaki demo bölüşme, gerçek `computeSplits` ile hesaplanır.
/// Bu test o senaryonun beklenen paylarını ve kullanıcı net sonucunu doğrular.
final class OnboardingSplitTests: XCTestCase {
    private let me = Fixtures.uuid("00000000-0000-0000-0000-0000000000A1")
    private let ayse = Fixtures.uuid("00000000-0000-0000-0000-0000000000A2")
    private let mert = Fixtures.uuid("00000000-0000-0000-0000-0000000000A3")
    private let amount = 120_000 // ₺1.200

    func testEqualSplitSharesAndUserNet() {
        let shares = computeSplits(
            amount: amount,
            type: .equal,
            memberIds: [me, ayse, mert]
        )
        XCTAssertEqual(shares, [me: 40_000, ayse: 40_000, mert: 40_000])
        XCTAssertEqual(shares.values.reduce(0, +), amount)
        // Sen ödedin (120000) − kendi payın (40000) = 80000 alacak.
        XCTAssertEqual(amount - (shares[me] ?? 0), 80_000)
    }

    func testSelectedPeopleSplitSharesAndUserNet() {
        let shares = computeSplits(
            amount: amount,
            type: .subset,
            memberIds: [me, ayse, mert],
            subset: [ayse, mert]
        )
        XCTAssertEqual(shares[ayse], 60_000)
        XCTAssertEqual(shares[mert], 60_000)
        XCTAssertNil(shares[me])
        XCTAssertEqual(shares.values.reduce(0, +), amount)
        // Sen payın yok → tüm 120000 alacak.
        XCTAssertEqual(amount - (shares[me] ?? 0), 120_000)
    }
}
