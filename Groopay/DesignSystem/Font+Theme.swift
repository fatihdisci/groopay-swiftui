import SwiftUI

// MARK: - Typography Scale (DESIGN.md §3)
//
// SF Pro (system font) — Inter ve Plus Jakarta Sans KALDIRILDI.
// Tüm font'lar Dynamic Type otomatik destekli (built-in text style).
// Para tutarları için .fontDesign(.monospaced) kullan (DESIGN.md §3.4).

extension Font {
    // MARK: - Display
    /// 34pt bold — hero tutarı, boş durum başlığı.
    static var displayLarge: Font { .system(.largeTitle, weight: .bold) }

    /// 28pt bold — sayfa başlığı, onboarding başlık.
    static var display: Font { .system(.title, weight: .bold) }

    // MARK: - Headings
    /// 22pt semibold — section başlığı.
    static var h1: Font { .system(.title2, weight: .semibold) }

    /// 17pt semibold — kart başlığı.
    static var h2: Font { .system(.headline, weight: .semibold) }

    // MARK: - Body
    /// 15pt regular — ana metin.
    static var bodyFont: Font { .system(.body, weight: .regular) }

    /// 13pt regular — ikincil bilgi.
    static var bodySmall: Font { .system(.subheadline, weight: .regular) }

    // MARK: - Captions
    /// 11pt medium — etiket, overline.
    static var captionFont: Font { .system(.caption, weight: .medium) }

    /// 10pt semibold — legal, fine print.
    static var captionSmall: Font { .system(.caption2, weight: .semibold) }
}

// MARK: - Backward-Compatible API (Adım 2 geçiş katmanı)
//
// Eski .display(_:weight:relativeTo:) ve .body(_:weight:relativeTo:) çağrıları
// derlenmeye devam eder. Size parametresi yok sayılır — Dynamic Type kendi
// ölçeklendirmesini yapar. Bu sayede mevcut view'lar kırılmaz.

extension Font {
    enum PlusJakartaSansWeight {
        case semibold
        case bold
        case extraBold

        fileprivate var swiftUIWeight: Font.Weight {
            switch self {
            case .semibold: .semibold
            case .bold: .bold
            case .extraBold: .heavy
            }
        }
    }

    enum InterWeight {
        case regular
        case medium
        case semibold

        fileprivate var swiftUIWeight: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            }
        }
    }

    /// @available(*, deprecated, message: "Use .display instead (Dynamic Type auto-sizes)")
    static func display(
        _ size: CGFloat,
        weight: PlusJakartaSansWeight = .bold,
        relativeTo textStyle: TextStyle = .title
    ) -> Font {
        .system(textStyle, weight: weight.swiftUIWeight)
    }

    /// @available(*, deprecated, message: "Use .bodyFont instead (Dynamic Type auto-sizes)")
    static func body(
        _ size: CGFloat,
        weight: InterWeight = .regular,
        relativeTo textStyle: TextStyle = .body
    ) -> Font {
        .system(textStyle, weight: weight.swiftUIWeight)
    }
}

// MARK: - Monospaced Digits (DESIGN.md §3.4)

extension View {
    /// Para tutarlarında alt alta hizalama için monospaced digit uygular.
    func monospacedAmount() -> some View {
        fontDesign(.monospaced)
    }
}
