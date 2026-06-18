import Foundation
import WidgetKit

enum WidgetBalanceSync {
    static let appGroupID = "group.com.groopay.app"
    static let storageKey = "groopay.balance-summary"
    static let widgetKind = "GroopayBalanceWidget"

    static func save(_ summary: BalanceSummary) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(summary) else { return }
        defaults.set(data, forKey: storageKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
