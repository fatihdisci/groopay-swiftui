import SwiftUI

struct AuthView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.primaryTheme)

                VStack(spacing: 8) {
                    Text("auth.title")
                        .font(.display(30, weight: .extraBold))
                        .foregroundStyle(Color.textPrimary)

                    Text("auth.subtitle")
                        .font(.body(16))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    AppleSignInButton()

                    Button("auth.guest") {
                        Task {
                            await authStore.signInAnonymously()
                        }
                    }
                    .font(.body(16, weight: .semibold))
                    .foregroundStyle(Color.primaryTheme)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.surface)
                    .clipShape(
                        RoundedRectangle(cornerRadius: ThemeRadius.button)
                    )
                    .purpleTintedShadow()
                    .disabled(authStore.isLoading)
                }

                Text("auth.purchaseRequiresApple")
                    .font(.body(13))
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(24)

            if authStore.isLoading {
                ProgressView()
                    .tint(.primaryTheme)
                    .padding(20)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthStore())
}
