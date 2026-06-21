import Foundation

struct ExpenseEntryPreference: Codable, Equatable, Sendable {
    let currency: String
    let categoryID: String
    let paidBy: UUID
    let splitType: SplitType
}

struct ExpenseEntryPreferences {
    private let defaults: UserDefaults
    private let keyPrefix = "expense-entry-preference."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func preference(for groupID: UUID) -> ExpenseEntryPreference? {
        guard let data = defaults.data(forKey: keyPrefix + groupID.uuidString) else {
            return nil
        }
        return try? JSONDecoder().decode(ExpenseEntryPreference.self, from: data)
    }

    func save(_ preference: ExpenseEntryPreference, for groupID: UUID) {
        guard let data = try? JSONEncoder().encode(preference) else { return }
        defaults.set(data, forKey: keyPrefix + groupID.uuidString)
    }
}
