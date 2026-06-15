import Foundation

/// UI'da seçilebilen para birimleri. `numeric(14,2)` kısıtı gereği yalnızca
/// 2-ondalıklı para birimleri (18 adet). JPY/KWD gibi 0/3-ondalıklılar
/// integer-minor migration'a (Faz 9) kadar gizli; `getDecimals` yine de doğru çalışır.
enum Currency {
    static let supported: [String] = [
        "TRY", "USD", "EUR", "GBP", "CHF", "CAD",
        "AUD", "AED", "SAR", "SEK", "NOK", "DKK",
        "PLN", "CZK", "HUF", "RON", "BRL", "ZAR"
    ]

    /// Verilen para birimi destekleniyorsa onu, değilse TRY döner.
    static func normalized(_ currency: String) -> String {
        let upper = currency.uppercased()
        return supported.contains(upper) ? upper : "TRY"
    }
}
