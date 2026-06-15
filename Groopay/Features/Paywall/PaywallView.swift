import SwiftUI
import RevenueCat

// MARK: - Pro Feature Model

struct ProFeature: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
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
    @State private var purchases = PurchasesManager.shared
    @State private var selectedFeature = 0
    @State private var isPurchasing = false
    @State private var purchaseSuccess = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Arka plan - tüm ekranı kaplayan gradient + gri
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.gradientStart, .gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 260)
                Color.background
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Hero Alanı
                heroSection

                // Feature Carousel
                featureCarousel

                // Fiyat Kartı
                pricingCard

                // Devam Butonu
                continueButton

                // Footer Linkler
                footerLinks
            }

            // X Butonu
            closeButton
        }
        .task {
            await purchases.loadOfferings()
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

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 56)

            // Uygulama ikonu
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 80, height: 80)

                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Text("Groopay User Pro")
                .font(.display(28, weight: .extraBold))
                .foregroundStyle(.white)

            Text("Tüm özelliklere sınırsız erişim.")
                .font(.body(15))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }

    // MARK: - Feature Carousel

    private var featureCarousel: some View {
        VStack(spacing: 12) {
            TabView(selection: $selectedFeature) {
                ForEach(Array(proFeatures.enumerated()), id: \.element.id) { index, feature in
                    featurePage(feature)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 160)

            // Page dots
            HStack(spacing: 8) {
                ForEach(proFeatures.indices, id: \.self) { index in
                    Circle()
                        .fill(
                            index == selectedFeature
                                ? Color.primaryTheme
                                : Color.primaryTheme.opacity(0.18)
                        )
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.3), value: selectedFeature)
                }
            }
        }
        .padding(.vertical, 20)
    }

    private func featurePage(_ feature: ProFeature) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.primaryTheme.opacity(0.1))
                    .frame(width: 52, height: 52)

                Image(systemName: feature.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.primaryTheme)
            }

            Text(feature.title)
                .font(.display(20, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text(feature.subtitle)
                .font(.body(14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Pricing Card

    private var pricingCard: some View {
        VStack(spacing: 10) {
            if let product = purchases.monthlyProduct {
                Text(product.localizedPriceString)
                    .font(.display(36, weight: .extraBold))
                    .foregroundStyle(Color.textPrimary)

                Text("/ay")
                    .font(.body(15))
                    .foregroundStyle(Color.textSecondary)
            } else if purchases.isLoading {
                ProgressView()
                    .tint(.primaryTheme)
            } else {
                Text("Fiyat bilgisi yükleniyor…")
                    .font(.body(14))
                    .foregroundStyle(Color.textTertiary)
            }

            Text("Abonelik dönem sonunda otomatik yenilenir. İptal edilmezse ücret tahsil edilir. Hesap ayarlarından yönetebilirsiniz.")
                .font(.body(11))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 24)
        .purpleTintedShadow(radius: 20, y: 8)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            Task {
                isPurchasing = true
                purchaseSuccess = await purchases.purchase()
                isPurchasing = false
            }
        } label: {
            SwiftUI.Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Devam Et")
                        .font(.body(17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [.gradientStart, .gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isPurchasing || purchases.monthlyProduct == nil)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .opacity(purchases.monthlyProduct == nil ? 0.5 : 1)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 24) {
            Button("Satın Almaları Geri Yükle") {
                Task {
                    isPurchasing = true
                    purchaseSuccess = await purchases.restorePurchases()
                    isPurchasing = false
                }
            }
            .font(.body(12, weight: .medium))
            .foregroundStyle(Color.textSecondary)

            Button {
                guard let url = URL(string: "https://groopay.vercel.app/privacy") else { return }
                UIApplication.shared.open(url)
            } label: {
                Text("Gizlilik")
                    .font(.body(12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .underline()
            }

            Button {
                guard let url = URL(string: "https://groopay.vercel.app/terms") else { return }
                UIApplication.shared.open(url)
            } label: {
                Text("Kullanım Koşulları")
                    .font(.body(12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .underline()
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 20)
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
}

// MARK: - Preview

#Preview {
    PaywallView()
}
