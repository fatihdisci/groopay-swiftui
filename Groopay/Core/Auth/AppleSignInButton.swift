import AuthenticationServices
import SwiftUI

struct AppleSignInButton: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        SignInWithAppleButton(
            .continue,
            onRequest: authStore.prepareAppleRequest,
            onCompletion: { result in
                Task {
                    await authStore.signInWithApple(result: result)
                }
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
        .disabled(authStore.isLoading)
        .accessibilityLabel(Text("auth.apple"))
    }
}

#Preview {
    AppleSignInButton()
        .padding()
        .environment(PreviewSupport.authStore)
}
