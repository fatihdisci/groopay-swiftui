import Foundation

struct CurrencyBalance: Equatable, Sendable {
    var byCurrency: [String: Int] = [:]

    subscript(currency: String) -> Int {
        get { byCurrency[currency.uppercased(), default: 0] }
        set { byCurrency[currency.uppercased()] = newValue }
    }
}

func computeBalance(
    expenses: [Expense],
    splits: [Split],
    settlements: [Settlement],
    for memberId: UUID
) -> [String: Int] {
    var balance = CurrencyBalance()
    let expensesByID = Dictionary(
        uniqueKeysWithValues: expenses.map { ($0.id, $0) }
    )

    for expense in expenses
        where expense.deletedAt == nil && expense.paidBy == memberId {
        balance[expense.currency] += expense.amount
    }

    for split in splits where split.memberId == memberId {
        guard let expense = expensesByID[split.expenseId] else { continue }
        guard expense.deletedAt == nil else { continue }
        balance[expense.currency] -= split.shareAmount
    }

    for settlement in settlements
        where settlement.status == .confirmed {
        if settlement.fromMember == memberId {
            balance[settlement.currency] += settlement.amount
        }

        if settlement.toMember == memberId {
            balance[settlement.currency] -= settlement.amount
        }
    }

    balance.byCurrency = balance.byCurrency.filter { $0.value != 0 }
    return balance.byCurrency
}
