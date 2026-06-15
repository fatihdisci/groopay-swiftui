import Foundation
import Supabase

@MainActor
enum PreviewSupport {
    static let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://preview.supabase.co")!,
        supabaseKey: "preview-anon-key"
    )

    static var authStore: AuthStore {
        AuthStore(supabase: supabase)
    }

    static var groupsStore: GroupsStore {
        GroupsStore(
            previewGroups: [snapshot],
            previewActivities: [
                Activity(
                    id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                    groupId: groupID,
                    actorMemberId: founderID,
                    actionType: "expense_added",
                    metadata: ["description": .string("Akşam yemeği")],
                    createdAt: Date()
                ),
                Activity(
                    id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
                    groupId: groupID,
                    actorMemberId: ghostID,
                    actionType: "member_joined",
                    createdAt: Date().addingTimeInterval(-90_000)
                )
            ],
            supabase: supabase
        )
    }

    static let groupID = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    )!
    static let founderID = UUID(
        uuidString: "22222222-2222-2222-2222-222222222222"
    )!
    static let ghostID = UUID(
        uuidString: "33333333-3333-3333-3333-333333333333"
    )!
    static let expenseID = UUID(
        uuidString: "44444444-4444-4444-4444-444444444444"
    )!

    static var snapshot: GroupSnapshot {
        GroupSnapshot(
            group: Group(
                id: groupID,
                name: "İtalya Tatili",
                photoURL: nil,
                baseCurrency: "EUR",
                createdBy: founderID,
                isPro: false,
                proPurchasedBy: nil,
                proPurchasedAt: nil,
                isDemo: false,
                archived: false,
                description: "Roma, Floransa ve bolca pizza",
                avatarEmoji: "✈️",
                avatarColor: "#6366F1",
                createdAt: nil
            ),
            members: [
                Member(
                    id: founderID,
                    groupId: groupID,
                    userId: founderID,
                    displayName: "Fatih",
                    avatarColor: "#6366F1",
                    role: .founder,
                    isActive: true,
                    createdAt: nil,
                    joinedAt: nil
                ),
                Member(
                    id: ghostID,
                    groupId: groupID,
                    userId: nil,
                    displayName: "Ayşe",
                    avatarColor: "#EC4899",
                    role: .member,
                    isActive: true,
                    createdAt: nil,
                    joinedAt: nil
                )
            ],
            expenses: [
                Expense(
                    id: expenseID,
                    groupId: groupID,
                    description: "Akşam yemeği",
                    amount: 84_00,
                    currency: "EUR",
                    category: "food",
                    splitType: .equal,
                    paidBy: founderID,
                    createdBy: founderID
                )
            ],
            splits: [
                Split(
                    id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                    expenseId: expenseID,
                    memberId: founderID,
                    shareAmount: 42_00
                ),
                Split(
                    id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                    expenseId: expenseID,
                    memberId: ghostID,
                    shareAmount: 42_00
                )
            ],
            settlements: []
        )
    }
}
