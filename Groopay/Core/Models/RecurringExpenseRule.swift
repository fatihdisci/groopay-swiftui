import Foundation

enum RecurringFrequency: String, Codable, Sendable, CaseIterable {
    case weekly
    case monthly
    case yearly
}

struct RecurringSplitEntry: Codable, Equatable, Sendable {
    let memberId: UUID
    var shareAmount: Int

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case shareAmount = "share_amount"
    }

    init(memberId: UUID, shareAmount: Int) {
        self.memberId = memberId
        self.shareAmount = shareAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = try container.decode(UUID.self, forKey: .memberId)
        
        // We use "TRY" as default currency since standard active currencies have 2 decimals.
        // This matches the approach in Split.swift (ExpenseSplit).
        shareAmount = try container.decodeMinorAmount(
            forKey: .shareAmount,
            currency: "TRY"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        
        // Converts minor unit to Decimal for database storage (numeric(14,2))
        try container.encode(
            decimalAmount(fromMinor: shareAmount, currency: "TRY"),
            forKey: .shareAmount
        )
    }
}

struct RecurringExpenseRule: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let groupId: UUID
    var description: String
    var note: String?
    var amount: Int
    var currency: String
    var category: String
    var splitType: SplitType
    var paidBy: UUID
    var createdBy: UUID
    var frequency: RecurringFrequency
    var startDate: Date?
    var nextExecutionDate: Date?
    var isActive: Bool
    var splits: [RecurringSplitEntry]
    var createdAt: Date?
    var updatedAt: Date?

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
        case createdBy = "created_by"
        case frequency
        case startDate = "start_date"
        case nextExecutionDate = "next_execution_date"
        case isActive = "is_active"
        case splits
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
        createdBy: UUID,
        frequency: RecurringFrequency,
        startDate: Date? = nil,
        nextExecutionDate: Date? = nil,
        isActive: Bool = true,
        splits: [RecurringSplitEntry] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil
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
        self.createdBy = createdBy
        self.frequency = frequency
        self.startDate = startDate
        self.nextExecutionDate = nextExecutionDate
        self.isActive = isActive
        self.splits = splits
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
        createdBy = try container.decode(UUID.self, forKey: .createdBy)
        frequency = try container.decode(RecurringFrequency.self, forKey: .frequency)
        startDate = try Self.decodeDate(from: container, forKey: .startDate)
        nextExecutionDate = try Self.decodeDate(from: container, forKey: .nextExecutionDate)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        splits = try container.decode([RecurringSplitEntry].self, forKey: .splits)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
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
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(frequency, forKey: .frequency)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(nextExecutionDate, forKey: .nextExecutionDate)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(splits, forKey: .splits)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
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
