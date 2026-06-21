import Foundation
@testable import Groopay

/// Saf model testleri için hafif fixture üreticileri. PreviewSupport @MainActor
/// ve Supabase'e bağlı olduğundan testlerde doğrudan kullanılmaz.
enum Fixtures {
    static func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }

    static func group(
        id: UUID,
        name: String = "Grup",
        createdBy: UUID = uuid("00000000-0000-0000-0000-0000000000AA"),
        baseCurrency: String = "TRY",
        isDemo: Bool = false
    ) -> Group {
        Group(
            id: id,
            name: name,
            photoURL: nil,
            baseCurrency: baseCurrency,
            createdBy: createdBy,
            isPro: false,
            proPurchasedBy: nil,
            proPurchasedAt: nil,
            isDemo: isDemo,
            archived: false,
            description: nil,
            avatarEmoji: nil,
            avatarColor: "#6366F1",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func member(
        id: UUID,
        groupId: UUID,
        userId: UUID? = nil,
        name: String = "Üye",
        role: MemberRole = .member,
        isActive: Bool = true
    ) -> Member {
        Member(
            id: id,
            groupId: groupId,
            userId: userId,
            displayName: name,
            avatarColor: "#6366F1",
            role: role,
            isActive: isActive,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func expense(
        id: UUID,
        groupId: UUID,
        amount: Int,
        currency: String = "TRY",
        paidBy: UUID,
        category: String = "food",
        description: String = "Masraf",
        date: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Expense {
        Expense(
            id: id,
            groupId: groupId,
            description: description,
            amount: amount,
            currency: currency,
            category: category,
            splitType: .equal,
            paidBy: paidBy,
            expenseDate: date,
            createdBy: paidBy,
            createdAt: date
        )
    }

    static func split(
        id: UUID,
        expenseId: UUID,
        memberId: UUID,
        amount: Int,
        currency: String = "TRY"
    ) -> Split {
        Split(
            id: id,
            expenseId: expenseId,
            memberId: memberId,
            shareAmount: amount,
            currency: currency
        )
    }

    static func settlement(
        id: UUID,
        groupId: UUID,
        from: UUID,
        to: UUID,
        amount: Int,
        currency: String = "TRY",
        status: SettlementStatus = .pending
    ) -> Settlement {
        Settlement(
            id: id,
            groupId: groupId,
            fromMember: from,
            toMember: to,
            amount: amount,
            currency: currency,
            status: status,
            markedBy: from,
            confirmedBy: status == .confirmed ? to : nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            confirmedAt: status == .confirmed ? Date(timeIntervalSince1970: 1_700_000_500) : nil
        )
    }

    static func activity(
        id: UUID,
        groupId: UUID,
        actor: UUID? = nil,
        type: String = "expense_added",
        description: String? = nil,
        currency: String? = nil,
        amount: Int? = nil,
        date: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Activity {
        var metadata: [String: JSONValue] = [:]
        if let description { metadata["description"] = .string(description) }
        if let currency { metadata["currency"] = .string(currency) }
        if let amount { metadata["amount"] = .integer(amount) }
        return Activity(
            id: id,
            groupId: groupId,
            actorMemberId: actor,
            actionType: type,
            metadata: metadata,
            createdAt: date
        )
    }
}
