import SwiftUI

// MARK: - Shadow Scale (DESIGN.md §5.2)
//
// Nötr siyah gölge kademesi. Mor-tintli gölge TAMAMEN kaldırıldı.
// Gölge RENGİ her zaman Color.black. Gölge yalnızca derinlik hiyerarşisi taşır.

// MARK: - New Neutral Shadow Modifiers

private struct NeutralShadow: ViewModifier {
    let opacity: Double
    let radius: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(
            color: .black.opacity(opacity),
            radius: radius,
            x: 0,
            y: y
        )
    }
}

extension View {
    /// Kartlar arka plan üzerinde — black 3%, radius 4, y 2.
    func shadowSubtle() -> some View {
        modifier(NeutralShadow(opacity: 0.03, radius: 4, y: 2))
    }

    /// Yükseltilmiş kart, hover/selected — black 6%, radius 8, y 4.
    func shadowMedium() -> some View {
        modifier(NeutralShadow(opacity: 0.06, radius: 8, y: 4))
    }

    /// Modal, bottom sheet, popover — black 10%, radius 16, y 8.
    func shadowStrong() -> some View {
        modifier(NeutralShadow(opacity: 0.10, radius: 16, y: 8))
    }
}

// MARK: - Backward-Compatible Alias (Adım 2 geçiş katmanı)
//
// Mevcut .purpleTintedShadow() çağrıları artık nötr gölge üretir.
// Radius/y parametreleri hâlâ çalışır ama mor renk yerine siyah kullanılır.

extension View {
    /// @available(*, deprecated, message: "Use .shadowSubtle() / .shadowMedium() instead")
    func purpleTintedShadow(radius: CGFloat = 12, y: CGFloat = 6) -> some View {
        modifier(NeutralShadow(opacity: 0.03, radius: radius, y: y))
    }
}
