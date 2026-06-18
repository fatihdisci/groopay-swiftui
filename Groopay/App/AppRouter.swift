import Foundation
import Observation

enum MainTab: Hashable {
    case dashboard
    case groups
    case activity
    case account
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: MainTab = .dashboard
    var groupPath: [UUID] = []

    func openGroup(_ groupID: UUID) {
        selectedTab = .groups
        groupPath = [groupID]
    }
}

extension Notification.Name {
    static let groopayOpenGroup = Notification.Name("groopay.open-group")
}
