import Foundation

struct RecurringExpenseExecution: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let ruleId: UUID
    var executionDate: Date?
    var expenseId: UUID?
    var errorMessage: String?
    var executedAt: Date?
    var status: String // 'processing', 'success', 'failed'

    enum CodingKeys: String, CodingKey {
        case id
        case ruleId = "rule_id"
        case executionDate = "execution_date"
        case expenseId = "expense_id"
        case errorMessage = "error_message"
        case executedAt = "executed_at"
        case status
    }

    init(
        id: UUID = UUID(),
        ruleId: UUID,
        executionDate: Date? = nil,
        expenseId: UUID? = nil,
        errorMessage: String? = nil,
        executedAt: Date? = nil,
        status: String
    ) {
        self.id = id
        self.ruleId = ruleId
        self.executionDate = executionDate
        self.expenseId = expenseId
        self.errorMessage = errorMessage
        self.executedAt = executedAt
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ruleId = try container.decode(UUID.self, forKey: .ruleId)
        executionDate = try Self.decodeDate(from: container, forKey: .executionDate)
        expenseId = try container.decodeIfPresent(UUID.self, forKey: .expenseId)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        executedAt = try container.decodeIfPresent(Date.self, forKey: .executedAt)
        status = try container.decode(String.self, forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ruleId, forKey: .ruleId)
        try container.encodeIfPresent(executionDate, forKey: .executionDate)
        try container.encodeIfPresent(expenseId, forKey: .expenseId)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(executedAt, forKey: .executedAt)
        try container.encode(status, forKey: .status)
    }

    private static func decodeDate(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Date? {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        guard let raw = try? container.decode(String.self, forKey: key) else {
            return nil
        }
        return dateOnlyFormatter.date(from: raw)
            ?? ISO8601DateFormatter().date(from: raw)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
