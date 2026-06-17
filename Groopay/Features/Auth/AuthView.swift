import SwiftUI

struct AuthView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 28)

                    VStack(spacing: 18) {
                        AppIconBadge()

                        VStack(spacing: 10) {
                            Text("auth.title")
                                .font(.display(30, weight: .extraBold))
                                .foregroundStyle(Color.textPrimary)
                                .multilineTextAlignment(.center)

                            Text("Harcamaları bölüş, kimin ne ödeyeceğini gör, gruplarını tek yerde takip et.")
                                .font(.body(15))
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                    }

                    VStack(spacing: 10) {
                        FeatureCard(
                            icon: "person.2.fill",
                            title: "Grupları yönet",
                            subtitle: "Ev, tatil ve arkadaş hesaplarını ayrı ayrı takip et.",
                            color: Color.primaryTheme
                        )
                        FeatureCard(
                            icon: "chart.pie.fill",
                            title: "Adil paylaşım",
                            subtitle: "Masrafları eşit, oranlı veya kişiye göre böl.",
                            color: Color.credit
                        )
                        FeatureCard(
                            icon: "checkmark.seal.fill",
                            title: "Misafir başla",
                            subtitle: "Hemen dene; Pro satın alırken Apple ile giriş yap.",
                            color: Color.warning
                        )
                    }

                    VStack(spacing: 12) {
                        AppleSignInButton()

                        Button {
                            Task {
                                await authStore.signInAnonymously()
                            }
                        } label: {
                            Text("auth.guest")
                                .font(.body(15, weight: .semibold))
                                .foregroundStyle(Color.primaryTheme)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.surface)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: ThemeRadius.button)
                                )
                        }
                        .purpleTintedShadow(radius: 10, y: 5)
                        .disabled(authStore.isLoading)
                    }

                    Text("auth.purchaseRequiresApple")
                        .font(.body(12))
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
            }

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

private struct AppIconBadge: View {
    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFill()
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
        .purpleTintedShadow(radius: 18, y: 10)
    }
}

private struct FeatureCard: View {
    let icon: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.body(12))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow(radius: 10, y: 5)
    }
}

#Preview("Signed Out") {
    AuthView()
        .environment(PreviewSupport.signedOutAuthStore)
}
