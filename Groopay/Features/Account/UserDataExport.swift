import Foundation

/// Kullanıcı veri dışa aktarımının Codable modeli. Para değerleri minor-unit
/// `Int` olarak korunur (modellerin backend Codable'ı major decimal'e çevirdiği
/// için burada AYRI export struct'ları kullanılır). JSON'da hiçbir secret,
/// access token, RevenueCat bilgisi veya push token bulunmaz.
struct UserDataExport: Codable, Equatable {
    let schemaVersion: Int
    let exportedAt: Date
    let profile: ExportProfile
    let groups: [ExportGroup]
    let activities: [ExportActivity]

    static let currentSchemaVersion = 1

    static func make(
        snapshots: [GroupSnapshot],
        profile: Profile?,
        activities: [Activity],
        exportedAt: Date = Date()
    ) -> UserDataExport {
        UserDataExport(
            schemaVersion: currentSchemaVersion,
            exportedAt: exportedAt,
            profile: ExportProfile(profile),
            groups: snapshots.map(ExportGroup.init),
            activities: activities.map(ExportActivity.init)
        )
    }

    /// UTF-8, prettyPrinted, sortedKeys JSON. Boş grupta da geçerli JSON üretir.
    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func fileName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return "groopay-export-\(formatter.string(from: date)).json"
    }
}

/// Yalnız güvenli profil alanları. expoPushToken ve benzeri hassas alanlar
/// bilerek dışarıda bırakılır.
struct ExportProfile: Codable, Equatable {
    let id: UUID?
    let displayName: String?
    let avatarColor: String?
    let locale: String?
    let userPro: Bool
    let createdAt: Date?

    init(_ profile: Profile?) {
        id = profile?.id
        displayName = profile?.displayName
        avatarColor = profile?.avatarColor
        locale = profile?.locale
        userPro = profile?.userPro ?? false
        createdAt = profile?.createdAt
    }
}

struct ExportGroup: Codable, Equatable {
    let group: ExportGroupInfo
    let members: [ExportMember]
    let expenses: [ExportExpense]
    let splits: [ExportSplit]
    let settlements: [ExportSettlement]

    init(_ snapshot: GroupSnapshot) {
        group = ExportGroupInfo(snapshot.group)
        members = snapshot.members.map(ExportMember.init)
        expenses = snapshot.expenses.map(ExportExpense.init)
        splits = snapshot.splits.map(ExportSplit.init)
        settlements = snapshot.settlements.map(ExportSettlement.init)
    }
}

struct ExportGroupInfo: Codable, Equatable {
    let id: UUID
    let name: String
    let baseCurrency: String
    let isDemo: Bool
    let archived: Bool
    let description: String?
    let avatarEmoji: String?
    let avatarColor: String
    let createdAt: Date?

    init(_ group: Group) {
        id = group.id
        name = group.name
        baseCurrency = group.baseCurrency
        isDemo = group.isDemo
        archived = group.archived
        description = group.description
        avatarEmoji = group.avatarEmoji
        avatarColor = group.avatarColor
        createdAt = group.createdAt
    }
}

struct ExportMember: Codable, Equatable {
    let id: UUID
    let userId: UUID?
    let displayName: String
    let avatarColor: String?
    let role: String
    let isActive: Bool
    let joinedAt: Date?

    init(_ member: Member) {
        id = member.id
        userId = member.userId
        displayName = member.displayName
        avatarColor = member.avatarColor
        role = member.role.rawValue
        isActive = member.isActive
        joinedAt = member.joinedAt
    }
}

struct ExportExpense: Codable, Equatable {
    let id: UUID
    let description: String
    let note: String?
    /// Minor-unit (kuruş) tam sayı — major decimal'e ÇEVRİLMEZ.
    let amountMinor: Int
    let currency: String
    let category: String
    let splitType: String
    let paidBy: UUID
    let expenseDate: Date?
    let createdBy: UUID
    let createdAt: Date?

    init(_ expense: Expense) {
        id = expense.id
        description = expense.description
        note = expense.note
        amountMinor = expense.amount
        currency = expense.currency
        category = expense.category
        splitType = expense.splitType.rawValue
        paidBy = expense.paidBy
        expenseDate = expense.expenseDate
        createdBy = expense.createdBy
        createdAt = expense.createdAt
    }
}

struct ExportSplit: Codable, Equatable {
    let id: UUID
    let expenseId: UUID
    let memberId: UUID
    let shareAmountMinor: Int
    let currency: String

    init(_ split: Split) {
        id = split.id
        expenseId = split.expenseId
        memberId = split.memberId
        shareAmountMinor = split.shareAmount
        currency = split.currency
    }
}

struct ExportSettlement: Codable, Equatable {
    let id: UUID
    let fromMember: UUID
    let toMember: UUID
    let amountMinor: Int
    let currency: String
    let status: String
    let createdAt: Date?
    let confirmedAt: Date?

    init(_ settlement: Settlement) {
        id = settlement.id
        fromMember = settlement.fromMember
        toMember = settlement.toMember
        amountMinor = settlement.amount
        currency = settlement.currency
        status = settlement.status.rawValue
        createdAt = settlement.createdAt
        confirmedAt = settlement.confirmedAt
    }
}

struct ExportActivity: Codable, Equatable {
    let id: UUID
    let groupId: UUID
    let actorMemberId: UUID?
    let actionType: String
    let createdAt: Date?

    init(_ activity: Activity) {
        id = activity.id
        groupId = activity.groupId
        actorMemberId = activity.actorMemberId
        actionType = activity.actionType
        createdAt = activity.createdAt
    }
}
