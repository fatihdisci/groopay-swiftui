import SwiftUI

/// İnteraktif onboarding. Üç aşama yerel demo üzerinden çalışır; backend'e veri
/// YAZILMAZ. Son adım mevcut anonim giriş akışını çalıştırır. Bölüşme hesabı
/// gerçek `computeSplits` ile yapılır (ayrı demo matematiği yok).
struct OnboardingFlow: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    @State private var selection = 0
    @State private var splitMode: DemoSplit = .equal
    @State private var markedPaid = false

    private let meID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let ayseID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
    private let mertID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!

    private let stageCount = 3
    private let demoAmount = 120_000 // ₺1.200 (minor, TRY)
    private let demoCurrency = "TRY"

    private enum DemoSplit { case equal, selected }

    private var memberIDs: [UUID] { [meID, ayseID, mertID] }

    /// Gerçek hesaplama: eşit böl tüm üyeleri, seçili kişiler yalnız iki arkadaşı
    /// kapsar (sen ödedin, payın değişir).
    private var demoShares: [UUID: Int] {
        computeSplits(
            amount: demoAmount,
            type: splitMode == .equal ? .equal : .subset,
            memberIds: memberIDs,
            subset: splitMode == .selected ? [ayseID, mertID] : nil
        )
    }

    /// Senin net sonucun: ödediğin tutar eksi kendi payın (alacak = pozitif).
    private var userNet: Int {
        demoAmount - (demoShares[meID] ?? 0)
    }

    var body: some View {
        ZStack {
            Color.brand
                .ignoresSafeArea()

            VStack(spacing: 16) {
                topBar

                TabView(selection: $selection) {
                    stage(0) { stageOne }
                    stage(1) { stageTwo }
                    stage(2) { stageThree }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                bottomButton
            }
            .padding(20)

            if authStore.isLoading {
                ProgressView().tint(.white)
            }
        }
    }

    private func stage<Content: View>(
        _ index: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .tag(index)
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button("onboarding.skip") { finish() }
                .font(.body(15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(minWidth: 44, minHeight: 44)
                .disabled(authStore.isLoading)
        }
    }

    // MARK: - Stage 1: Örnek grup

    private var stageOne: some View {
        VStack(spacing: 22) {
            stageHeader(
                title: "Önce bir grup",
                message: "Arkadaşlarınla bir grup oluştur. Tüm ortak harcamalar tek bir yerde toplanır."
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text("🏖️")
                        .font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hafta Sonu")
                            .font(.display(18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("3 üye")
                            .font(.body(13))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: -10) {
                    demoAvatar("Sen", "#6366F1")
                    demoAvatar("Ayşe", "#EC4899")
                    demoAvatar("Mert", "#10B981")
                    Spacer()
                }
            }
            .padding(18)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Örnek grup Hafta Sonu, üç üye: Sen, Ayşe, Mert")
        }
    }

    // MARK: - Stage 2: Örnek masraf

    private var stageTwo: some View {
        VStack(spacing: 22) {
            stageHeader(
                title: "Bir masraf ekle",
                message: "Akşam yemeğini sen ödedin. Nasıl bölüşüleceğini seç; paylar anında güncellenir."
            )

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Akşam yemeği")
                            .font(.body(15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Sen ödedin")
                            .font(.body(12))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Text(formatAmount(demoAmount, currency: demoCurrency))
                        .font(.display(18, weight: .extraBold))
                        .foregroundStyle(Color.textPrimary)
                }

                Picker("Bölüşme", selection: $splitMode) {
                    Text("Eşit böl").tag(DemoSplit.equal)
                    Text("Seçili kişiler").tag(DemoSplit.selected)
                }
                .pickerStyle(.segmented)

                VStack(spacing: 0) {
                    demoShareRow("Sen", "#6366F1", id: meID)
                    Divider()
                    demoShareRow("Ayşe", "#EC4899", id: ayseID)
                    Divider()
                    demoShareRow("Mert", "#10B981", id: mertID)
                }
            }
            .padding(18)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: splitMode)
        }
    }

    private func demoShareRow(_ name: String, _ color: String, id: UUID) -> some View {
        let share = demoShares[id] ?? 0
        return HStack(spacing: 12) {
            demoAvatar(name, color, size: 34)
            Text(name)
                .font(.body(15, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(
                share > 0
                    ? formatAmount(share, currency: demoCurrency)
                    : String(localized: "Dahil değil", locale: locale)
            )
            .font(.body(14, weight: .semibold))
            .foregroundStyle(share > 0 ? Color.textPrimary : Color.textTertiary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stage 3: Sonuç

    private var stageThree: some View {
        VStack(spacing: 22) {
            stageHeader(
                title: "Sonucu gör",
                message: "Groopay kimin kime ne kadar borçlu olduğunu sadeleştirir."
            )

            VStack(spacing: 14) {
                if markedPaid {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.credit)
                        Text("Ödeştiniz")
                            .font(.display(20, weight: .extraBold))
                            .foregroundStyle(Color.credit)
                    }
                } else {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(Color.credit)
                            Text("Alacağın")
                                .font(.body(14, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Text(formatAmount(userNet, currency: demoCurrency))
                            .font(.display(28, weight: .extraBold))
                            .foregroundStyle(Color.credit)
                    }

                    Button {
                        if reduceMotion {
                            markedPaid = true
                        } else {
                            withAnimation(.spring(response: 0.35)) { markedPaid = true }
                        }
                    } label: {
                        Label("Ödendi olarak işaretle", systemImage: "checkmark")
                            .font(.body(15, weight: .semibold))
                            .foregroundStyle(Color.primaryTheme)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Color.primaryTheme.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        }
    }

    // MARK: - Shared pieces

    private func stageHeader(
        title: LocalizedStringResource,
        message: LocalizedStringResource
    ) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.display(28, weight: .extraBold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body(16))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 4)
    }

    private func demoAvatar(_ name: String, _ color: String, size: CGFloat = 44) -> some View {
        GradientAvatar(name: name, color: color, size: size)
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    private var bottomButton: some View {
        Button {
            if selection == stageCount - 1 {
                finish()
            } else if reduceMotion {
                selection += 1
            } else {
                withAnimation { selection += 1 }
            }
        } label: {
            Text(selection == stageCount - 1 ? "onboarding.start" : "onboarding.next")
                .font(.body(17, weight: .semibold))
                .foregroundStyle(Color.primaryTheme)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
        }
        .disabled(authStore.isLoading)
    }

    private func finish() {
        // Duplicate submit koruması: zaten yükleme sürüyorsa yeni giriş başlatma.
        guard !authStore.isLoading else { return }
        Task {
            await authStore.signInAnonymously()
            if authStore.sessionState != .signedOut {
                hasCompletedOnboarding = true
            }
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(PreviewSupport.signedOutAuthStore)
}
