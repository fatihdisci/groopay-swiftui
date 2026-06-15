import Foundation

struct Activity: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let groupId: UUID
    var actorMemberId: UUID?
    var actionType: String
    var targetType: String?
    var targetId: UUID?
    var metadata: [String: JSONValue]
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case actorMemberId = "actor_member_id"
        case actionType = "action_type"
        case targetType = "target_type"
        case targetId = "target_id"
        case metadata
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        groupId = try container.decode(UUID.self, forKey: .groupId)
        actorMemberId = try container.decodeIfPresent(UUID.self, forKey: .actorMemberId)
        actionType = try container.decode(String.self, forKey: .actionType)
        targetType = try container.decodeIfPresent(String.self, forKey: .targetType)
        targetId = try container.decodeIfPresent(UUID.self, forKey: .targetId)
        // metadata jsonb null/eksik olabilir → boş sözlüğe düş.
        metadata = (try? container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)) ?? [:]
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    init(
        id: UUID,
        groupId: UUID,
        actorMemberId: UUID? = nil,
        actionType: String,
        targetType: String? = nil,
        targetId: UUID? = nil,
        metadata: [String: JSONValue] = [:],
        createdAt: Date? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.actorMemberId = actorMemberId
        self.actionType = actionType
        self.targetType = targetType
        self.targetId = targetId
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

extension JSONValue {
    var stringValue: String? {
        switch self {
        case .string(let value): value
        case .integer(let value): String(value)
        case .decimal(let value): "\(value)"
        case .boolean(let value): value ? "true" : "false"
        case .object, .array, .null: nil
        }
    }
}
