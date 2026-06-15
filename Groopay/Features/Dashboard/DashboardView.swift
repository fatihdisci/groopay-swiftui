import SwiftUI

struct DashboardView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Hero Kart
                    heroCard

                    if authStore.currentProfile?.userPro == true {
                        // Pro — tam dashboard
                        proContent
                    } else {
                        // Ücretsiz — paywall teaser
                        freeContent
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("tab.dashboard")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white)

            Text("Harcama Özeti")
                .font(.display(22, weight: .bold))
                .foregroundStyle(.white)

            Text(authStore.currentProfile?.userPro == true
                 ? "Tüm gruplarının para birimi bazında özeti."
                 : "Pro'ya geçerek gelişmiş panele eriş.")
                .font(.body(14))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            LinearGradient(
                colors: [.gradientStart, .gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .purpleTintedShadow(radius: 20, y: 8)
    }

    // MARK: - Pro Content

    @ViewBuilder
    private var proContent: some View {
        // Kategori Analizi kartı
        categoryCard

        // Yakında eklenecek özellikler…
        VStack(alignment: .leading, spacing: 12) {
            Text("Kullanıma Hazır")
                .font(.display(17, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            proFeatureRow(
                icon: "chart.pie.fill",
                title: "Kategori Analizi",
                subtitle: "Harcamalarını kategorilere göre incele."
            )

            proFeatureRow(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                title: "Trendler",
                subtitle: "Zaman içindeki harcama değişimini takip et."
            )
        }
    }

    private var categoryCard: some View {
        VStack(spacing: 12) {
            Text("Kategori Analizi")
                .font(.display(17, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                categoryPill(color: .orange, label: "Yemek")
                categoryPill(color: .blue, label: "Ulaşım")
                categoryPill(color: .green, label: "Alışveriş")
            }

            Text("Pro analitik yakında daha da detaylanacak.")
                .font(.body(13))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    private func categoryPill(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.body(13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private func proFeatureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryTheme)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.body(13))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - Free Content

    private var freeContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.textTertiary)

            Text("Gelişmiş Panel Pro'ya Özel")
                .font(.display(17, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("Tüm gruplarının para birimi bazında özetini, harcama trendlerini ve kategorilerini görmek için Pro'ya geç.")
                .font(.body(14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                showPaywall = true
            } label: {
                Text("Pro'ya Geç")
                    .font(.body(16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        LinearGradient(
                            colors: [.gradientStart, .gradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(PreviewSupport.authStore)
}
