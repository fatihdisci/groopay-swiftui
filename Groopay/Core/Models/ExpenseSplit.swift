import Foundation

struct Split: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let expenseId: UUID
    let memberId: UUID
    var shareAmount: Int
    /// Split'in para birimi — parent expense ile aynıdır.
    /// CodingKeys'te yok, DB splits tablosunda da currency kolonu yok;
    /// varsayılan TRY. Çoklu-currency gelince expense_id JOIN ile çekilecek.
    var currency: String = "TRY"

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
        shareAmount: Int,
        currency: String = "TRY"
    ) {
        self.id = id
        self.expenseId = expenseId
        self.memberId = memberId
        self.shareAmount = shareAmount
        self.currency = currency.uppercased()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        expenseId = try container.decode(UUID.self, forKey: .expenseId)
        memberId = try container.decode(UUID.self, forKey: .memberId)
        currency = "TRY"
        shareAmount = try container.decodeMinorAmount(
            forKey: .shareAmount,
            currency: currency
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(expenseId, forKey: .expenseId)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(
            decimalAmount(fromMinor: shareAmount, currency: currency),
            forKey: .shareAmount
        )
    }
}
