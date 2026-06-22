import SwiftUI
import Supabase

#if TESTFLIGHT_DEV
import LocalAuthentication
#endif

struct AccountView: View {
    let store: GroupsStore

    @Environment(AuthStore.self) private var authStore
    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(\.appFeedback) private var feedback
    @State private var showPaywall = false
    @State private var showProfileEditor = false
    @State private var showDeleteConfirm = false
    @State private var showSignOutConfirm = false
    @State private var isDeleting = false
    @State private var isExporting = false
    @State private var exportDocument: UserDataExportDocument?
    @State private var exportFileName = UserDataExport.fileName()
    @State private var showExporter = false

    #if TESTFLIGHT_DEV
    @State private var isPreparingTestData = false
    @State private var isRemovingTestData = false
    #endif

    private var legalPathPrefix: String {
        localizationStore.languageCode == "en" ? "/en" : ""
    }

    private var privacyURL: String {
        "https://groopay.vercel.app\(legalPathPrefix)/privacy"
    }

    private var termsURL: String {
        "https://groopay.vercel.app\(legalPathPrefix)/terms"
    }

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Profil Kartı
                    profileCard

                    // Tercihler
                    preferencesSection

                    // Pro Kartı
                    proCard

                    #if TESTFLIGHT_DEV
                    developerSection
                    #endif

                    // İşlemler
                    actionsSection

                    // Yasal
                    legalSection

