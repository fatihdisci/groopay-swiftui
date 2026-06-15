import Foundation

struct Profile: Codable, Equatable, Sendable {
    let id: UUID
    var displayName: String
    var avatarColor: String
    var locale: String
    var preferredCurrency: String?
    var expoPushToken: String?
    var userPro: Bool
    var userProPurchasedAt: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarColor = "avatar_color"
        case locale
        case preferredCurrency = "preferred_currency"
        case expoPushToken = "expo_push_token"
        case userPro = "user_pro"
        case userProPurchasedAt = "user_pro_purchased_at"
        case createdAt = "created_at"
    }
}
