import SwiftUI
import RevenueCat

@main
struct GroopayApp: App {
    @State private var authStore: AuthStore
    @State private var localizationStore: LocalizationStore
    @State private var screenshotGroupsStore: GroupsStore?

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
            _authStore = State(initialValue: AuthStore())
            _screenshotGroupsStore = State(initialValue: nil)
            PurchasesManager.shared.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            content
                .environment(authStore)
                .environment(localizationStore)
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
