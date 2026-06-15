import SwiftUI

struct AccountView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.primaryTheme)

                if authStore.sessionState == .anonymous {
                    Text("account.guest")
                        .font(.display(24))
                        .foregroundStyle(Color.textPrimary)

                    Text("account.appleRequired")
                        .font(.body(15))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)

                    AppleSignInButton()
                } else {
                    Text(
                        authStore.currentProfile?.displayName
                            ?? String(localized: "account.appleUser")
                    )
                    .font(.display(24))
                    .foregroundStyle(Color.textPrimary)

                    Label(
                        "account.purchaseReady",
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(.body(15, weight: .medium))
                    .foregroundStyle(Color.credit)
                }
            }
            .padding(24)
        }
        .navigationTitle("tab.account")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
    .environment(PreviewSupport.authStore)
}
