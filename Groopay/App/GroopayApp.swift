import SwiftUI
import RevenueCat

@main
struct GroopayApp: App {
    @UIApplicationDelegateAdaptor(GroopayAppDelegate.self) private var appDelegate
    @State private var authStore: AuthStore
    @State private var localizationStore: LocalizationStore
    @State private var screenshotGroupsStore: GroupsStore?
    @State private var router = AppRouter()
    @State private var feedback = AppFeedbackCenter()

    init() {
        let screenshotMode = Self.hasArgument("-groopayScreenshots")

        if let language = Self.value(after: "-groopayLanguage"),
           let appLanguage = AppLanguage(rawValue: language) {
            UserDefaults.standard.set(
                appLanguage.rawValue,
                forKey: LocalizationStore.preferenceKey
            )
        }

        let localizationStore = LocalizationStore()
        _localizationStore = State(initialValue: localizationStore)

        if screenshotMode {
            _authStore = State(initialValue: PreviewSupport.authStore)
            _screenshotGroupsStore = State(initialValue: PreviewSupport.groupsStore)
        } else {
            // RevenueCat'i AuthStore'dan önce yapılandır: auth dinleyicisi
            // oturum gelir gelmez `logIn` çağıracak, SDK hazır olmalı.
            PurchasesManager.shared.configure()
            _authStore = State(initialValue: AuthStore())
            _screenshotGroupsStore = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            content
                .environment(authStore)
                .environment(localizationStore)
                .environment(router)
                .environment(\.appFeedback, feedback)
                .environment(\.locale, localizationStore.locale)
                .preferredColorScheme(.light)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let screenshotGroupsStore {
            MainTabView(store: screenshotGroupsStore)
        } else {
            RootView()
        }
    }

    private static func hasArgument(_ argument: String) -> Bool {
        CommandLine.arguments.contains(argument)
    }

    private static func value(after argument: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: argument) else {
            return nil
        }
        let valueIndex = CommandLine.arguments.index(after: index)
        guard CommandLine.arguments.indices.contains(valueIndex) else {
            return nil
        }
        return CommandLine.arguments[valueIndex]
    }
}
