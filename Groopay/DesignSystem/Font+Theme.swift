import SwiftUI

extension Font {
    enum PlusJakartaSansWeight {
        case semibold
        case bold
        case extraBold

        fileprivate var swiftUIWeight: Font.Weight {
            switch self {
            case .semibold: .semibold   // wght ~600
            case .bold: .bold           // wght ~700
            case .extraBold: .heavy     // wght ~800
            }
        }
    }

    enum InterWeight {
        case regular
        case medium
        case semibold

        fileprivate var swiftUIWeight: Font.Weight {
            switch self {
            case .regular: .regular     // wght 400
            case .medium: .medium       // wght ~500
            case .semibold: .semibold   // wght ~600
            }
        }
    }

    // Variable font'lar tek bir PostScript adıyla yüklenir
    // (PlusJakartaSans-Regular / Inter-Regular); ağırlık `wght` ekseni
    // üzerinden `.weight()` ile sürülür. iOS 17+ bunu native destekler.
    private static let displayFontName = "PlusJakartaSans-Regular"
    private static let bodyFontName = "Inter-Regular"

    static func display(
        _ size: CGFloat,
        weight: PlusJakartaSansWeight = .bold,
        relativeTo textStyle: TextStyle = .title
    ) -> Font {
        .custom(displayFontName, size: size, relativeTo: textStyle)
            .weight(weight.swiftUIWeight)
    }

    static func body(
        _ size: CGFloat,
        weight: InterWeight = .regular,
        relativeTo textStyle: TextStyle = .body
    ) -> Font {
        .custom(bodyFontName, size: size, relativeTo: textStyle)
            .weight(weight.swiftUIWeight)
    }
}
