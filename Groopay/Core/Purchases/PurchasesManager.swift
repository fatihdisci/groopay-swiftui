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
            errorMessage = error.localizedDescription
        }
    }

    func purchase() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let product = monthlyProduct else {
            errorMessage = String(
                localized: "Ürün bilgisi yüklenemedi.",
                locale: LocalizationStore.currentLocale()
            )
            return false
        }

        do {
            let result = try await Purchases.shared.purchase(product: product)
            return result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
