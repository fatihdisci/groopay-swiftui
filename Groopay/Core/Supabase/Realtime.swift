import Foundation
import Realtime
import Supabase

/// Kullanıcının üye olduğu gruplara realtime abone olur. expenses / settlements /
/// activity tablolarındaki her değişimde bağlı GroupsStore'u yeniden yükler
/// (manuel cache invalidate). expense_splits'te group_id kolonu yoktur; bir
/// masraf değişimi zaten splits'i de yeniden çektiğinden ona abone olmaya gerek yok.
@MainActor
final class RealtimeManager {
    private let supabase: SupabaseClient
    private weak var groupsStore: GroupsStore?

    private var channels: [RealtimeChannelV2] = []
    private var listenerTasks: [Task<Void, Never>] = []
    private var subscribedGroupIDs: Set<UUID> = []

    private static let watchedTables = ["expenses", "settlements", "activity"]

    init(supabase: SupabaseClient = SupabaseService.shared) {
        self.supabase = supabase
    }

    func attach(_ store: GroupsStore) {
        groupsStore = store
    }

    /// İzlenen grup kümesini günceller. Değişiklik yoksa hiçbir şey yapmaz.
    func sync(groupIDs: [UUID]) async {
        let target = Set(groupIDs)
        guard target != subscribedGroupIDs else { return }

        await stop()
        subscribedGroupIDs = target

        for groupID in target {
            await subscribe(groupID: groupID)
        }
    }

    func stop() async {
        for task in listenerTasks { task.cancel() }
        listenerTasks.removeAll()

        for channel in channels {
            await supabase.removeChannel(channel)
        }
        channels.removeAll()
        subscribedGroupIDs.removeAll()
    }

    private func subscribe(groupID: UUID) async {
        let channel = supabase.channel("groopay:group:\(groupID.uuidString)")
        var groupListenerTasks: [Task<Void, Never>] = []

        for table in Self.watchedTables {
            let stream = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: table,
                filter: .eq("group_id", value: groupID.uuidString)
            )

            let task = Task { [weak self] in
                for await _ in stream {
                    guard !Task.isCancelled else { return }
                    await self?.groupsStore?.refreshFromRealtime()
                }
            }
            groupListenerTasks.append(task)
        }

        do {
            try await channel.subscribeWithError()
            listenerTasks.append(contentsOf: groupListenerTasks)
            channels.append(channel)
        } catch {
            groupListenerTasks.forEach { $0.cancel() }
            await supabase.removeChannel(channel)
            #if DEBUG
            print("Realtime subscription failed for group \(groupID): \(error)")
            #endif
        }
    }
}
