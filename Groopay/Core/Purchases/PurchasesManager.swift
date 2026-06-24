import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class PurchasesManager {
    static let shared = PurchasesManager()

    private(set) var offerings: Offerings?
    private(set) var monthlyProduct: StoreProduct?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Optimistic entitlement state — gerçek kaynak `profiles.user_pro`.
    /// RevenueCat SDK entitlement'ını okur, ama asıl doğrulama server'dan gelir
    /// (webhook → profiles.user_pro). Bu değer UI'da optimistic gösterim içindir;
    /// gerçek gate `AuthStore.currentProfile?.userPro` ile yapılır.
    var hasProAccess: Bool {
        Purchases.shared.cachedCustomerInfo?
            .entitlements[Self.entitlementID]?.isActive == true
    }

    private static let entitlementID = "user_pro"

    private var hasConfigured = false

    private init() {}

    func configure() {
        guard !hasConfigured else { return }
        hasConfigured = true

        guard
            let apiKey = Bundle.main.object(
                forInfoDictionaryKey: "REVENUECAT_API_KEY"
            ) as? String,
            !apiKey.isEmpty,
            apiKey != "placeholder"
        else {
            errorMessage = "RevenueCat API key not configured"
            return
        }

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }

    /// Supabase kullanıcı kimliğini RevenueCat'e bağlar. Webhook'un satın alımı
    /// doğru profile (`profiles.user_pro`) eşleyebilmesi için zorunludur — aksi
    /// halde RC anonim bir app user id kullanır ve webhook profili güncelleyemez.
    /// Anonim bir oturumda yapılmış satın alım varsa `logIn` onu bu kimliğe
    /// taşır (alias), böylece eski satın almalar da kurtulur.
    func logIn(userID: String) async {
        guard Purchases.isConfigured else { return }
        do {
            _ = try await Purchases.shared.logIn(userID)
        } catch {
            errorMessage = userErrorMessage(error)
        }
    }

    func logOut() async {
        guard Purchases.isConfigured else { return }
        _ = try? await Purchases.shared.logOut()
    }

    /// Sunucudan taze `CustomerInfo` çekip Pro entitlement'ının aktif olup
    /// olmadığını döndürür. Açılışta profil ile entitlement'ı uzlaştırmak için.
    func refreshCustomerInfo() async -> Bool {
        guard Purchases.isConfigured else { return false }
        do {
            let info = try await Purchases.shared.customerInfo()
            return info.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            return false
        }
    }

    func loadOfferings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await Purchases.shared.offerings()
            offerings = fetched

            // com.groopay.app.userpro product'unu current offering'de ara
            if let current = fetched.current {
                monthlyProduct = current.monthly?.storeProduct
                    ?? current.availablePackages.first(where: {
                        $0.packageType == .monthly
                    })?.storeProduct
            }

            if monthlyProduct == nil {
                // Fallback: tüm offerings içinde product identifier'a göre ara
                for offering in fetched.all.values {
                    if let pkg = offering.package(identifier: "com.groopay.app.userpro") {
                        monthlyProduct = pkg.storeProduct
                        break
                    }
                }
            }
        } catch {
            errorMessage = userErrorMessage(error)
        }
    }

    func purchase() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let product = monthlyProduct else {
            errorMessage = String(
                localized: "Fiyat bilgisi alınamadı · App Store bağlantısı kurulamadı · İnternetini kontrol edip tekrar dene",
                locale: LocalizationStore.currentLocale()
            )
            return false
        }

        do {
            let result = try await Purchases.shared.purchase(product: product)
            return result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            return customerInfo.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    /// Kullanıcıya gösterilecek [ne oldu]·[neden]·[ne yapmalı] formatlı hata mesajı.
    private func userErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain || nsError.domain == "NSURLErrorDomain" {
            return String(localized: "App Store'a bağlanılamadı · İnternet bağlantını kontrol et · Tekrar dene")
        }
        return String(localized: "Satın alma tamamlanamadı · Beklenmeyen bir hata oluştu · Tekrar dene")
    }

    func clearError() {
        errorMessage = nil
    }
}
