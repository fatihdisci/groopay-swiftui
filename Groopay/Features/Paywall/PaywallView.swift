import SwiftUI
import RevenueCat

// MARK: - Pro Feature Model

struct ProFeature: Identifiable {
    let id: String
    let icon: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
}

private let proFeatures: [ProFeature] = [
    ProFeature(
        id: "dashboard",
        icon: "chart.bar.fill",
        title: "Gelişmiş Panel",
        subtitle: "Tüm gruplarının para birimi bazında özetini, harcama trendlerini ve kategorilerini tek ekranda gör."
    ),
    ProFeature(
        id: "groups",
        icon: "person.2.fill",
        title: "Sınırsız Grup",
        subtitle: "Ücretsizde 5 grup sınırı var. Pro ile istediğin kadar grup oluştur, hiçbir arkadaşını dışarıda bırakma."
    ),
    ProFeature(
        id: "analytics",
        icon: "chart.pie.fill",
        title: "Kategori Analizi",
        subtitle: "Harcamalarını kategorilere göre analiz et, nereye ne kadar gittiğini görselleştir."
    ),
    ProFeature(
        id: "activity",
        icon: "clock.fill",
        title: "Aktivite Arama",
        subtitle: "Tüm gruplarındaki aktivitelerde arama yap, geçmiş masrafları kolayca bul."
    ),
]

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AuthStore.self) private var authStore
    @State private var purchases = PurchasesManager.shared
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseSuccess = false
    @State private var successMessage: String?
    @State private var animateHero = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            paywallBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroSection
                    pricingCard
                    featureGrid
                }
                .padding(.horizontal, 22)
                .padding(.top, 44)
                .padding(.bottom, 172)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomPurchaseBar
            }

            closeButton

            if let successMessage {
                toast(successMessage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            await purchases.loadOfferings()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                animateHero = true
            }
        }
        .onChange(of: purchaseSuccess) { _, success in
            if success {
                dismiss()
            }
        }
        .alert(
            "Bir hata oluştu",
            isPresented: Binding(
                get: { purchases.errorMessage != nil },
                set: { if !$0 { purchases.clearError() } }
            )
        ) {
            Button("Tamam", role: .cancel) { purchases.clearError() }
        } message: {
            Text(purchases.errorMessage ?? "")
        }
    }

    private var paywallBackground: some View {
        ZStack(alignment: .top) {
            Color.background
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(cssHex: "#312E81") ?? .gradientStart,
                    Color(cssHex: "#6D28D9") ?? .gradientEnd,
                    Color(cssHex: "#A855F7") ?? .gradientEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 330)
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.34), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 10)
                .scaleEffect(animateHero ? 1.04 : 1)

            VStack(spacing: 6) {
                Text("Groopay Pro")
                    .font(.display(28, weight: .extraBold))
                    .foregroundStyle(.white)

                Text("Gruplarını sınırsız yönet, harcamaları daha hızlı analiz et.")
                    .font(.body(14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            HStack(spacing: 10) {
                heroPill("Sınırsız grup")
                heroPill("Gelişmiş analiz")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 0)
        .padding(.bottom, 6)
    }

    private func heroPill(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.body(12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.14))
            .clipShape(Capsule())
    }

    // MARK: - Features

    private var featureGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 8
        ) {
            ForEach(proFeatures) { feature in
                featureCard(feature)
            }
        }
    }

    private func featureCard(_ feature: ProFeature) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: feature.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primaryTheme)
                .frame(width: 32, height: 32)
                .background(Color.primaryTheme.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(feature.title)
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            Text(feature.subtitle)
                .font(.body(11))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(12)
        .background(.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow(radius: 12, y: 6)
    }

    // MARK: - Pricing Card

    private var pricingCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aylık Pro")
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    if let product = purchases.monthlyProduct {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(product.localizedPriceString)
                                .font(.display(34, weight: .extraBold))
                                .foregroundStyle(Color.textPrimary)
                            Text("/ay")
                                .font(.body(14, weight: .semibold))
                                .foregroundStyle(Color.textSecondary)
                        }
                    } else if purchases.isLoading {
                        ProgressView()
                            .tint(.primaryTheme)
                    } else {
                        Text("Fiyat bilgisi yükleniyor…")
                            .font(.body(14))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.warning)
                    .frame(width: 42, height: 42)
                    .background(Color.warning.opacity(0.12))
                    .clipShape(Circle())
            }

            Text("Abonelik dönem sonunda otomatik yenilenir. İptal edilmezse ücret tahsil edilir. Hesap ayarlarından yönetebilirsiniz.")
                .font(.body(11))
                .foregroundStyle(Color.textTertiary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.primaryTheme.opacity(0.12), lineWidth: 1)
        )
        .purpleTintedShadow(radius: 18, y: 8)
    }

    // MARK: - Continue Button

    private var bottomPurchaseBar: some View {
        VStack(spacing: 10) {
            if authStore.canPurchase {
                continueButton
            } else {
                guestPurchaseGate
            }
            footerLinks
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.textTertiary.opacity(0.14))
                .frame(height: 1)
        }
    }

    private var guestPurchaseGate: some View {
        VStack(spacing: 8) {
            AppleSignInButton()
                .frame(maxWidth: .infinity, minHeight: 52)

            Text("account.appleRequired")
                .font(.body(11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var continueButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            SwiftUI.Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Pro’ya Geç", systemImage: "arrow.right.circle.fill")
                        .font(.body(17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [.gradientStart, .gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
        }
        .disabled(isPurchasing || isRestoring || purchases.monthlyProduct == nil)
        .opacity(purchases.monthlyProduct == nil ? 0.5 : 1)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        let pathPrefix = locale.language.languageCode?.identifier == "en"
            ? "/en"
            : ""

        return HStack(spacing: 12) {
            Button {
                Task { await restorePurchases() }
            } label: {
                HStack(spacing: 6) {
                    if isRestoring {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(Color.primaryTheme)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text("Satın Almaları Geri Yükle")
                }
            }
            .font(.body(11, weight: .medium))
            .foregroundStyle(Color.primaryTheme)
            .disabled(isPurchasing || isRestoring)

            Button {
                openURL("https://groopay.vercel.app\(pathPrefix)/privacy")
            } label: {
                Text("Gizlilik")
                    .font(.body(11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .underline()
            }

            Button {
                openURL("https://groopay.vercel.app\(pathPrefix)/terms")
            } label: {
                Text("Kullanım Koşulları")
                    .font(.body(11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .underline()
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Close

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(.top, 56)
        .padding(.trailing, 16)
    }

    private func purchase() async {
        guard authStore.canPurchase else { return }
        isPurchasing = true
        let success = await purchases.purchase()
        if success { await authStore.setProActive() }
        purchaseSuccess = success
        isPurchasing = false
    }

    private func restorePurchases() async {
        isRestoring = true
        let success = await purchases.restorePurchases()
        if success {
            await authStore.setProActive()
            showSuccess("Satın almaların geri yüklendi.")
        }
        isRestoring = false
    }

    private func showSuccess(_ message: String.LocalizationValue) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86)) {
            successMessage = String(localized: message, locale: locale)
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                successMessage = nil
            }
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func toast(_ message: String) -> some View {
        Text(message)
            .font(.body(13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.textPrimary.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 8)
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environment(PreviewSupport.authStore)
}
