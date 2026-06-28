import Foundation

struct ScannedReceiptItem: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var amountMinor: Int
    var assignedMemberIds: Set<UUID>

    var isAssigned: Bool {
        !assignedMemberIds.isEmpty
    }

    init(
        id: UUID = UUID(),
        name: String,
        amountMinor: Int,
        assignedMemberIds: Set<UUID> = []
    ) {
        self.id = id
        self.name = name
        self.amountMinor = amountMinor
        self.assignedMemberIds = assignedMemberIds
    }
}
