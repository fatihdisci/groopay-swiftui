import Foundation
import Supabase

@MainActor
enum PreviewSupport {
    static let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://preview.supabase.co")!,
        supabaseKey: "preview-anon-key"
    )

    static let userID = uuid("22222222-2222-2222-2222-222222222222")
    static let groupID = uuid("11111111-1111-1111-1111-111111111111")
    static let founderID = uuid("33333333-3333-3333-3333-333333333301")
    static let ghostID = uuid("33333333-3333-3333-3333-333333333302")
    static let expenseID = uuid("44444444-4444-4444-4444-444444444401")

    static var authStore: AuthStore {
        AuthStore(previewProfile: previewProfile, supabase: supabase)
    }

    static var groupsStore: GroupsStore {
        GroupsStore(
            previewGroups: snapshots,
            previewActivities: activities,
            previewUserID: userID,
            supabase: supabase
        )
    }

    static var snapshot: GroupSnapshot {
        snapshots[0]
    }

    private static var previewProfile: Profile {
        Profile(
            id: userID,
            displayName: "Fatih",
            avatarColor: "#6366F1",
            locale: isEnglish ? "en" : "tr",
            preferredCurrency: isEnglish ? "USD" : "TRY",
            expoPushToken: nil,
            userPro: true,
            userProPurchasedAt: Date().addingTimeInterval(-2_592_000),
            createdAt: Date().addingTimeInterval(-7_776_000)
        )
    }

    private static var snapshots: [GroupSnapshot] {
        [
            tripSnapshot,
            homeSnapshot,
            officeSnapshot
        ]
    }

    private static var activities: [Activity] {
        let now = Date()
        let data = copy

        return [
            activity(
                "77777777-7777-7777-7777-777777777701",
                groupID: groupID,
                actor: founderID,
                type: "expense_added",
                description: data.tripDinner,
                amount: 128_40,
                currency: "EUR",
                date: now.addingTimeInterval(-900)
            ),
            activity(
                "77777777-7777-7777-7777-777777777702",
                groupID: homeGroupID,
                actor: homeAylinID,
                type: "expense_added",
                description: data.homeGroceries,
                amount: 2_180_00,
                currency: "TRY",
                date: now.addingTimeInterval(-4_200)
            ),
            activity(
                "77777777-7777-7777-7777-777777777703",
                groupID: officeGroupID,
                actor: officeFatihID,
                type: "settlement_confirmed",
                description: data.officeCoffee,
                amount: 18_00,
                currency: "USD",
                date: now.addingTimeInterval(-8_400)
            ),
            activity(
                "77777777-7777-7777-7777-777777777704",
                groupID: groupID,
                actor: ghostID,
                type: "expense_updated",
                description: data.tripMuseum,
                amount: 72_00,
                currency: "EUR",
                date: now.addingTimeInterval(-86_000)
            ),
            activity(
                "77777777-7777-7777-7777-777777777705",
                groupID: homeGroupID,
                actor: homeDenizID,
                type: "member_joined",
                date: now.addingTimeInterval(-92_000)
            ),
            activity(
                "77777777-7777-7777-7777-777777777706",
                groupID: officeGroupID,
                actor: officeSelinID,
                type: "expense_added",
                description: data.officeLunch,
                amount: 96_50,
                currency: "USD",
                date: now.addingTimeInterval(-172_000)
            )
        ]
    }

    private static var tripSnapshot: GroupSnapshot {
        let data = copy
        let members = [
            member(founderID, groupID: groupID, userID: userID, name: "Fatih", color: "#6366F1", role: .founder),
            member(ghostID, groupID: groupID, name: data.personOne, color: "#EC4899"),
            member(tripMertID, groupID: groupID, name: data.personTwo, color: "#10B981")
        ]
        let expenses = [
            expense(expenseID, groupID: groupID, description: data.tripDinner, amount: 128_40, currency: "EUR", category: "food", paidBy: founderID),
            expense(tripHotelExpenseID, groupID: groupID, description: data.tripHotel, amount: 312_00, currency: "EUR", category: "accommodation", paidBy: ghostID),
            expense(tripMuseumExpenseID, groupID: groupID, description: data.tripMuseum, amount: 72_00, currency: "EUR", category: "entertainment", paidBy: tripMertID),
            expense(tripTaxiExpenseID, groupID: groupID, description: data.tripTaxi, amount: 38_50, currency: "EUR", category: "transport", paidBy: founderID)
        ]

        return GroupSnapshot(
            group: group(
                groupID,
                name: data.tripName,
                currency: "EUR",
                description: data.tripDescription,
                emoji: "✈️",
                color: "#6366F1"
            ),
            members: members,
            expenses: expenses,
            splits: [
                split("55555555-5555-5555-5555-555555555501", expenseID, founderID, 42_80),
                split("55555555-5555-5555-5555-555555555502", expenseID, ghostID, 42_80),
                split("55555555-5555-5555-5555-555555555503", expenseID, tripMertID, 42_80),
                split("55555555-5555-5555-5555-555555555504", tripHotelExpenseID, founderID, 104_00),
                split("55555555-5555-5555-5555-555555555505", tripHotelExpenseID, ghostID, 104_00),
                split("55555555-5555-5555-5555-555555555506", tripHotelExpenseID, tripMertID, 104_00),
                split("55555555-5555-5555-5555-555555555507", tripMuseumExpenseID, founderID, 24_00),
                split("55555555-5555-5555-5555-555555555508", tripMuseumExpenseID, ghostID, 24_00),
                split("55555555-5555-5555-5555-555555555509", tripMuseumExpenseID, tripMertID, 24_00),
                split("55555555-5555-5555-5555-555555555510", tripTaxiExpenseID, founderID, 12_84),
                split("55555555-5555-5555-5555-555555555511", tripTaxiExpenseID, ghostID, 12_83),
                split("55555555-5555-5555-5555-555555555512", tripTaxiExpenseID, tripMertID, 12_83)
            ],
            settlements: [
                settlement("99999999-9999-9999-9999-999999999901", groupID: groupID, from: tripMertID, to: founderID, amount: 42_80, currency: "EUR", status: .pending)
            ]
        )
    }

    private static var homeSnapshot: GroupSnapshot {
        let data = copy
        let expenses = [
            expense(homeGroceryExpenseID, groupID: homeGroupID, description: data.homeGroceries, amount: 2_180_00, currency: "TRY", category: "groceries", paidBy: homeAylinID),
            expense(homeBillExpenseID, groupID: homeGroupID, description: data.homeBills, amount: 1_460_00, currency: "TRY", category: "bills", paidBy: homeFatihID),
            expense(homeShoppingExpenseID, groupID: homeGroupID, description: data.homeSupplies, amount: 740_00, currency: "TRY", category: "shopping", paidBy: homeDenizID)
        ]

        return GroupSnapshot(
            group: group(
                homeGroupID,
                name: data.homeName,
                currency: "TRY",
                description: data.homeDescription,
                emoji: "🏠",
                color: "#10B981"
            ),
            members: [
                member(homeFatihID, groupID: homeGroupID, userID: userID, name: "Fatih", color: "#6366F1", role: .founder),
                member(homeAylinID, groupID: homeGroupID, name: data.personThree, color: "#F59E0B"),
                member(homeDenizID, groupID: homeGroupID, name: data.personFour, color: "#3B82F6")
            ],
            expenses: expenses,
            splits: equalSplits(
                [
                    (homeGroceryExpenseID, 2_180_00, [homeFatihID, homeAylinID, homeDenizID]),
                    (homeBillExpenseID, 1_460_00, [homeFatihID, homeAylinID]),
                    (homeShoppingExpenseID, 740_00, [homeFatihID, homeAylinID, homeDenizID])
                ],
                prefix: "56565656-5656-5656-5656-5656565656"
            ),
            settlements: [
                settlement("99999999-9999-9999-9999-999999999902", groupID: homeGroupID, from: homeDenizID, to: homeFatihID, amount: 320_00, currency: "TRY", status: .confirmed)
            ]
        )
    }

    private static var officeSnapshot: GroupSnapshot {
        let data = copy
        let expenses = [
            expense(officeLunchExpenseID, groupID: officeGroupID, description: data.officeLunch, amount: 96_50, currency: "USD", category: "food", paidBy: officeSelinID),
            expense(officeCoffeeExpenseID, groupID: officeGroupID, description: data.officeCoffee, amount: 54_00, currency: "USD", category: "food", paidBy: officeFatihID),
            expense(officeTaxiExpenseID, groupID: officeGroupID, description: data.officeTaxi, amount: 42_75, currency: "USD", category: "transport", paidBy: officeFatihID)
        ]

        return GroupSnapshot(
            group: group(
                officeGroupID,
                name: data.officeName,
                currency: "USD",
                description: data.officeDescription,
                emoji: "💼",
                color: "#8B5CF6"
            ),
            members: [
                member(officeFatihID, groupID: officeGroupID, userID: userID, name: "Fatih", color: "#6366F1", role: .founder),
                member(officeSelinID, groupID: officeGroupID, name: data.personFive, color: "#EC4899"),
                member(officeCanID, groupID: officeGroupID, name: data.personSix, color: "#14B8A6")
            ],
            expenses: expenses,
            splits: equalSplits(
                [
                    (officeLunchExpenseID, 96_50, [officeFatihID, officeSelinID, officeCanID]),
                    (officeCoffeeExpenseID, 54_00, [officeFatihID, officeSelinID, officeCanID]),
                    (officeTaxiExpenseID, 42_75, [officeFatihID, officeCanID])
                ],
                prefix: "57575757-5757-5757-5757-5757575757"
            ),
            settlements: []
        )
    }

    private static var copy: DemoCopy {
        isEnglish ? .english : .turkish
    }

    private static var isEnglish: Bool {
        LocalizationStore.currentLocale().language.languageCode?.identifier == "en"
    }

    private static func group(
        _ id: UUID,
        name: String,
        currency: String,
        description: String,
        emoji: String,
        color: String
    ) -> Group {
        Group(
            id: id,
            name: name,
            photoURL: nil,
            baseCurrency: currency,
            createdBy: userID,
            isPro: true,
            proPurchasedBy: userID,
            proPurchasedAt: Date().addingTimeInterval(-2_592_000),
            isDemo: false,
            archived: false,
            description: description,
            avatarEmoji: emoji,
            avatarColor: color,
            createdAt: Date().addingTimeInterval(-604_800)
        )
    }

    private static func member(
        _ id: UUID,
        groupID: UUID,
        userID: UUID? = nil,
        name: String,
        color: String,
        role: MemberRole = .member
    ) -> Member {
        Member(
            id: id,
            groupId: groupID,
            userId: userID,
            displayName: name,
            avatarColor: color,
            role: role,
            isActive: true,
            createdAt: Date().addingTimeInterval(-604_800),
            joinedAt: Date().addingTimeInterval(-604_800)
        )
    }

    private static func expense(
        _ id: UUID,
        groupID: UUID,
        description: String,
        amount: Int,
        currency: String,
        category: String,
        paidBy: UUID
    ) -> Expense {
        Expense(
            id: id,
            groupId: groupID,
            description: description,
            amount: amount,
            currency: currency,
            category: category,
            splitType: .equal,
            paidBy: paidBy,
            expenseDate: Date(),
            createdBy: paidBy,
            createdAt: Date().addingTimeInterval(-86_400)
        )
    }

    private static func split(
        _ id: String,
        _ expenseID: UUID,
        _ memberID: UUID,
        _ amount: Int
    ) -> Split {
        Split(id: uuid(id), expenseId: expenseID, memberId: memberID, shareAmount: amount)
    }

    private static func equalSplits(
        _ rows: [(expenseID: UUID, amount: Int, members: [UUID])],
        prefix: String
    ) -> [Split] {
        var output: [Split] = []
        var index = 1
        for row in rows {
            let base = row.amount / row.members.count
            var remainder = row.amount % row.members.count
            for memberID in row.members {
                let share = base + (remainder > 0 ? 1 : 0)
                remainder = max(remainder - 1, 0)
                output.append(
                    split(
                        "\(prefix)\(String(format: "%02d", index))",
                        row.expenseID,
                        memberID,
                        share
                    )
                )
                index += 1
            }
        }
        return output
    }

    private static func settlement(
        _ id: String,
        groupID: UUID,
        from: UUID,
        to: UUID,
        amount: Int,
        currency: String,
        status: SettlementStatus
    ) -> Settlement {
        Settlement(
            id: uuid(id),
            groupId: groupID,
            fromMember: from,
            toMember: to,
            amount: amount,
            currency: currency,
            status: status,
            markedBy: from,
            confirmedBy: status == .confirmed ? to : nil,
            createdAt: Date().addingTimeInterval(-42_000),
            confirmedAt: status == .confirmed ? Date().addingTimeInterval(-21_000) : nil
        )
    }

    private static func activity(
        _ id: String,
        groupID: UUID,
        actor: UUID,
        type: String,
        description: String? = nil,
        amount: Int? = nil,
        currency: String? = nil,
        date: Date
    ) -> Activity {
        var metadata: [String: JSONValue] = [:]
        if let description {
            metadata["description"] = .string(description)
        }
        if let amount {
            metadata["amount"] = .integer(amount)
        }
        if let currency {
            metadata["currency"] = .string(currency)
        }

        return Activity(
            id: uuid(id),
            groupId: groupID,
            actorMemberId: actor,
            actionType: type,
            metadata: metadata,
            createdAt: date
        )
    }

    private static func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }

    private static let tripMertID = uuid("33333333-3333-3333-3333-333333333303")
    private static let homeGroupID = uuid("11111111-1111-1111-1111-111111111112")
    private static let homeFatihID = uuid("33333333-3333-3333-3333-333333333311")
    private static let homeAylinID = uuid("33333333-3333-3333-3333-333333333312")
    private static let homeDenizID = uuid("33333333-3333-3333-3333-333333333313")
    private static let officeGroupID = uuid("11111111-1111-1111-1111-111111111113")
    private static let officeFatihID = uuid("33333333-3333-3333-3333-333333333321")
    private static let officeSelinID = uuid("33333333-3333-3333-3333-333333333322")
    private static let officeCanID = uuid("33333333-3333-3333-3333-333333333323")

    private static let tripHotelExpenseID = uuid("44444444-4444-4444-4444-444444444402")
    private static let tripMuseumExpenseID = uuid("44444444-4444-4444-4444-444444444403")
    private static let tripTaxiExpenseID = uuid("44444444-4444-4444-4444-444444444404")
    private static let homeGroceryExpenseID = uuid("44444444-4444-4444-4444-444444444411")
    private static let homeBillExpenseID = uuid("44444444-4444-4444-4444-444444444412")
    private static let homeShoppingExpenseID = uuid("44444444-4444-4444-4444-444444444413")
    private static let officeLunchExpenseID = uuid("44444444-4444-4444-4444-444444444421")
    private static let officeCoffeeExpenseID = uuid("44444444-4444-4444-4444-444444444422")
    private static let officeTaxiExpenseID = uuid("44444444-4444-4444-4444-444444444423")
}

