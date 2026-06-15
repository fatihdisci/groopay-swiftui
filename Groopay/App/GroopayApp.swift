import SwiftUI
import RevenueCat

@main
struct GroopayApp: App {
    @State private var authStore = AuthStore()
    @State private var localizationStore = LocalizationStore()

    init() {
        PurchasesManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .environment(localizationStore)
                .environment(\.locale, localizationStore.locale)
                .preferredColorScheme(.light)
        }
    }
}
