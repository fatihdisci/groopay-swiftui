import SwiftUI
import RevenueCat

@main
struct GroopayApp: App {
    @State private var authStore = AuthStore()

    init() {
        PurchasesManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .preferredColorScheme(.light)
        }
    }
}
