import Foundation

/// Aktivite araması için saf, test edilebilir yardımcı. Tüm kullanıcılarda
/// (ücretsiz dahil) çalışır. Karşılaştırma locale-aware lowercase iledir; boş
/// query gereksiz filtreleme yapmaz (no-op).
enum ActivitySearch {
    static func filter<T>(
        _ items: [T],
        query: String,
        locale: Locale = LocalizationStore.currentLocale(),
        haystack: (T) -> String
    ) -> [T] {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: locale)
        guard !normalized.isEmpty else { return items }
        return items.filter { item in
            haystack(item).lowercased(with: locale).contains(normalized)
        }
    }
}
