#if TESTFLIGHT_DEV
import Foundation

@MainActor
enum DeveloperTestData {
    private static let groupPrefix = "🧪 "

    static func seed(
        store: GroupsStore,
        profile: Profile?,
        languageCode: String
    ) async throws {
        guard let profile else { throw DeveloperTestDataError.signedOut }
        await store.load()

        for specification in specifications(isEnglish: languageCode == "en") {
            try await seedGroup(
                specification,
                store: store,
                displayName: profile.displayName
            )
        }
    }

    static func remove(from store: GroupsStore) async throws {
        await store.load()
        let groupIDs = store.groups
            .filter { $0.group.name.hasPrefix(groupPrefix) }
            .map(\.id)

        for groupID in groupIDs {
            guard await store.deleteGroup(groupID) else {
                throw DeveloperTestDataError.operationFailed(store.errorMessage)
            }
        }
    }

    private static func seedGroup(
        _ specification: GroupSpecification,
        store: GroupsStore,
        displayName: String
    ) async throws {
        if !store.groups.contains(where: { $0.group.name == specification.name }) {
            guard await store.createGroup(
                name: specification.name,
                displayName: displayName,
                currency: specification.currency
            ) else {
                throw DeveloperTestDataError.operationFailed(store.errorMessage)
            }
        }

        guard let groupID = store.groups.first(where: {
            $0.group.name == specification.name
        })?.id else {
            throw DeveloperTestDataError.groupNotFound
        }

        for ghostName in specification.ghostNames {
            let alreadyExists = store.snapshot(groupID)?.members.contains {
                $0.displayName == ghostName
            } == true
            if !alreadyExists {
                guard await store.addGhost(groupID: groupID, displayName: ghostName) else {
                    throw DeveloperTestDataError.operationFailed(store.errorMessage)
                }
            }
        }

        for expense in specification.expenses {
            guard let snapshot = store.snapshot(groupID),
                  let currentMember = snapshot.currentMember(userID: store.currentUserID)
            else {
                throw DeveloperTestDataError.membersNotFound
            }

            if snapshot.expenses.contains(where: { $0.description == expense.description }) {
                continue
            }

            let ghosts = specification.ghostNames.compactMap { name in
                snapshot.members.first { $0.displayName == name }
            }
            let members = [currentMember] + ghosts
            guard members.count == specification.ghostNames.count + 1,
                  members.indices.contains(expense.payerIndex)
            else {
                throw DeveloperTestDataError.membersNotFound
            }

            guard await store.addExpense(
                groupID: groupID,
                description: expense.description,
                note: expense.note,
                amount: expense.amount,
                currency: specification.currency,
                category: expense.category,
                splitType: .equal,
                paidBy: members[expense.payerIndex].id,
                splits: equalSplits(total: expense.amount, members: members),
                date: Calendar.current.date(
                    byAdding: .day,
                    value: -expense.daysAgo,
                    to: Date()
                ) ?? Date()
            ) else {
                throw DeveloperTestDataError.operationFailed(store.errorMessage)
            }
        }
    }

    private static func equalSplits(
        total: Int,
        members: [Member]
    ) -> [UUID: Int] {
        guard !members.isEmpty else { return [:] }
        let base = total / members.count
        let remainder = total % members.count
        return Dictionary(uniqueKeysWithValues: members.enumerated().map { index, member in
            (member.id, base + (index < remainder ? 1 : 0))
        })
    }

    private static func specifications(isEnglish: Bool) -> [GroupSpecification] {
        if isEnglish {
            return [
                GroupSpecification(
                    name: "\(groupPrefix)Weekend Trip",
                    currency: "TRY",
                    ghostNames: ["Alex", "Taylor"],
                    expenses: [
                        ExpenseSpecification(description: "Breakfast", note: "Seaside café", amount: 126_000, category: "food", payerIndex: 0, daysAgo: 1),
                        ExpenseSpecification(description: "Fuel", note: "Round trip", amount: 84_000, category: "transport", payerIndex: 1, daysAgo: 2),
                        ExpenseSpecification(description: "Groceries", note: nil, amount: 47_550, category: "groceries", payerIndex: 2, daysAgo: 3)
                    ]
                ),
                GroupSpecification(
                    name: "\(groupPrefix)Housemates",
                    currency: "USD",
                    ghostNames: ["Morgan", "Sam"],
                    expenses: [
                        ExpenseSpecification(description: "Rent", note: "June", amount: 120_000, category: "accommodation", payerIndex: 1, daysAgo: 5),
                        ExpenseSpecification(description: "Internet", note: nil, amount: 6_600, category: "bills", payerIndex: 0, daysAgo: 4),
                        ExpenseSpecification(description: "Dinner", note: "Friday night", amount: 9_300, category: "food", payerIndex: 2, daysAgo: 1)
                    ]
                )
            ]
        }

        return [
            GroupSpecification(
                name: "\(groupPrefix)Hafta Sonu",
                currency: "TRY",
                ghostNames: ["Ayşe", "Mert"],
                expenses: [
                    ExpenseSpecification(description: "Kahvaltı", note: "Sahil kafesi", amount: 126_000, category: "food", payerIndex: 0, daysAgo: 1),
                    ExpenseSpecification(description: "Yakıt", note: "Gidiş dönüş", amount: 84_000, category: "transport", payerIndex: 1, daysAgo: 2),
                    ExpenseSpecification(description: "Market", note: nil, amount: 47_550, category: "groceries", payerIndex: 2, daysAgo: 3)
                ]
            ),
            GroupSpecification(
                name: "\(groupPrefix)Ev Arkadaşları",
                currency: "USD",
                ghostNames: ["Ece", "Can"],
                expenses: [
                    ExpenseSpecification(description: "Kira", note: "Haziran", amount: 120_000, category: "accommodation", payerIndex: 1, daysAgo: 5),
                    ExpenseSpecification(description: "İnternet", note: nil, amount: 6_600, category: "bills", payerIndex: 0, daysAgo: 4),
                    ExpenseSpecification(description: "Akşam Yemeği", note: "Cuma akşamı", amount: 9_300, category: "food", payerIndex: 2, daysAgo: 1)
                ]
            )
        ]
    }
}

private struct GroupSpecification {
    let name: String
    let currency: String
    let ghostNames: [String]
    let expenses: [ExpenseSpecification]
}

private struct ExpenseSpecification {
    let description: String
    let note: String?
    let amount: Int
    let category: String
    let payerIndex: Int
    let daysAgo: Int
}

private enum DeveloperTestDataError: LocalizedError {
    case signedOut
    case groupNotFound
    case membersNotFound
    case operationFailed(String?)

    var errorDescription: String? {
        switch self {
        case .signedOut:
            String(localized: "Test verisi için oturum açmalısın.")
        case .groupNotFound:
            String(localized: "Test grubu oluşturulamadı.")
        case .membersNotFound:
            String(localized: "Test grubu üyeleri hazırlanamadı.")
        case .operationFailed(let message):
            message ?? String(localized: "Test verileri hazırlanamadı.")
        }
    }
}
#endif
