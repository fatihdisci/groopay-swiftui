import Foundation

struct Transfer: Codable, Equatable, Sendable {
    let fromMemberId: UUID
    let toMemberId: UUID
    let amount: Int
    let currency: String
}

func simplifyDebts(
    balances: [UUID: [String: Int]]
) -> [Transfer] {
    let currencies = Set(
        balances.values.flatMap { $0.keys.map { $0.uppercased() } }
    ).sorted()
    var transfers: [Transfer] = []

    for currency in currencies {
        var debtors = balances.compactMap { memberID, memberBalances in
            let amount = memberBalances[currency, default: 0]
            return amount < 0
                ? LedgerEntry(memberID: memberID, amount: magnitude(of: amount))
                : nil
        }
        .sorted { $0.memberID.uuidString < $1.memberID.uuidString }

        var creditors = balances.compactMap { memberID, memberBalances in
            let amount = memberBalances[currency, default: 0]
            return amount > 0
                ? LedgerEntry(memberID: memberID, amount: amount)
                : nil
        }
        .sorted { $0.memberID.uuidString < $1.memberID.uuidString }

        var debtorIndex = 0
        var creditorIndex = 0

        while debtorIndex < debtors.count, creditorIndex < creditors.count {
            let amount = min(
                debtors[debtorIndex].amount,
                creditors[creditorIndex].amount
            )

            guard amount > 0 else { break }

            transfers.append(
                Transfer(
                    fromMemberId: debtors[debtorIndex].memberID,
                    toMemberId: creditors[creditorIndex].memberID,
                    amount: amount,
                    currency: currency
                )
            )

            debtors[debtorIndex].amount -= amount
            creditors[creditorIndex].amount -= amount

            if debtors[debtorIndex].amount == 0 {
                debtorIndex += 1
            }

            if creditors[creditorIndex].amount == 0 {
                creditorIndex += 1
            }
        }
    }

    return transfers
}

private struct LedgerEntry {
    let memberID: UUID
    var amount: Int
}

private func magnitude(of value: Int) -> Int {
    value == Int.min ? Int.max : -value
}
