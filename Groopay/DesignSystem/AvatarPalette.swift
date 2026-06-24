import Foundation

// MARK: - Solid Avatar Color Palette (DESIGN.md §1 avatar notu)
//
// Yön B — Sıcak Nötr + Ada Çamı. En az 8 solid ton, kullanıcı/grup ayırt edilebilirliği için.
// Gradient avatar TAMAMEN kaldırıldı. Renkler brand/accent/nötr sıcak tonlardan türetildi.
// Mor, parlak pembe, neon tonları YOK (AI tell'lerden arındırıldı).

enum AvatarPalette {
    /// 8 solid renk — Yön B paletinden türetilmiş, birbirinden ayırt edilebilir tonlar.
    static let colors = [
        "#2D3436",  // warm charcoal (brand)
        "#0D7B63",  // deep teal-green (accent)
        "#636E72",  // muted slate blue
        "#B76E4A",  // warm terracotta (complementary)
        "#5B8C5A",  // muted sage green
        "#8E7D5E",  // warm taupe
        "#4A7C96",  // dusty blue
        "#A3806B",  // warm brown
    ]

    static let fallback = colors[0]
}
