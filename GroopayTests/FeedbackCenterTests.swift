import XCTest
@testable import Groopay

@MainActor
final class FeedbackCenterTests: XCTestCase {
    func testShowSetsCurrentMessageAndStyle() {
        let center = AppFeedbackCenter()
        center.success("Kaydedildi")
        XCTAssertEqual(center.current?.text, "Kaydedildi")
        XCTAssertEqual(center.current?.style, .success)
    }

    func testNewMessageReplacesPrevious() {
        let center = AppFeedbackCenter()
        center.info("ilk")
        let firstID = center.current?.id
        center.error("ikinci")

        // Aynı anda tek mesaj; yeni mesaj öncekini değiştirir.
        XCTAssertEqual(center.current?.text, "ikinci")
        XCTAssertEqual(center.current?.style, .error)
        XCTAssertNotEqual(center.current?.id, firstID)
    }

    func testActionableMessageKeepsActionTitle() {
        let center = AppFeedbackCenter()
        var undone = false
        center.show(
            "Masraf silindi.",
            style: .info,
            actionTitle: "Geri Al",
            action: { undone = true }
        )
        XCTAssertEqual(center.current?.actionTitle, "Geri Al")
        center.current?.action?()
        XCTAssertTrue(undone)
    }

    func testDismissClearsCurrent() {
        let center = AppFeedbackCenter()
        center.warning("dikkat")
        XCTAssertNotNil(center.current)
        center.dismiss()
        XCTAssertNil(center.current)
    }

    func testStyleMapping() {
        XCTAssertEqual(FeedbackStyle.success.tint, .credit)
        XCTAssertEqual(FeedbackStyle.error.tint, .debt)
        XCTAssertEqual(FeedbackStyle.warning.tint, .warning)
        XCTAssertEqual(FeedbackStyle.info.tint, .primaryTheme)
    }
}
