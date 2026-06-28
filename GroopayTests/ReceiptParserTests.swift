import XCTest
@testable import Groopay

final class ReceiptParserTests: XCTestCase {
    func testParsesBasicReceiptLine() {
        let text = "Hamburger        150,50"
        let parsed = ReceiptParser.parseReceiptText(text, currency: "TRY")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "Hamburger")
        XCTAssertEqual(parsed[0].amountMinor, 15050)
    }

    func testFiltersTotalLine() {
        let text = "TOPLAM          300,00"
        let parsed = ReceiptParser.parseReceiptText(text, currency: "TRY")
        XCTAssertTrue(parsed.isEmpty)
    }

    func testFiltersKDVLine() {
        let text = "KDV %18         27,00"
        let parsed = ReceiptParser.parseReceiptText(text, currency: "TRY")
        XCTAssertTrue(parsed.isEmpty)
    }

    func testParsesMultipleLines() {
        let text = """
        Hamburger        150,50
        Patates Cipsi     60,00
        Kola              40,00
        TOPLAM           250,00
        """
        let parsed = ReceiptParser.parseReceiptText(text, currency: "TRY")
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].name, "Hamburger")
        XCTAssertEqual(parsed[0].amountMinor, 15050)
        XCTAssertEqual(parsed[1].name, "Patates Cipsi")
        XCTAssertEqual(parsed[1].amountMinor, 6000)
        XCTAssertEqual(parsed[2].name, "Kola")
        XCTAssertEqual(parsed[2].amountMinor, 4000)
    }

    func testEmptyTextReturnsEmptyArray() {
        let parsed = ReceiptParser.parseReceiptText("", currency: "TRY")
        XCTAssertTrue(parsed.isEmpty)
    }

    func testRemainderDistribution() {
        // 100 kuruş / 3 kişi = 34 + 33 + 33 kuruş
        let amount = 100
        let memberIds = [UUID(), UUID(), UUID()]
        
        let splits = computeSplits(
            amount: amount,
            type: .equal,
            memberIds: memberIds
        )
        
        XCTAssertEqual(splits.values.reduce(0, +), amount)
        let sortedShares = splits.values.sorted(by: >)
        XCTAssertEqual(sortedShares, [34, 33, 33])
    }

    func testItemSplitSumEqualsItemAmount() {
        // Her kalem için split toplamı = kalem amountMinor
        let amount = 250 // 2.50 TRY
        let memberIds = [UUID(), UUID(), UUID()]
        
        let splits = computeSplits(
            amount: amount,
            type: .equal,
            memberIds: memberIds
        )
        
        XCTAssertEqual(splits.values.reduce(0, +), amount)
    }

    func testTurkishLocaleAmountParsing() {
        let text = "Kebap 1.250,50"
        let parsed = ReceiptParser.parseReceiptText(text, currency: "TRY")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "Kebap")
        XCTAssertEqual(parsed[0].amountMinor, 125050)
    }

    func testSampleReceiptText() {
        let receiptText = """
        GROOPAY RESTORAN
        Tarih: 28.06.2026 Saat: 14:00
        Kasiyer: Ahmet
        ----------------------------
        1 Hamburger        150,50
        1 Pizza           220.00
        2 Kola             80,00
        ----------------------------
        Ara Toplam         450,00
        KDV                45,00
        GENEL TOPLAM       495,00
        Nakit              500,00
        Para Ustü            5,00
        """
        
        let parsed = ReceiptParser.parseReceiptText(receiptText, currency: "TRY")
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].name, "1 Hamburger")
        XCTAssertEqual(parsed[0].amountMinor, 15050)
        XCTAssertEqual(parsed[1].name, "1 Pizza")
        XCTAssertEqual(parsed[1].amountMinor, 22000)
        XCTAssertEqual(parsed[2].name, "2 Kola")
        XCTAssertEqual(parsed[2].amountMinor, 8000)
    }
}
