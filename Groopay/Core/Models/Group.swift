import Foundation

struct Group: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var photoURL: String?
    var baseCurrency: String
    var createdBy: UUID
    var isPro: Bool
    var proPurchasedBy: UUID?
    var proPurchasedAt: Date?
    var isDemo: Bool
    var archived: Bool
    var description: String?
    var avatarEmoji: String?
    var avatarColor: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case photoURL = "photo_url"
        case baseCurrency = "base_currency"
        case createdBy = "created_by"
        case isPro = "is_pro"
        case proPurchasedBy = "pro_purchased_by"
        case proPurchasedAt = "pro_purchased_at"
        case isDemo = "is_demo"
        case archived
        case description
        case avatarEmoji = "avatar_emoji"
        case avatarColor = "avatar_color"
        case createdAt = "created_at"
    }
}
