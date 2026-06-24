import SwiftUI

// MARK: - Radius Scale (DESIGN.md §5.1)
//
// 9 farklı değer → 4 token. Bir view ağacında en fazla 2 farklı radius token'ı kullan.

enum ThemeRadius {
    /// 4pt — TextField, picker, segmented control, toolbar.
    static let sharp: CGFloat = 4

    /// 8pt — kartlar, sheet'ler, list item.
    static let soft: CGFloat = 8

    /// 12pt — butonlar, chip'ler, FAB.
    static let rounded: CGFloat = 12

    /// Capsule — pill, avatar, progress bar.
    static var full: Capsule {
        Capsule()
    }

    // MARK: - Backward-Compatible Aliases (Adım 2 geçiş katmanı)

    /// @available(*, deprecated, message: "Use .soft (8pt) instead")
    static let card: CGFloat = 8

    /// @available(*, deprecated, message: "Use .rounded (12pt) instead")
    static let button: CGFloat = 12

    /// @available(*, deprecated, message: "Use .full instead")
    static var pill: Capsule { full }
}
