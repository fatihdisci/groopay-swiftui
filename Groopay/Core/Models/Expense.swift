import Foundation

struct Expense: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let groupId: UUID
    var description: String
    var note: String?
    var amount: Int
    var currency: String
    var category: String
    var splitType: SplitType
    var paidBy: UUID
    var expenseDate: Date?
    var createdBy: UUID
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case description
        case note
        case amount
        case currency
        case category
        case splitType = "split_type"
        case paidBy = "paid_by"
        case expenseDate = "expense_date"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(
        id: UUID,
        groupId: UUID,
        description: String,
        note: String? = nil,
        amount: Int,
        currency: String,
        category: String,
        splitType: SplitType,
        paidBy: UUID,
        expenseDate: Date? = nil,
        createdBy: UUID,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.description = description
        self.note = note
        self.amount = amount
        self.currency = currency.uppercased()
        self.category = category
        self.splitType = splitType
        self.paidBy = paidBy
        self.expenseDate = expenseDate
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        groupId = try container.decode(UUID.self, forKey: .groupId)
        description = try container.decode(String.self, forKey: .description)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        currency = try container.decode(String.self, forKey: .currency).uppercased()
        amount = try container.decodeMinorAmount(
            forKey: .amount,
            currency: currency
        )
        category = try container.decode(String.self, forKey: .category)
        splitType = try container.decode(SplitType.self, forKey: .splitType)
        paidBy = try container.decode(UUID.self, forKey: .paidBy)
        // expense_date Postgres `date` tipidir → "2026-06-15" (saatsiz) gelir.
        // Supabase çözücüsü timestamp beklediğinden Date decode'u patlayabilir;
        // toleranslı çöz: önce Date, olmazsa "yyyy-MM-dd" string'i ayrıştır.
        expenseDate = try Self.decodeDate(from: container, forKey: .expenseDate)
        createdBy = try container.decode(UUID.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(decimalAmount(fromMinor: amount, currency: currency), forKey: .amount)
        try container.encode(currency, forKey: .currency)
        try container.encode(category, forKey: .category)
        try container.encode(splitType, forKey: .splitType)
        try container.encode(paidBy, forKey: .paidBy)
        try container.encodeIfPresent(expenseDate, forKey: .expenseDate)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
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
