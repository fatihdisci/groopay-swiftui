import SwiftUI

struct AppToastModifier: ViewModifier {
    @Binding var message: String?
    let actionTitle: String?
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    HStack(spacing: 14) {
                        Text(message)
                            .font(.body(14, weight: .medium))
                            .foregroundStyle(.white)

                        if let actionTitle, let action {
                            Button(action: action) {
                                Text(actionTitle)
                                    .font(Font.body(14, weight: .semibold))
                                    .foregroundStyle(Color.warning)
                            }
                        }
                    }
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
    func appToast(
        message: Binding<String?>,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        modifier(
            AppToastModifier(
                message: message,
                actionTitle: actionTitle,
                action: action
            )
        )
    }
}
