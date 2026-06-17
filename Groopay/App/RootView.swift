import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var authStore
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    var body: some View {
        SwiftUI.Group {
            if authStore.isRestoringSession {
                ZStack {
                    Color.background
                        .ignoresSafeArea()

                    ProgressView()
                        .tint(.primaryTheme)
                }
            } else {
                switch authStore.sessionState {
                case .signedOut:
                    if hasCompletedOnboarding {
                        AuthView()
                    } else {
                        OnboardingFlow()
                    }
                case .anonymous, .identified:
                    MainTabView()
                }
            }
        }
        .alert(
            "auth.error.title",
            isPresented: Binding(
                get: { authStore.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        authStore.clearError()
                    }
                }
            )
        ) {
            Button("common.ok", role: .cancel) {
                authStore.clearError()
            }
        } message: {
            Text(authStore.errorMessage ?? "")
        }
    }
}

#Preview("Signed Out Root") {
    RootView()
        .environment(PreviewSupport.signedOutAuthStore)
        .environment(LocalizationStore())
}

#Preview("Signed In Root") {
    RootView()
        .environment(PreviewSupport.authStore)
        .environment(LocalizationStore())
}
