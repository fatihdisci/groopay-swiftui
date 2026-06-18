import Foundation

struct BalanceSummary: Codable, Equatable, Sendable {
    struct Amounts: Codable, Equatable, Sendable {
        var receivable: Int = 0
        var debt: Int = 0
    }

    var byCurrency: [String: Amounts]
    var updatedAt: Date

    struct Row: Identifiable, Equatable, Sendable {
        var id: String { currency }
        let currency: String
        let amounts: Amounts
    }

    var rows: [Row] {
        byCurrency.map { Row(currency: $0.key, amounts: $0.value) }
            .sorted { $0.currency < $1.currency }
    }

    static let empty = BalanceSummary(byCurrency: [:], updatedAt: .distantPast)

    static func calculate(groups: [GroupSnapshot], userID: UUID?) -> BalanceSummary {
        guard let userID else { return .empty }
        var totals: [String: Amounts] = [:]

        for snapshot in groups {
            guard let member = snapshot.currentMember(userID: userID) else { continue }
            let balance = computeBalance(
                expenses: snapshot.expenses,
                splits: snapshot.splits,
                settlements: snapshot.settlements,
                for: member.id
            )

            for (currency, amount) in balance where amount != 0 {
                let key = currency.uppercased()
                var entry = totals[key, default: Amounts()]
                if amount > 0 {
                    entry.receivable += amount
                } else {
                    entry.debt += abs(amount)
                }
                totals[key] = entry
            }
        }

        return BalanceSummary(byCurrency: totals, updatedAt: Date())
    }
}
