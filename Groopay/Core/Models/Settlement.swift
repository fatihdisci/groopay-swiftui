import Foundation

enum SettlementStatus: String, Codable, Sendable {
    case pending
    case confirmed
    case rejected
}

struct Settlement: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let groupId: UUID
    var fromMember: UUID
    var toMember: UUID
    var amount: Int
    var currency: String
    var status: SettlementStatus
    var markedBy: UUID
    var confirmedBy: UUID?
    var createdAt: Date?
    var confirmedAt: Date?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case fromMember = "from_member"
        case toMember = "to_member"
        case amount
        case currency
        case status
        case markedBy = "marked_by"
        case confirmedBy = "confirmed_by"
        case createdAt = "created_at"
        case confirmedAt = "confirmed_at"
        case note
    }

    init(
        id: UUID,
        groupId: UUID,
        fromMember: UUID,
        toMember: UUID,
        amount: Int,
        currency: String,
        status: SettlementStatus,
        markedBy: UUID,
        confirmedBy: UUID? = nil,
        createdAt: Date? = nil,
        confirmedAt: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.fromMember = fromMember
        self.toMember = toMember
        self.amount = amount
        self.currency = currency.uppercased()
        self.status = status
        self.markedBy = markedBy
        self.confirmedBy = confirmedBy
        self.createdAt = createdAt
        self.confirmedAt = confirmedAt
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        groupId = try container.decode(UUID.self, forKey: .groupId)
        fromMember = try container.decode(UUID.self, forKey: .fromMember)
        toMember = try container.decode(UUID.self, forKey: .toMember)
        currency = try container.decode(String.self, forKey: .currency).uppercased()
        amount = try container.decodeMinorAmount(
            forKey: .amount,
            currency: currency
        )
        status = try container.decode(SettlementStatus.self, forKey: .status)
        markedBy = try container.decode(UUID.self, forKey: .markedBy)
        confirmedBy = try container.decodeIfPresent(UUID.self, forKey: .confirmedBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        confirmedAt = try container.decodeIfPresent(Date.self, forKey: .confirmedAt)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(fromMember, forKey: .fromMember)
        try container.encode(toMember, forKey: .toMember)
        try container.encode(decimalAmount(fromMinor: amount, currency: currency), forKey: .amount)
        try container.encode(currency, forKey: .currency)
        try container.encode(status, forKey: .status)
        try container.encode(markedBy, forKey: .markedBy)
        try container.encodeIfPresent(confirmedBy, forKey: .confirmedBy)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(confirmedAt, forKey: .confirmedAt)
        try container.encodeIfPresent(note, forKey: .note)
    }
}
