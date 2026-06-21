import XCTest
@testable import Groopay

final class ExpenseEntryPreferencesTests: XCTestCase {
    func testPreferencePersistsPerGroup() throws {
        let suiteName = "ExpenseEntryPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ExpenseEntryPreferences(defaults: defaults)
        let firstGroup = UUID()
        let secondGroup = UUID()
        let preference = ExpenseEntryPreference(
            currency: "EUR",
            categoryID: "food",
            paidBy: UUID(),
            splitType: .subset
        )

        store.save(preference, for: firstGroup)

        XCTAssertEqual(store.preference(for: firstGroup), preference)
        XCTAssertNil(store.preference(for: secondGroup))
    }

    func testInvalidStoredDataIsIgnored() throws {
        let suiteName = "ExpenseEntryPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let groupID = UUID()
        defaults.set(Data("invalid".utf8), forKey: "expense-entry-preference.\(groupID.uuidString)")

        XCTAssertNil(
            ExpenseEntryPreferences(defaults: defaults).preference(for: groupID)
        )
    }
}
