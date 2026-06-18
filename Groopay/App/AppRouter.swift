import Foundation
import Observation

enum MainTab: Hashable {
    case dashboard
    case groups
    case activity
    case account
}

enum GroupRoute: Hashable {
    case detail(UUID)
    case members(UUID)
    case edit(UUID)
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: MainTab = .dashboard
    var groupPath: [GroupRoute] = []

    func openGroup(_ groupID: UUID) {
        selectedTab = .groups
        groupPath = [.detail(groupID)]
    }
}

extension Notification.Name {
    static let groopayOpenGroup = Notification.Name("groopay.open-group")
}
