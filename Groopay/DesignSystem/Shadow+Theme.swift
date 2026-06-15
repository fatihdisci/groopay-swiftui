import SwiftUI

private struct PurpleTintedShadow: ViewModifier {
    let radius: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(
            color: Color.primaryTheme.opacity(0.06),
            radius: radius,
            x: 0,
            y: y
        )
    }
}

extension View {
    func purpleTintedShadow(radius: CGFloat = 12, y: CGFloat = 6) -> some View {
        modifier(PurpleTintedShadow(radius: radius, y: y))
    }
}
