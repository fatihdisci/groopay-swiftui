import Foundation

enum MemberRole: String, Codable, Sendable {
    case founder
    case member
}

struct Member: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let groupId: UUID
    var userId: UUID?
    var displayName: String
    var avatarColor: String?
    var role: MemberRole
    var isActive: Bool
    var createdAt: Date?
    var joinedAt: Date?

    var isGhost: Bool {
        userId == nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case displayName = "display_name"
        case avatarColor = "avatar_color"
        case role
        case isActive = "is_active"
        case createdAt = "created_at"
        case joinedAt = "joined_at"
    }
}