                    // Oturum / Tehlikeli
                    Spacer()
                        .frame(height: 12)
                    if authStore.sessionState == .identified {
                        signOutButton
                    }
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
        .tipsButton()
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showProfileEditor) {
            if let profile = authStore.currentProfile {
                ProfileEditView(profile: profile) { name, color in
                    try await authStore.updateProfile(name: name, color: color)
                    await store.load()
                    feedback.success(
                        String(localized: "Profil güncellendi.", locale: localizationStore.locale)
                    )
                }
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                feedback.success(
                    String(localized: "Verilerin dışa aktarıldı.", locale: localizationStore.locale)
                )
            case .failure:
                feedback.error(
                    String(localized: "Dışa aktarma başarısız.", locale: localizationStore.locale)
                )
            }
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
        .confirmationDialog(
            "Çıkış yapılsın mı?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Çıkış Yap", role: .destructive) {
                Task { await authStore.signOut() }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Verilerin korunur. Apple ile tekrar giriş yaparak geri dönebilirsin.")
        }
    }

    // MARK: - Profil

    private var profileCard: some View {
        profileCardContent
            .padding(18)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .purpleTintedShadow()
    }

    @ViewBuilder
    private var profileCardContent: some View {
        if authStore.sessionState == .anonymous {
            VStack(alignment: .leading, spacing: 16) {
                profileIdentity

                AppleSignInButton()
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: 16) {
                profileIdentity

                Spacer(minLength: 12)

                Button {
                    showProfileEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primaryTheme)
                        .frame(width: 36, height: 36)
                        .background(Color.surfaceTinted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profili Düzenle")
            }
        }
    }

    private var profileIdentity: some View {
        Button {
            guard authStore.currentProfile != nil else { return }
            showProfileEditor = true
        } label: {
            HStack(alignment: .center, spacing: 14) {
                GradientAvatar(
                    name: authStore.currentProfile?.displayName ?? "?",
                    color: authStore.currentProfile?.avatarColor
                        ?? AvatarPalette.fallback,
                    size: 56
                )

                VStack(alignment: .leading, spacing: 4) {
                    if authStore.sessionState == .anonymous {
                        Text(
                            authStore.currentProfile?.displayName
                                ?? String(
                                    localized: "Misafir Kullanıcı",
                                    locale: localizationStore.locale
                                )
                        )
                            .font(.display(18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Pro için Apple ile giriş yap")
                            .font(.body(14))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(
                            authStore.currentProfile?.displayName
                                ?? String(
                                    localized: "Kullanıcı",
                                    locale: localizationStore.locale
                                )
                        )
                            .font(.display(18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 6) {
                            if authStore.hasProAccess {
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
                            authStore.hasProAccess
                                ? LinearGradient(colors: [.gradientStart, .gradientEnd], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.textTertiary, Color.textTertiary], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pro

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dil")
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            Picker(
                "Dil",
                selection: Binding(
                    get: { localizationStore.selection },
                    set: { language in
                        localizationStore.select(language)
                        Task { await saveLanguage(language) }
                    }
                )
            ) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Text("Otomatik seçim, cihazınızın tercih edilen dilini kullanır.")
                .font(.body(12))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .purpleTintedShadow()
    }

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

            if authStore.hasProAccess {
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

    private func featureRow(
        icon: String,
        text: LocalizedStringResource
    ) -> some View {
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
        title: LocalizedStringResource,
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

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            showSignOutConfirm = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)
                Text("Çıkış Yap")
                    .font(.body(15, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
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

    // MARK: - TestFlight Developer Mode

    #if TESTFLIGHT_DEV
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: authStore.isDeveloperModeUnlocked ? "lock.open.fill" : "lock.fill")
                    .foregroundStyle(Color.warning)
                Text("TestFlight Geliştirici Modu")
                    .font(.display(16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(authStore.isDeveloperModeUnlocked ? "Açık" : "Kilitli")
                    .font(.body(12, weight: .semibold))
                    .foregroundStyle(authStore.isDeveloperModeUnlocked ? Color.credit : Color.textTertiary)
            }

            if authStore.isDeveloperModeUnlocked {
                Text("Pro erişimi bu cihazda geçici olarak açık. Test verileri gerçek test hesabına eklenir.")
                    .font(.body(12))
                    .foregroundStyle(Color.textSecondary)

                developerActionButton(
                    title: "Test Verilerini Kur / Tamamla",
                    icon: "wand.and.stars",
                    isLoading: isPreparingTestData
                ) {
                    Task { await prepareTestData() }
                }

                developerActionButton(
                    title: "Test Verilerini Sil",
                    icon: "trash",
                    color: .red,
                    isLoading: isRemovingTestData
                ) {
                    Task { await removeTestData() }
                }

                Button("Geliştirici Modunu Kilitle") {
                    authStore.setDeveloperModeUnlocked(false)
                }
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 40)
            } else {
                Text("Cihaz kimliğini doğrulayarak Pro araçlarını aç ve diline uygun örnek grup ve masrafları oluştur.")
                    .font(.body(12))
                    .foregroundStyle(Color.textSecondary)

                developerActionButton(
                    title: "Kilidi Aç ve Test Verilerini Kur",
                    icon: "lock.open.fill",
                    isLoading: isPreparingTestData
                ) {
                    Task { await unlockAndPrepareTestData() }
                }
            }
        }
        .padding(18)
        .background(Color.warning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.warning.opacity(0.3), lineWidth: 1)
        )
    }

    private func developerActionButton(
        title: LocalizedStringResource,
        icon: String,
        color: Color = .warning,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(color)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.body(14, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoading || isPreparingTestData || isRemovingTestData)
    }

    private func unlockAndPrepareTestData() async {
        isPreparingTestData = true
        defer { isPreparingTestData = false }

        do {
            let context = LAContext()
            let authenticated = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(
                    localized: "TestFlight geliştirici araçlarını aç",
                    locale: localizationStore.locale
                )
            )
            guard authenticated else { return }
            authStore.setDeveloperModeUnlocked(true)
            try await DeveloperTestData.seed(
                store: store,
                profile: authStore.currentProfile,
                languageCode: localizationStore.languageCode
            )
            feedback.success(
                String(localized: "Pro ve test verileri hazır.", locale: localizationStore.locale)
            )
        } catch {
            feedback.error(error.localizedDescription)
        }
    }

    private func prepareTestData() async {
        isPreparingTestData = true
        defer { isPreparingTestData = false }
        do {
            try await DeveloperTestData.seed(
                store: store,
                profile: authStore.currentProfile,
                languageCode: localizationStore.languageCode
            )
            feedback.success(
                String(localized: "Test verileri hazır.", locale: localizationStore.locale)
            )
        } catch {
            feedback.error(error.localizedDescription)
        }
    }

    private func removeTestData() async {
        isRemovingTestData = true
        defer { isRemovingTestData = false }
        do {
            try await DeveloperTestData.remove(from: store)
            feedback.success(
                String(localized: "Test verileri silindi.", locale: localizationStore.locale)
            )
        } catch {
            feedback.error(error.localizedDescription)
        }
    }
    #endif

    // MARK: - Helpers

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func saveLanguage(_ language: AppLanguage) async {
        do {
            try await authStore.updateLocale(language)
        } catch {
            feedback.error(
                String(localized: "Dil tercihi kaydedilemedi.", locale: localizationStore.locale)
            )
        }
    }

    /// Kullanıcının erişebildiği tüm yüklü grup snapshot'larını minor-unit Int
    /// koruyarak JSON'a aktarır. Önce store.load() ile veri yenilenir; sunum
    /// SwiftUI fileExporter ile yapılır (UIKit manuel presentation yok).
    private func handleExport() async {
        isExporting = true
        defer { isExporting = false }

        await store.load()

        let export = UserDataExport.make(
            snapshots: store.groups,
            profile: authStore.currentProfile,
            activities: store.activities
        )

        do {
            let data = try export.jsonData()
            exportDocument = UserDataExportDocument(data: data)
            exportFileName = UserDataExport.fileName(for: export.exportedAt)
            showExporter = true
        } catch {
            feedback.error(
                String(localized: "Dışa aktarma başarısız.", locale: localizationStore.locale)
            )
        }
    }

    private func handleDelete() async {
        isDeleting = true
        do {
            _ = try await SupabaseService.shared.functions
                .invoke("delete-account")
            // Hesap sunucuda silindi; yerel oturumu kapat. (Profili yeniden
            // yüklemeye çalışmak silinmiş satırı `.single()` ile okuyup
            // "Cannot coerce the result to a single JSON object" hatası verirdi.)
            await authStore.signOut()
        } catch {
            feedback.error(
                String(localized: "Hesap silme başarısız.", locale: localizationStore.locale)
            )
        }
        isDeleting = false
    }

}

// MARK: - Helpers

#Preview("Guest Account") {
    NavigationStack {
        AccountView(store: PreviewSupport.groupsStore)
    }
    .environment(PreviewSupport.anonymousAuthStore)
    .environment(LocalizationStore())
}

#Preview("Apple Account") {
    NavigationStack {
        AccountView(store: PreviewSupport.groupsStore)
    }
    .environment(PreviewSupport.authStore)
    .environment(LocalizationStore())
}
