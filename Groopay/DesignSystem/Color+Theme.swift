import SwiftUI
import UIKit

// MARK: - Color Token Catalog (DESIGN.md §2)
//
// Yön B — Sıcak Nötr + Ada Çamı (FİNAL, 24 Haziran 2026)
// Her token light + dark varyantlıdır.
// credit/debt/warning semantik renkleri yalnızca bakiye/borç/onay bağlamında.

extension Color {
    // MARK: - Brand
    /// Ana marka rengi. Buton, link, seçili durum. Light: warm charcoal, Dark: soft gray.
    static let brand = Color(light: 0x2D3436, dark: 0xB2BEC3)

    /// brand'in %6-8 opaque hali. Chip arka planı, seçili satır.
    static let brandMuted = Color(light: 0xEEF0F0, dark: 0x25282A)

    // MARK: - Accent
    /// Vurgu rengi. Öne çıkan CTA, bildirim dot'u, fiyat vurgusu. Light: deep teal-green, Dark: bright teal.
    static let themeAccent = Color(light: 0x0D7B63, dark: 0x2DD4A8)

    /// accent'in %6-8 opaque hali.
    static let themeAccentMuted = Color(light: 0xEDF7F4, dark: 0x1A2824)

    // MARK: - Surface
    /// Ana ekran arka planı. Light: neutral white, Dark: true black.
    static let themeBackground = Color(light: 0xFAFAFA, dark: 0x0D0D0D)

    /// Kartlar, sheet'ler, list row'ları. Light: pure white, Dark: system gray.
    static let themeSurface = Color(light: 0xFFFFFF, dark: 0x1C1C1E)

    /// İkincil yüzey: iç içe kart, alternatif satır, disabled. Light: neutral gray 100, Dark: elevated gray.
    static let themeSurfaceMuted = Color(light: 0xF5F5F5, dark: 0x262628)

    // MARK: - Text
    /// Başlık, body, önemli rakamlar.
    static let themeTextPrimary = Color(light: 0x171717, dark: 0xFAFAFA)

    /// Açıklama, meta bilgi.
    static let themeTextSecondary = Color(light: 0x737373, dark: 0xA3A3A3)

    /// Placeholder, disabled, legal fine print.
    static let themeTextTertiary = Color(light: 0xA3A3A3, dark: 0x666666)

    // MARK: - Semantic (FİNANSAL KONVANSİYON — DEĞİŞMEZ)
    /// Alacak, pozitif bakiye, ödeştin, onay — HER ZAMAN YEŞİL.
    static let credit = Color(light: 0x10B981, dark: 0x34D399)

    /// Borç, negatif bakiye, reddet, sil — HER ZAMAN KIRMIZI.
    static let debt = Color(light: 0xEF4444, dark: 0xF87171)

    /// Bekleyen onay, süre dolacak, limit — HER ZAMAN AMBER/SARI.
    static let warning = Color(light: 0xF59E0B, dark: 0xFBBF24)
}

// MARK: - Backward-Compatible Aliases (Adım 2 geçiş katmanı)
//
// Eski token isimleri çalışmaya devam eder ama altta Yön B renklerine bağlıdır.
// Bu alias'lar Adım 11'de (eski dosyaları kaldır) tüm referanslar temizlendikten
// sonra silinebilir.

extension Color {
    /// @available(*, deprecated, message: "Use .brand instead")
    static var primaryTheme: Color { .brand }

    /// @available(*, deprecated, message: "Gradient kaldırıldı — use .brand instead")
    static var gradientStart: Color { .brand }

    /// @available(*, deprecated, message: "Gradient kaldırıldı — use .brand instead")
    static var gradientEnd: Color { .brand }

    /// @available(*, deprecated, message: "Use .themeBackground instead")
    static var background: Color { .themeBackground }

    /// @available(*, deprecated, message: "Use .themeSurface instead")
    static var surface: Color { .themeSurface }

    /// @available(*, deprecated, message: "Use .themeSurfaceMuted instead")
    static var surfaceTinted: Color { .themeSurfaceMuted }

    /// @available(*, deprecated, message: "Use .themeTextPrimary instead")
    static var textPrimary: Color { .themeTextPrimary }

    /// @available(*, deprecated, message: "Use .themeTextSecondary instead")
    static var textSecondary: Color { .themeTextSecondary }

    /// @available(*, deprecated, message: "Use .themeTextTertiary instead")
    static var textTertiary: Color { .themeTextTertiary }
}

// MARK: - Hex Parsing (GroupComponents, Avatar tarafından kullanılır)

extension Color {
    init?(cssHex: String) {
        let cleaned = cssHex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        guard cleaned.count == 6, let value = UInt(cleaned, radix: 16) else {
            return nil
        }

        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Light/Dark Adaptive Init

private extension Color {
    /// Light ve dark mode için hex değerleriyle adaptive Color.
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(hex: dark)
            default:
                return UIColor(hex: light)
            }
        })
    }
}

private extension UIColor {
    /// Hex unsigned integer'dan UIColor oluşturur.
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
