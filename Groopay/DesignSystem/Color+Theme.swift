import SwiftUI

extension Color {
    static let background = Color(hex: 0xF7F6FF)
    static let surface = Color(hex: 0xFFFFFF)
    static let surfaceTinted = Color(hex: 0xEFEEFC)
    static let primaryTheme = Color(hex: 0x4F46E5)
    static let gradientStart = Color(hex: 0x4F46E5)
    static let gradientEnd = Color(hex: 0x7C3AED)
    static let debt = Color(hex: 0xF43F5E)
    static let credit = Color(hex: 0x10B981)
    static let warning = Color(hex: 0xF59E0B)
    static let textPrimary = Color(hex: 0x0D0D14)
    static let textSecondary = Color(hex: 0x6B7280)
    static let textTertiary = Color(hex: 0x9CA3AF)

    private init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
