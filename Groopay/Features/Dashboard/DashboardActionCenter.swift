import Foundation

/// "Yapmam gerekenler" bölümünün saf (test edilebilir) modeli. Ücretsiz
/// kullanıcılar dahil herkese açıktır. İki tür aksiyon üretir:
/// - `debt`: kullanıcının borçlu olduğu grup/para birimi kayıtları
/// - `pendingApproval`: kullanıcının onaylaması gereken bekleyen ödemeler
///
/// Para birimleri ASLA toplanmaz; her grup/para birimi ayrı kart olur. Aynı
/// borç veya ödeme iki kez görünmez (dedupe).
enum DashboardActionItem: Identifiable, Equatable, Sendable {
    case debt(groupID: UUID, groupName: String, currency: String, amount: Int)
    case pendingApproval(
        groupID: UUID,
        groupName: String,
        settlementID: UUID,
        fromName: String,
        currency: String,
        amount: Int
    )

    var id: String {
        switch self {
        case let .debt(groupID, _, currency, _):
            return "debt-\(groupID.uuidString)-\(currency)"
        case let .pendingApproval(_, _, settlementID, _, _, _):
            return "approve-\(settlementID.uuidString)"
        }
    }

    var groupID: UUID {
        switch self {
        case let .debt(groupID, _, _, _): groupID
        case let .pendingApproval(groupID, _, _, _, _, _): groupID
        }
    }

    static func build(groups: [GroupSnapshot], userID: UUID?) -> [DashboardActionItem] {
        guard let userID else { return [] }
        var items: [DashboardActionItem] = []
        var seenDebtKeys = Set<String>()
        var seenSettlementIDs = Set<UUID>()

        for snapshot in groups {
            guard let member = snapshot.currentMember(userID: userID) else { continue }

            // Borç kayıtları — her para birimi ayrı.
            let balance = computeBalance(
                expenses: snapshot.expenses,
                splits: snapshot.splits,
                settlements: snapshot.settlements,
                for: member.id
            )
            for (currency, amount) in balance where amount < 0 {
                let key = "\(snapshot.id.uuidString)-\(currency.uppercased())"
                guard seenDebtKeys.insert(key).inserted else { continue }
                items.append(
                    .debt(
                        groupID: snapshot.id,
                        groupName: snapshot.group.name,
                        currency: currency.uppercased(),
                        amount: abs(amount)
                    )
                )
            }

            // Onay bekleyen ödemeler — kullanıcının alıcı olduğu pending'ler.
            for settlement in snapshot.pendingSettlements(forRecipient: member.id) {
                guard seenSettlementIDs.insert(settlement.id).inserted else { continue }
                let fromName = snapshot.member(id: settlement.fromMember)?.displayName ?? "?"
                items.append(
                    .pendingApproval(
                        groupID: snapshot.id,
                        groupName: snapshot.group.name,
                        settlementID: settlement.id,
                        fromName: fromName,
                        currency: settlement.currency.uppercased(),
                        amount: settlement.amount
                    )
                )
            }
        }

        return items
    }
}
