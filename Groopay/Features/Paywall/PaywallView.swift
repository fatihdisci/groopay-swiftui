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
        id: "groups",
        icon: "person.2.fill",
        title: "Sınırsız grup oluştur",
        subtitle: "Free planda 10 aktif grup oluşturabilirsin. Pro ile oluşturduğun aktif gruplarda sınır kalkar."
    ),
    ProFeature(
        id: "trends",
        icon: "chart.xyaxis.line",
        title: "Harcama trendlerini gör",
        subtitle: "Seçtiğin para biriminde harcamalarının zaman içindeki hareketini takip et."
    ),
    ProFeature(
        id: "analytics",
        icon: "chart.bar.doc.horizontal",
        title: "Detaylı grup analizleri",
        subtitle: "En hareketli ayı, popüler kategoriyi, en çok ödeyeni ve ödeşme özetini gör."
    ),
]

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appFeedback) private var feedback
    @Environment(AuthStore.self) private var authStore
    @State private var purchases = PurchasesManager.shared
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseSuccess = false
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
        .onChange(of: purchases.errorMessage) { _, message in
            if let message {
                feedback.error(message)
                purchases.clearError()
            }
        }
    }

    private var paywallBackground: some View {
        ZStack(alignment: .top) {
            Color.background
                .ignoresSafeArea()

            Color.brand
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

                Text("Sınırsız grup oluştur, harcama trendlerini ve detaylı analizleri aç.")
                    .font(.body(14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            HStack(spacing: 10) {
                heroPill("Sınırsız grup oluştur")
                heroPill("Harcama trendleri")
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

            // Cancel anytime güven pill'i — yasal metinden ÖNCE gösterilir.
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.credit)
                Text("İstediğin zaman iptal et")
                    .font(.body(11, weight: .medium))
                    .foregroundStyle(Color.credit)
            }
            .padding(.top, 2)

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

            Text("Satın almanı Apple hesabına bağlamak için giriş yap. Böylece yeni telefonunda da Pro'nu geri yükleyebilirsin.")
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
            .background(Color.brand)
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
        if success {
            await authStore.setProActive()
            EndowmentNotificationScheduler.cancelIfScheduled()
        }
        purchaseSuccess = success
        isPurchasing = false
    }

    private func restorePurchases() async {
        isRestoring = true
        let success = await purchases.restorePurchases()
        if success {
            await authStore.setProActive()
            EndowmentNotificationScheduler.cancelIfScheduled()
            feedback.success(
                String(localized: "Satın almaların geri yüklendi.", locale: locale)
            )
        }
        isRestoring = false
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

}

// MARK: - Preview

#Preview {
    PaywallView()
        .environment(PreviewSupport.authStore)
}
