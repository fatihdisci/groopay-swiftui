import SwiftUI

/// Masraf kategorileri. `id` veritabanında `expenses.category` (String) olarak saklanır.
/// İkonlar SF Symbols, renkler kategori chip/dairesi için kullanılır.
struct ExpenseCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: LocalizedStringResource
    let icon: String
    let colorHex: String

    var color: Color {
        Color(cssHex: colorHex) ?? .primaryTheme
    }

    static func == (lhs: ExpenseCategory, rhs: ExpenseCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let all: [ExpenseCategory] = [
        ExpenseCategory(id: "food", title: "Yemek", icon: "fork.knife", colorHex: "#F59E0B"),
        ExpenseCategory(id: "transport", title: "Ulaşım", icon: "car.fill", colorHex: "#3B82F6"),
        ExpenseCategory(id: "accommodation", title: "Konaklama", icon: "bed.double.fill", colorHex: "#8B5CF6"),
        ExpenseCategory(id: "shopping", title: "Alışveriş", icon: "bag.fill", colorHex: "#EC4899"),
        ExpenseCategory(id: "entertainment", title: "Eğlence", icon: "music.note", colorHex: "#10B981"),
        ExpenseCategory(id: "groceries", title: "Market", icon: "cart.fill", colorHex: "#14B8A6"),
        ExpenseCategory(id: "bills", title: "Faturalar", icon: "doc.text.fill", colorHex: "#6366F1"),
        ExpenseCategory(id: "other", title: "Diğer", icon: "ellipsis.circle.fill", colorHex: "#6B7280")
    ]

    /// Bilinmeyen bir id için "Diğer" döner; UI hiçbir zaman boş kalmaz.
    static func find(_ id: String) -> ExpenseCategory {
        all.first { $0.id == id } ?? all[all.count - 1]
    }
}
