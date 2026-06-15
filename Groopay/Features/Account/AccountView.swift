import SwiftUI
import Supabase

struct AccountView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var purchasesManager = PurchasesManager.shared
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Profil
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

                    // Pro durumu
                    if authStore.currentProfile?.userPro == true {
                        Label("Pro Aktif", systemImage: "checkmark.seal.fill")
                            .font(.body(15, weight: .medium))
                            .foregroundStyle(Color.credit)
                    } else {
                        Label("Ücretsiz Plan", systemImage: "diamond")
                            .font(.body(15, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        Button {
                            showPaywall = true
                        } label: {
                            Text("Pro'ya Geç")
                                .font(.body(15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: 220, minHeight: 44)
                                .background(
                                    LinearGradient(
                                        colors: [.gradientStart, .gradientEnd],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                Spacer()

                // DEV Toggle
                #if DEBUG
                Divider()
                    .padding(.horizontal, 24)

                Button {
                    Task {
                        await togglePro()
                    }
                } label: {
                    HStack {
                        Image(systemName: "wrench.fill")
                            .font(.system(size: 14))
                        Text("Pro Aç/Kapat (Geliştirici)")
                            .font(.body(14, weight: .medium))
                    }
                    .foregroundStyle(Color.warning)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color.warning.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                #endif
            }
            .padding(24)
        }
        .navigationTitle("tab.account")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    #if DEBUG
    private func togglePro() async {
        let supabase = SupabaseService.shared
        guard let userID = supabase.auth.currentUser?.id else { return }

        let currentValue = authStore.currentProfile?.userPro ?? false

        do {
            try await supabase
                .from("profiles")
                .update(["user_pro": !currentValue])
                .eq("id", value: userID)
                .execute()

            await authStore.loadProfile()
        } catch {
            print("DEV toggle error: \(error.localizedDescription)")
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        AccountView()
    }
    .environment(PreviewSupport.authStore)
}
