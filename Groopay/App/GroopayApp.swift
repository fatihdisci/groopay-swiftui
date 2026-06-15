import SwiftUI

@main
struct GroopayApp: App {
    @State private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                // Tasarım sistemi sabit açık temadır (background #F7F6FF,
                // surface beyaz, textPrimary koyu). Cihaz koyu moddayken
                // navigation başlıkları/sistem metinleri beyaza dönüp açık
                // arka planda kaybolmasın diye color scheme'i light'a sabitliyoruz.
                .preferredColorScheme(.light)
        }
    }
}
