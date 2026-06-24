import Foundation
import Observation

enum MainTab: Hashable {
    case dashboard
    case groups
    case activity
    case account
}

/// Grup detayında açılacak bölüm. Action center kartları doğrudan Ödeşme
/// bölümünü açmak için kullanır; nil ise grup varsayılan davranışıyla açılır
/// (borç varsa Ödeşme, yoksa Masraflar).
enum GroupDetailSection: String, Hashable, CaseIterable, Identifiable, Sendable {
    case expenses
    case balances

    var id: String { rawValue }

    var title: LocalizedStringResource {
        self == .expenses ? "Masraflar" : "Ödeşme"
    }
}

enum GroupRoute: Hashable {
    case detail(UUID, section: GroupDetailSection?)
    case members(UUID)
    case edit(UUID)
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: MainTab = .dashboard
    var groupPath: [GroupRoute] = []

    /// Push bildirimi ve genel grup açma davranışı: bölüm belirtilmez (nil),
    /// grup kendi varsayılan sekmesinde açılır.
    func openGroup(_ groupID: UUID) {
        openGroup(groupID, section: nil)
    }

    func openGroup(_ groupID: UUID, section: GroupDetailSection?) {
        selectedTab = .groups
        groupPath = [.detail(groupID, section: section)]
    }
}

extension Notification.Name {
    static let groopayOpenGroup = Notification.Name("groopay.open-group")
    static let groopayOpenPaywall = Notification.Name("groopay.open-paywall")
}
