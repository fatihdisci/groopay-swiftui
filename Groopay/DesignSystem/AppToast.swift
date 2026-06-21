import SwiftUI

struct AppToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.body(14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.textPrimary.opacity(0.9))
                        .clipShape(Capsule())
                        .purpleTintedShadow(radius: 12, y: 8)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .sensoryFeedback(.success, trigger: message != nil)
    }
}

extension View {
    func appToast(message: Binding<String?>) -> some View {
        modifier(AppToastModifier(message: message))
    }
}
