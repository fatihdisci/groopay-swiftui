import Foundation

struct GroupSnapshot: Identifiable, Equatable, Sendable {
    var group: Group
    var members: [Member]
    var expenses: [Expense]
    var splits: [Split]
    var settlements: [Settlement]

    var id: UUID {
        group.id
    }

    var activeMembers: [Member] {
        members.filter(\.isActive)
    }

    func currentMember(userID: UUID?) -> Member? {
        guard let userID else { return nil }
        return members.first { $0.userId == userID && $0.isActive }
    }

    func member(id: UUID) -> Member? {
        members.first { $0.id == id }
    }

    /// Onay bekleyen ödemeler (bu üyenin onaylaması gerekenler dahil filtrelenir).
    func pendingSettlements(forRecipient memberID: UUID) -> [Settlement] {
        settlements.filter {
            $0.status == .pending && $0.toMember == memberID
        }
    }

    /// Bir transfer için zaten oluşturulmuş bekleyen ödeme var mı? (borçluya
    /// "Onay Bekleniyor" göstermek için.)
    func pendingSettlement(
        from: UUID,
        to: UUID,
        currency: String
    ) -> Settlement? {
        settlements.first {
            $0.status == .pending
                && $0.fromMember == from
                && $0.toMember == to
                && $0.currency.uppercased() == currency.uppercased()
        }
    }

    /// Aktif üye başına para birimi bazında bakiye. Para birimleri asla toplanmaz.
    func memberBalances() -> [UUID: [String: Int]] {
        Dictionary(
            uniqueKeysWithValues: activeMembers.map { member in
                (
                    member.id,
                    computeBalance(
                        expenses: expenses,
                        splits: splits,
                        confirmedSettlements: settlements,
                        for: member.id
                    )
                )
            }
        )
    }
}
