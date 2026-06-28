import Foundation

struct ReceiptLineItem: Equatable, Sendable {
    var name: String
    var amountMinor: Int
}

struct ReceiptParser {
    static let filterKeywords: [String] = [
        "toplam", "genel toplam", "ara toplam", "subtotal", "total", "grand total",
        "kdv", "vergi", "tax", "vat",
        "nakit", "kredi kartı", "banka kartı", "cash", "credit card",
        "matrah", "iade", "para üstü", "change", "discount", "indirim",
        "fiş no", "tarih", "date", "saat", "time", "kasör", "kasiyer"
    ]

    static func parseReceiptText(_ text: String, currency: String) -> [ReceiptLineItem] {
        var items: [ReceiptLineItem] = []
        let lines = text.components(separatedBy: .newlines)
        let locale = Locale(identifier: "tr_TR")

        // Regular expression to match amounts at the end of the line:
        // 1. Thousand separators with decimals: 1.250,50 / 1,250.50
        // 2. Simple decimals: 150,50 / 150.50
        // 3. Whole numbers: 150
        let pattern = #"(\d{1,3}(?:[.,\s]\d{3})*[.,]\d{2}|\d+[.,]\d{2}|\d+)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        var itemIndex = 1
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            // Filter out metadata/total lines (case insensitive, Turkish locale)
            let lowercasedLine = trimmedLine.lowercased(with: locale)
            let shouldFilter = filterKeywords.contains { keyword in
                lowercasedLine.contains(keyword)
            }
            if shouldFilter { continue }

            let range = NSRange(trimmedLine.startIndex..<trimmedLine.endIndex, in: trimmedLine)
            guard let match = regex.firstMatch(in: trimmedLine, options: [], range: range) else {
                continue
            }

            guard let amountRange = Range(match.range(at: 1), in: trimmedLine) else {
                continue
            }

            let amountString = String(trimmedLine[amountRange])
            let amountMinor = parseMoneyInputToMinor(amountString, currency: currency)

            // Skip zero or negative parsed amounts
            guard amountMinor > 0 else { continue }

            // The rest of the line is the item name
            let nameSubstring = trimmedLine[..<amountRange.lowerBound]
            var name = nameSubstring.trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove trailing symbols like dot, dash, colon, star, or currency symbols
            while !name.isEmpty && (name.last == "." || name.last == "-" || name.last == ":" || name.last == "*" || name.last == "," || name.last == "₺" || name.last == "$" || name.last == "€") {
                name.removeLast()
            }
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)

            if name.isEmpty {
                name = String(localized: "Kalem \(itemIndex)", comment: "Default item name when parser cannot extract it")
            }

            items.append(ReceiptLineItem(name: name, amountMinor: amountMinor))
            itemIndex += 1
        }

        return items
    }
}
