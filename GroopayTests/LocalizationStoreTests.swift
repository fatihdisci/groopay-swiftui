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

    func testReleaseStringsHaveEnglishTranslations() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Groopay/Core/Localization/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try JSONDecoder().decode(LocalizationCatalog.self, from: data)
        let translations: [(key: String, expected: String)] = [
            ("tab.dashboard", "Dashboard"),
            ("Genel Durumun", "Your Overall Status"),
            ("Toplam Alacak", "Total Receivable"),
            ("Toplam Borç", "Total Debt"),
            (
                "Harcamaları bölüş, kimin ne ödeyeceğini gör, gruplarını tek yerde takip et.",
                "Split expenses, see who owes what, and manage all your groups in one place."
            ),
            ("Grupları yönet", "Manage Groups"),
            ("Adil paylaşım", "Fair Splitting"),
            ("Misafir başla", "Start as a Guest")
        ]

        for translation in translations {
            let entry = try XCTUnwrap(
                catalog.strings.first { $0.key == translation.key }?.value,
                "Missing localization key: \(translation.key)"
            )
            let english = try XCTUnwrap(
                entry.localizations?["en"],
                "Missing English localization: \(translation.key)"
            )
            XCTAssertEqual(english.stringUnit.value, translation.expected)
        }
    }
}

private struct LocalizationCatalog: Decodable {
    let strings: [String: LocalizationEntry]
}

private struct LocalizationEntry: Decodable {
    let localizations: [String: LocalizationValue]?
}

private struct LocalizationValue: Decodable {
    let stringUnit: LocalizationStringUnit
}

private struct LocalizationStringUnit: Decodable {
    let value: String
}