private struct DemoCopy {
    let tripName: String
    let tripDescription: String
    let tripDinner: String
    let tripHotel: String
    let tripMuseum: String
    let tripTaxi: String
    let homeName: String
    let homeDescription: String
    let homeGroceries: String
    let homeBills: String
    let homeSupplies: String
    let officeName: String
    let officeDescription: String
    let officeLunch: String
    let officeCoffee: String
    let officeTaxi: String
    let personOne: String
    let personTwo: String
    let personThree: String
    let personFour: String
    let personFive: String
    let personSix: String

    static let turkish = DemoCopy(
        tripName: "İtalya Tatili",
        tripDescription: "Roma, Floransa ve ortak seyahat masrafları",
        tripDinner: "Trastevere akşam yemeği",
        tripHotel: "Floransa oteli",
        tripMuseum: "Vatikan müze biletleri",
        tripTaxi: "Havalimanı taksisi",
        homeName: "Ev Arkadaşları",
        homeDescription: "Kira dışı market, fatura ve ev alışverişleri",
        homeGroceries: "Haftalık market",
        homeBills: "Elektrik ve internet",
        homeSupplies: "Temizlik malzemeleri",
        officeName: "Ürün Ekibi",
        officeDescription: "Öğle yemeği, kahve ve toplantı ulaşımı",
        officeLunch: "Sprint öğle yemeği",
        officeCoffee: "Takım kahveleri",
        officeTaxi: "Müşteri toplantısı taksisi",
        personOne: "Ayşe",
        personTwo: "Mert",
        personThree: "Aylin",
        personFour: "Deniz",
        personFive: "Selin",
        personSix: "Can"
    )

    static let english = DemoCopy(
        tripName: "Italy Trip",
        tripDescription: "Rome, Florence, and shared travel costs",
        tripDinner: "Trastevere dinner",
        tripHotel: "Florence hotel",
        tripMuseum: "Vatican museum tickets",
        tripTaxi: "Airport taxi",
        homeName: "Flatmates",
        homeDescription: "Groceries, utilities, and shared home supplies",
        homeGroceries: "Weekly groceries",
        homeBills: "Electricity and internet",
        homeSupplies: "Cleaning supplies",
        officeName: "Product Team",
        officeDescription: "Lunches, coffee, and meeting transport",
        officeLunch: "Sprint lunch",
        officeCoffee: "Team coffee",
        officeTaxi: "Client meeting taxi",
        personOne: "Ava",
        personTwo: "Noah",
        personThree: "Mia",
        personFour: "Deniz",
        personFive: "Lina",
        personSix: "Can"
    )
}
