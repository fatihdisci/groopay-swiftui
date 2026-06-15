import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case automatic = "auto"
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .automatic:
            "Otomatik"
        case .turkish:
            "Türkçe"
        case .english:
            "English"
        }
    }
}

@MainActor
@Observable
final class LocalizationStore {
    nonisolated static let preferenceKey = "appLanguage"

    private(set) var selection: AppLanguage

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private let preferredLanguages: () -> [String]

    init(
        defaults: UserDefaults = .standard,
        preferredLanguages: @escaping () -> [String] = {
            Locale.preferredLanguages
        }
    ) {
        self.defaults = defaults
        self.preferredLanguages = preferredLanguages
        selection = AppLanguage(
            rawValue: defaults.string(forKey: Self.preferenceKey) ?? ""
        ) ?? .automatic
    }

    var languageCode: String {
        switch selection {
        case .automatic:
            Self.supportedLanguageCode(from: preferredLanguages())
        case .turkish:
            "tr"
        case .english:
            "en"
        }
    }

    var locale: Locale {
        Locale(identifier: languageCode == "en" ? "en_US" : "tr_TR")
    }

    func select(_ language: AppLanguage) {
        selection = language
        defaults.set(language.rawValue, forKey: Self.preferenceKey)
    }

    nonisolated static func currentLocale(
        defaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Locale {
        let selection = AppLanguage(
            rawValue: defaults.string(forKey: preferenceKey) ?? ""
        ) ?? .automatic

        let code: String
        switch selection {
        case .automatic:
            code = supportedLanguageCode(from: preferredLanguages)
        case .turkish:
            code = "tr"
        case .english:
            code = "en"
        }
        return Locale(identifier: code == "en" ? "en_US" : "tr_TR")
    }

    nonisolated static func supportedLanguageCode(
        from preferredLanguages: [String]
    ) -> String {
        for identifier in preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?
                .identifier
            if code == "tr" || code == "en" {
                return code ?? "tr"
            }
        }
        return "tr"
    }
}
