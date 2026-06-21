import Foundation

/// Yeni masraf ekranındaki "Son kullandıkların" önerisi. Saf, test edilebilir.
struct ExpenseSuggestion: Equatable, Identifiable {
    let description: String
    let category: String
    let currency: String

    var id: String { description.lowercased() }
}

enum RecentExpenseSuggestions {
    /// İlgili grubun son masraflarından en fazla `limit` benzersiz açıklama.
    /// En yeni kayıt önceliklidir; case-insensitive tekrarlar elenir; silinmiş
    /// ve boş açıklamalı masraflar atlanır.
    static func suggestions(
        from expenses: [Expense],
        limit: Int = 3
    ) -> [ExpenseSuggestion] {
        let sorted = expenses
            .filter { $0.deletedAt == nil }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }

        var seen = Set<String>()
        var result: [ExpenseSuggestion] = []
        for expense in sorted {
            let description = expense.description
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { continue }
            let key = description.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(
                ExpenseSuggestion(
                    description: description,
                    category: expense.category,
                    currency: expense.currency.uppercased()
                )
            )
            if result.count >= limit { break }
        }
        return result
    }
}
