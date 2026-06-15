import XCTest
@testable import Groopay

@MainActor
final class LocalizationStoreTests: XCTestCase {
    func testAutomaticLanguageUsesFirstSupportedDeviceLanguage() {
        XCTAssertEqual(
            LocalizationStore.supportedLanguageCode(
                from: ["de-DE", "en-US", "tr-TR"]
            ),
            "en"
        )
        XCTAssertEqual(
            LocalizationStore.supportedLanguageCode(
                from: ["de-DE", "fr-FR"]
            ),
            "tr"
        )
    }

    func testSelectionPersistsAndOverridesDeviceLanguage() {
        let suiteName = "LocalizationStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LocalizationStore(
            defaults: defaults,
            preferredLanguages: { ["en-US"] }
        )
        XCTAssertEqual(store.selection, .automatic)
        XCTAssertEqual(store.languageCode, "en")

        store.select(.turkish)

        let restored = LocalizationStore(
            defaults: defaults,
            preferredLanguages: { ["en-US"] }
        )
        XCTAssertEqual(restored.selection, .turkish)
        XCTAssertEqual(restored.languageCode, "tr")
    }
}
