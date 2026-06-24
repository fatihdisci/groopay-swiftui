import Foundation

enum AppLocalization {
    static func string(_ key: String, locale: Locale) -> String {
        let languageCode = locale.language.languageCode?.identifier == "en"
            ? "en"
            : "tr"
        guard let path = Bundle.main.path(
            forResource: languageCode,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else {
            return Bundle.main.localizedString(
                forKey: key,
                value: key,
                table: nil
            )
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
