import XCTest
@testable import Groopay

final class MoneyTests: XCTestCase {
    func testCurrencyDecimals() {
        XCTAssertEqual(getDecimals("TRY"), 2)
        XCTAssertEqual(getDecimals("usd"), 2)
        XCTAssertEqual(getDecimals("EUR"), 2)
        XCTAssertEqual(getDecimals("JPY"), 0)
        XCTAssertEqual(getDecimals("KWD"), 3)
        XCTAssertEqual(getDecimals("XYZ"), 2)
    }

    func testParsesLocalizedInputWithoutFloatingPoint() {
        XCTAssertEqual(parseMoneyInputToMinor("19,99", currency: "TRY"), 1_999)
        XCTAssertEqual(parseMoneyInputToMinor("19.99", currency: "TRY"), 1_999)
        XCTAssertEqual(parseMoneyInputToMinor("₺100", currency: "TRY"), 10_000)
        XCTAssertEqual(parseMoneyInputToMinor("1.000,50", currency: "TRY"), 100_050)
        XCTAssertEqual(parseMoneyInputToMinor("1,000.50", currency: "TRY"), 100_050)
        XCTAssertEqual(parseMoneyInputToMinor("5,5", currency: "TRY"), 550)
        XCTAssertEqual(parseMoneyInputToMinor("0,01", currency: "TRY"), 1)
        XCTAssertEqual(parseMoneyInputToMinor("", currency: "TRY"), 0)
    }

    func testParsesOtherDecimalCounts() {
        XCTAssertEqual(parseMoneyInputToMinor("100", currency: "JPY"), 100)
        XCTAssertEqual(parseMoneyInputToMinor("1,234", currency: "KWD"), 1_234)
    }

    func testFormattingUsesTurkishCurrencyStyle() {
        XCTAssertEqual(normalized(formatAmount(59_163, currency: "TRY")), "₺591,63")
        XCTAssertEqual(normalized(formatAmount(5_000, currency: "EUR")), "€50,00")
        XCTAssertEqual(normalized(formatAmount(10_000, currency: "USD")), "$100,00")
    }

    func testDecimalRoundTripIsExact() {
        let source = 1_999
        let decimal = decimalAmount(fromMinor: source, currency: "TRY")
        XCTAssertEqual(minorAmount(fromDecimal: decimal, currency: "TRY"), source)
    }

    private func normalized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
    }
}
