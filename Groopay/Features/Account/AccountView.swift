import SwiftUI
import Supabase

struct AccountView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var isExporting = false
    @State private var toastMessage: String?

    private let privacyURL = "https://groopay.vercel.app/privacy"
    private let termsURL = "https://groopay.vercel.app/terms"

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Profil Kartı
                    profileCard

                    // Pro Kartı
                    proCard

                    // İşlemler
                    actionsSection

                    // Yasal
                    legalSection

                    // Tehlikeli
                    Spacer()
                        .frame(height: 12)
                    dangerZone

                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Hesabım")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .confirmationDialog(
            "Hesabın silinsin mi?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Hesabımı Sil", role: .destructive) {
                Task { await handleDelete() }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz. Tüm grup verilerine erişimin silinir ve Pro aboneliğin iptal olur.")
        }
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                toastView(message)
            }
        }
    }

    // MARK: - Profil

    private var profileCard: some View {
        HStack(spacing: 16) {
            GradientAvatar(
                name: authStore.currentProfile?.displayName ?? "?",
                color: authStore.currentProfile?.avatarColor ?? "#4F46E5",
                size: 56
            )

            VStack(alignment: .leading, spacing: 4) {
                if authStore.sessionState == .anonymous {
                    Text("Misafir Kullanıcı")
                        .font(.display(18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Pro için Apple ile giriş yap")
                        .font(.body(14))
                        .foregroundStyle(Color.textSecondary)
                } else {
                    Text(authStore.currentProfile?.displayName ?? "Kullanıcı")
                        .font(.display(18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    HStack(spacing: 6) {
                        if authStore.currentProfile?.userPro == true {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 11))
                            Text("Pro")
                                .font(.body(12, weight: .semibold))
                        } else {
                            Text("Ücretsiz")
                                .font(.body(12, weight: .medium))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        authStore.currentProfile?.userPro == true
                            ? LinearGradient(colors: [.gradientStart, .gradientEnd], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.textTertiary, Color.textTertiary], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                }
            }

            Spacer()

            if authStore.sessionState == .anonymous {
                AppleSignInButton()
                    .frame(width: 150)
            }
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    // MARK: - Pro

    private var proCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.primaryTheme)
                Text("Groopay Pro")
                    .font(.display(16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }

            if authStore.currentProfile?.userPro == true {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.credit)
                    Text("Pro aboneliğin aktif")
                        .font(.body(14, weight: .medium))
                        .foregroundStyle(Color.credit)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    featureRow(icon: "chart.bar.fill", text: "Gelişmiş Panel")
                    featureRow(icon: "person.2.fill", text: "Sınırsız Grup")
                    featureRow(icon: "chart.pie.fill", text: "Kategori Analizi")
                    featureRow(icon: "magnifyingglass", text: "Aktivite Arama")
                }

                Button {
                    showPaywall = true
                } label: {
                    Text("Pro'ya Geç")
                        .font(.body(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
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
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primaryTheme)
                .frame(width: 22)
            Text(text)
                .font(.body(14))
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionButton(
        icon: String,
        title: String,
        color: Color,
        isLoading: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 14) {
                if isLoading {
                    ProgressView()
                        .tint(color)
                        .frame(width: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                        .frame(width: 20)
                }

                Text(title)
                    .font(.body(15))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
        }
        .disabled(isLoading)
    }

    private var actionsSection: some View {
        VStack(spacing: 0) {
            actionButton(
                icon: "square.and.arrow.up",
                title: "Verilerimi Dışa Aktar",
                color: Color.primaryTheme,
                isLoading: isExporting
            ) {
                Task { await handleExport() }
            }

            Divider()
                .padding(.leading, 52)

            actionButton(
                icon: "doc.text",
                title: "Gizlilik Politikası",
                color: Color.textSecondary
            ) {
                openURL(privacyURL)
            }

            Divider()
                .padding(.leading, 52)

            actionButton(
                icon: "list.clipboard",
                title: "Kullanım Koşulları",
                color: Color.textSecondary
            ) {
                openURL(termsURL)
            }
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Yasal")
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .padding(.leading, 6)

            Link(destination: URL(string: privacyURL)!) {
                HStack {
                    Text("Gizlilik Politikası")
                        .font(.body(15))
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.primaryTheme)
                .padding(.vertical, 4)
            }

            Link(destination: URL(string: termsURL)!) {
                HStack {
                    Text("Kullanım Koşulları")
                        .font(.body(15))
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.primaryTheme)
                .padding(.vertical, 4)
            }
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: 0) {
            Button {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                    Text("Hesabımı Sil")
                        .font(.body(15, weight: .medium))
                        .foregroundStyle(.red)
                    Spacer()

                    if isDeleting {
                        ProgressView()
                            .tint(.red)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .disabled(isDeleting)
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - DEV

    #if DEBUG
    private var devToggle: some View {
        Button {
            Task { await togglePro() }
        } label: {
            HStack {
                Image(systemName: "wrench.fill")
                    .font(.system(size: 14))
                Text("Pro Aç/Kapat (Geliştirici)")
                    .font(.body(14, weight: .medium))
            }
            .foregroundStyle(Color.warning)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

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

    // MARK: - Helpers

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func handleExport() async {
        isExporting = true
        // TODO: Supabase'ten kullanıcı verilerini JSON olarak çek, paylaş
        do {
            let supabase = SupabaseService.shared
            guard let userID = supabase.auth.currentUser?.id else { return }

            let groups: [Group] = try await supabase
                .from("group_members")
                .select("group:groups!inner(*)")
                .eq("user_id", value: userID)
                .execute()
                .value

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(groups)

            // Kaydet + Share Sheet
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("groopay-export.json")
            try data.write(to: tempURL)

            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )
            
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                activityVC.popoverPresentationController?.sourceView = rootVC.view
                rootVC.present(activityVC, animated: true)
            }

            withAnimation {
                toastMessage = "Veriler hazır, paylaşım ekranı açılıyor."
            }
            try? await Task.sleep(for: .seconds(2))
            withAnimation { toastMessage = nil }
        } catch {
            withAnimation {
                toastMessage = "Dışa aktarma başarısız: \(error.localizedDescription)"
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { toastMessage = nil }
        }
        isExporting = false
    }

    private func handleDelete() async {
        isDeleting = true
        do {
            _ = try await SupabaseService.shared.functions
                .invoke("delete-account")
            await authStore.loadProfile()
        } catch {
            withAnimation {
                toastMessage = "Hesap silme başarısız."
            }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { toastMessage = nil }
        }
        isDeleting = false
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(.body(14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.textPrimary.opacity(0.88))
            .clipShape(Capsule())
            .padding(.bottom, 36)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Helpers

#Preview {
    NavigationStack {
        AccountView()
    }
    .environment(PreviewSupport.authStore)
}
