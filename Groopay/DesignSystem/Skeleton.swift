import SwiftUI

/// Shimmer animasyonu. Reduce Motion açıkken animasyon çalışmaz; statik bir
/// placeholder gösterilir. Skeleton'lar VoiceOver ağacından gizlenir.
/// Dark mode uyumlu — shimmer rengi colorScheme'e göre white/black arasında geçiş yapar.
struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = -0.7

    private var shimmerColor: Color {
        colorScheme == .dark ? .white : .white
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                shimmerColor.opacity(0),
                                shimmerColor.opacity(colorScheme == .dark ? 0.10 : 0.55),
                                shimmerColor.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 1.4)
                        .offset(x: phase * geo.size.width * 1.6)
                    }
                )
                .mask(Rectangle())
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.2).repeatForever(autoreverses: false)
                    ) {
                        phase = 1.2
                    }
                }
        }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// Tek bir gri blok (satır, başlık, pill yer tutucusu).
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat = 8

    init(width: CGFloat? = nil, height: CGFloat = 14, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.surfaceTinted)
            .frame(width: width, height: height)
            .shimmer()
            .accessibilityHidden(true)
    }
}

/// Gerçek liste kartı geometrisine yakın bir skeleton (avatar + iki satır + pill).
struct SkeletonCard: View {
    var showsTrailingAmount: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.surfaceTinted)
                .frame(width: 48, height: 48)
                .shimmer()

            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 140, height: 15)
                SkeletonBlock(width: 90, height: 12)
                SkeletonBlock(width: 70, height: 18, cornerRadius: 9)
            }

            Spacer()

            if showsTrailingAmount {
                SkeletonBlock(width: 56, height: 16)
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow()
        .accessibilityHidden(true)
    }
}

/// Liste ekranları için tekrar eden skeleton kart yığını.
struct SkeletonList: View {
    var count: Int = 5
    var showsTrailingAmount: Bool = true

    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonCard(showsTrailingAmount: showsTrailingAmount)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .accessibilityHidden(true)
    }
}

#Preview {
    ScrollView {
        SkeletonList()
    }
    .background(Color.background)
}
