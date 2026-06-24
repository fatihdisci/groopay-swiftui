import Foundation

// MARK: - Spacing Scale (DESIGN.md §4)
//
// 8pt grid. Mevcut magic number'lar (6, 10, 14, 18, 22…) bu token'lara normalize edilir.
// Kural: bileşen içi sm, ilişkili bileşenler md, section'lar arası xl.

enum ThemeSpacing {
    /// 4pt — ikon-metin arası, tight chip iç padding.
    static let xs: CGFloat = 4

    /// 8pt — aynı bileşen içi dikey boşluk, card iç padding.
    static let sm: CGFloat = 8

    /// 12pt — ilişkili bileşenler arası (label-input).
    static let md: CGFloat = 12

    /// 16pt — kart iç padding, list row arası.
    static let lg: CGFloat = 16

    /// 20pt — section'lar arası, sayfa yatay padding.
    static let xl: CGFloat = 20

    /// 24pt — büyük section arası, card'lar arası.
    static let xxl: CGFloat = 24

    /// 32pt — ekran üst/alt boşluğu, hero altı.
    static let xxxl: CGFloat = 32

    /// 40pt — sayfa başlangıcı.
    static let huge: CGFloat = 40

    /// 48pt — boş durum (empty state) dikey.
    static let huge2: CGFloat = 48

    /// 56pt.
    static let huge3: CGFloat = 56

    /// 64pt.
    static let huge4: CGFloat = 64
}
