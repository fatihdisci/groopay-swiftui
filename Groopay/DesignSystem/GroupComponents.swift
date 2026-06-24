import SwiftUI

struct GradientAvatar: View {
    let name: String
    var emoji: String?
    var color: String?
    var size: CGFloat = 48
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)

            Text(emoji ?? initials)
                .font(
                    emoji == nil
                        ? .display(size * 0.32, weight: .bold)
                        : .system(size: size * 0.42)
                )
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var initials: String {
        let words = name.split(separator: " ")
        let letters = words.prefix(2).compactMap(\.first)
        return String(letters).uppercased(with: locale)
    }

    private var fillColor: Color {
        if let color, let parsed = Color(cssHex: color) {
            return parsed
        }
        return .brand
    }
}

struct GradientButtonLabel: View {
    let title: LocalizedStringResource
    let systemImage: String
    var disabled = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.body(15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(disabled ? Color.textTertiary : Color.brand)
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
    }
}

#Preview {
    VStack(spacing: 20) {
        GradientAvatar(
            name: "İtalya Tatili",
            emoji: "✈️",
            color: "#6366F1",
            size: 64
        )
        GradientButtonLabel(
            title: "Yeni Grup",
            systemImage: "plus"
        )
    }
    .padding()
}
