import SwiftUI

struct GradientAvatar: View {
    let name: String
    var emoji: String?
    var color: String?
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

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
        return String(letters).uppercased(
            with: Locale(identifier: "tr_TR")
        )
    }

    private var gradientColors: [Color] {
        guard let color, let parsed = Color(cssHex: color) else {
            return [.gradientStart, .gradientEnd]
        }
        return [parsed, parsed.opacity(0.7)]
    }
}

struct GradientButtonLabel: View {
    let title: String
    let systemImage: String
    var disabled = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.body(15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                LinearGradient(
                    colors: disabled
                        ? [.textTertiary, .textTertiary]
                        : [.gradientStart, .gradientEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
    }
}

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
