import Foundation
import Realtime
import Supabase

/// Kullanıcının üye olduğu gruplara realtime abone olur. expenses / settlements /
/// activity / üyelik tablolarındaki her değişimde bağlı GroupsStore'u yeniden
/// yükler (manuel cache invalidate).
@MainActor
final class RealtimeManager {
    private let supabase: SupabaseClient
    private weak var groupsStore: GroupsStore?

    private var channels: [RealtimeChannelV2] = []
    private var listenerTasks: [Task<Void, Never>] = []
    private var subscribedGroupIDs: Set<UUID> = []
    private var subscribedUserID: UUID?

    private static let groupScopedTables = [
        "expenses",
        "settlements",
        "activity",
        "group_members"
    ]

    init(supabase: SupabaseClient = SupabaseService.shared) {
        self.supabase = supabase
    }

    func attach(_ store: GroupsStore) {
        groupsStore = store
    }

    /// İzlenen grup kümesini günceller. Değişiklik yoksa hiçbir şey yapmaz.
    func sync(groupIDs: [UUID]) async {
        let target = Set(groupIDs)
        let userID = supabase.auth.currentUser?.id
        guard target != subscribedGroupIDs || userID != subscribedUserID else {
            return
        }

        await stop()
        subscribedGroupIDs = target
        subscribedUserID = userID

        if let userID {
            await subscribeMemberships(userID: userID)
            await subscribeExpenseSplits(userID: userID)
        }

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
        subscribedUserID = nil
    }

    private func subscribeMemberships(userID: UUID) async {
        let channel = supabase.channel("groopay:user-memberships:\(userID.uuidString)")
        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "group_members",
            filter: .eq("user_id", value: userID.uuidString)
        )

        let task = Task { [weak self] in
            for await _ in stream {
                guard !Task.isCancelled else { return }
                await self?.groupsStore?.refreshFromRealtime()
            }
        }

        do {
            try await channel.subscribeWithError()
            listenerTasks.append(task)
            channels.append(channel)
        } catch {
            task.cancel()
            await supabase.removeChannel(channel)
            #if DEBUG
            print("Realtime membership subscription failed: \(error)")
            #endif
        }
    }

    private func subscribeExpenseSplits(userID: UUID) async {
        let channel = supabase.channel("groopay:expense-splits:\(userID.uuidString)")
        let stream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "expense_splits"
        )

        let task = Task { [weak self] in
            for await _ in stream {
                guard !Task.isCancelled else { return }
                await self?.groupsStore?.refreshFromRealtime()
            }
        }

        do {
            try await channel.subscribeWithError()
            listenerTasks.append(task)
            channels.append(channel)
        } catch {
            task.cancel()
            await supabase.removeChannel(channel)
            #if DEBUG
            print("Realtime expense split subscription failed: \(error)")
            #endif
        }
    }

    private func subscribe(groupID: UUID) async {
        let channel = supabase.channel("groopay:group:\(groupID.uuidString)")
        var groupListenerTasks: [Task<Void, Never>] = []

        for table in Self.groupScopedTables {
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

        let groupStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "groups",
            filter: .eq("id", value: groupID.uuidString)
        )

        groupListenerTasks.append(
            Task { [weak self] in
                for await _ in groupStream {
                    guard !Task.isCancelled else { return }
                    await self?.groupsStore?.refreshFromRealtime()
                }
            }
        )

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
