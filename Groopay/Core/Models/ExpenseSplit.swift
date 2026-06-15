import Foundation

struct Split: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let expenseId: UUID
    let memberId: UUID
    var shareAmount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case expenseId = "expense_id"
        case memberId = "member_id"
        case shareAmount = "share_amount"
    }

    init(
        id: UUID,
        expenseId: UUID,
        memberId: UUID,
        shareAmount: Int
    ) {
        self.id = id
        self.expenseId = expenseId
        self.memberId = memberId
        self.shareAmount = shareAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        expenseId = try container.decode(UUID.self, forKey: .expenseId)
        memberId = try container.decode(UUID.self, forKey: .memberId)
        shareAmount = try container.decodeMinorAmount(
            forKey: .shareAmount,
            currency: "TRY"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(expenseId, forKey: .expenseId)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(
            decimalAmount(fromMinor: shareAmount, currency: "TRY"),
            forKey: .shareAmount
        )
    }
}
