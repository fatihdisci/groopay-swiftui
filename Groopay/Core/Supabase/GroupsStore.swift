import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class GroupsStore {
    private(set) var groups: [GroupSnapshot] = []
    private(set) var activities: [Activity] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var presentedPaywall = false

    private let supabase: SupabaseClient
    private let rpc: RPCClient

    init(supabase: SupabaseClient = SupabaseService.shared) {
        self.supabase = supabase
        rpc = RPCClient(supabase: supabase)
    }

    init(
        previewGroups: [GroupSnapshot],
        previewActivities: [Activity] = [],
        supabase: SupabaseClient
    ) {
        self.supabase = supabase
        rpc = RPCClient(supabase: supabase)
        groups = previewGroups
        activities = previewActivities
    }

    var overallBalance: [String: Int] {
        guard let userID = supabase.auth.currentUser?.id else { return [:] }
        var result: [String: Int] = [:]

        for snapshot in groups {
            guard let member = snapshot.currentMember(userID: userID) else {
                continue
            }

            let balance = computeBalance(
                expenses: snapshot.expenses,
                splits: snapshot.splits,
                confirmedSettlements: snapshot.settlements,
                for: member.id
            )

            for (currency, amount) in balance {
                result[currency, default: 0] += amount
            }
        }

        return result.filter { $0.value != 0 }
    }

    var createdNonDemoGroupCount: Int {
        guard let userID = supabase.auth.currentUser?.id else { return 0 }
        return groups.filter {
            $0.group.createdBy == userID && !$0.group.isDemo
        }.count
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let memberships: [GroupIDRow] = try await supabase
                .from("group_members")
                .select("group_id")
                .eq("is_active", value: true)
                .execute()
                .value

            let groupIDs = Array(Set(memberships.map(\.groupId)))
            guard !groupIDs.isEmpty else {
                groups = []
                return
            }

            async let groupRows: [Group] = supabase
                .from("groups")
                .select()
                .in("id", values: groupIDs)
                .eq("archived", value: false)
                .order("created_at", ascending: false)
                .execute()
                .value

            async let memberRows: [Member] = supabase
                .from("group_members")
                .select()
                .in("group_id", values: groupIDs)
                .order("created_at", ascending: true)
                .execute()
                .value

            async let expenseRows: [Expense] = supabase
                .from("expenses")
                .select()
                .in("group_id", values: groupIDs)
                .is("deleted_at", value: nil)
                .order("created_at", ascending: false)
                .execute()
                .value

            async let settlementRows: [Settlement] = supabase
                .from("settlements")
                .select()
                .in("group_id", values: groupIDs)
                .eq("status", value: SettlementStatus.confirmed.rawValue)
                .execute()
                .value

            let fetchedGroups = try await groupRows
            let fetchedMembers = try await memberRows
            let fetchedExpenses = try await expenseRows
            let fetchedSettlements = try await settlementRows
            let expenseIDs = fetchedExpenses.map(\.id)

            let fetchedSplits: [Split]
            if expenseIDs.isEmpty {
                fetchedSplits = []
            } else {
                fetchedSplits = try await supabase
                    .from("expense_splits")
                    .select()
                    .in("expense_id", values: expenseIDs)
                    .execute()
                    .value
            }

            groups = fetchedGroups.map { group in
                let expenses = fetchedExpenses.filter {
                    $0.groupId == group.id
                }
                let ids = Set(expenses.map(\.id))

                return GroupSnapshot(
                    group: group,
                    members: fetchedMembers.filter {
                        $0.groupId == group.id
                    },
                    expenses: expenses,
                    splits: fetchedSplits.filter {
                        ids.contains($0.expenseId)
                    },
                    settlements: fetchedSettlements.filter {
                        $0.groupId == group.id
                    }
                )
            }

            await loadActivities(groupIDs: groupIDs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Aktivite akışı en iyi çaba ile yüklenir; bir sorun olsa bile grup
    /// listesini düşürmemeli (bkz. expense_date decode dersi).
    private func loadActivities(groupIDs: [UUID]) async {
        do {
            activities = try await supabase
                .from("activity")
                .select()
                .in("group_id", values: groupIDs)
                .order("created_at", ascending: false)
                .limit(200)
                .execute()
                .value
        } catch {
            activities = []
        }
    }

    /// Realtime tetiklemesiyle önbelleği geçersiz kıl (manuel invalidate).
    func refreshFromRealtime() async {
        await load()
    }

    func createGroup(
        name: String,
        displayName: String,
        currency: String = "TRY"
    ) async -> Bool {
        let input = CreateGroupRPCInput(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            baseCurrency: currency,
            displayName: displayName
        )

        switch await rpc.createGroupWithLimit(input) {
        case .success:
            await load()
            return true
        case .failure(let error):
            if Self.isLimitError(error) {
                presentedPaywall = true
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    func updateGroup(
        id: UUID,
        name: String,
        description: String,
        emoji: String?,
        color: String
    ) async -> Bool {
        do {
            try await supabase
                .from("groups")
                .update(
                    GroupUpdate(
                        name: name,
                        description: description.isEmpty ? nil : description,
                        avatarEmoji: emoji,
                        avatarColor: color
                    )
                )
                .eq("id", value: id)
                .execute()
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Expenses

    var currentUserID: UUID? {
        supabase.auth.currentUser?.id
    }

    func snapshot(_ id: UUID) -> GroupSnapshot? {
        groups.first { $0.id == id }
    }

    /// Mevcut kullanıcının ilgili gruptaki aktif üye kaydının id'si (member id,
    /// user id değil). Masraf actor/createdBy alanları için gereklidir.
    func currentMemberID(in groupID: UUID) -> UUID? {
        snapshot(groupID)?.currentMember(userID: currentUserID)?.id
    }

    func addExpense(
        groupID: UUID,
        description: String,
        note: String?,
        amount: Int,
        currency: String,
        category: String,
        splitType: SplitType,
        paidBy: UUID,
        splits: [UUID: Int],
        date: Date = Date()
    ) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = "Üyelik bilgisi bulunamadı."
            return false
        }

        let input = AddExpenseRPCInput(
            groupId: groupID,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note?.isEmpty == true ? nil : note,
            amount: amount,
            currency: currency,
            category: category,
            splitType: splitType,
            paidBy: paidBy,
            createdBy: actor,
            expenseDate: Self.dateString(date),
            splits: Self.splitInputs(splits, currency: currency)
        )

        switch await rpc.addExpenseWithSplits(input) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateExpense(
        expenseID: UUID,
        groupID: UUID,
        description: String,
        note: String?,
        amount: Int,
        currency: String,
        category: String,
        splitType: SplitType,
        paidBy: UUID,
        splits: [UUID: Int],
        date: Date = Date()
    ) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = "Üyelik bilgisi bulunamadı."
            return false
        }

        let input = UpdateExpenseRPCInput(
            expenseId: expenseID,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note?.isEmpty == true ? nil : note,
            amount: amount,
            currency: currency,
            category: category,
            splitType: splitType,
            paidBy: paidBy,
            actorMemberId: actor,
            expenseDate: Self.dateString(date),
            splits: Self.splitInputs(splits, currency: currency)
        )

        switch await rpc.updateExpenseWithSplits(input) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteExpense(expenseID: UUID, groupID: UUID) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = "Üyelik bilgisi bulunamadı."
            return false
        }

        switch await rpc.deleteExpense(expenseId: expenseID, actorMemberId: actor) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func splitInputs(
        _ splits: [UUID: Int],
        currency: String
    ) -> [ExpenseSplitRPCInput] {
        splits.map {
            ExpenseSplitRPCInput(
                memberId: $0.key,
                shareAmount: $0.value,
                currency: currency
            )
        }
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func addGhost(
        groupID: UUID,
        displayName: String
    ) async -> Bool {
        do {
            try await supabase
                .from("group_members")
                .insert(
                    GhostMemberInsert(
                        groupId: groupID,
                        displayName: displayName
                    )
                )
                .execute()
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func createInvite(groupID: UUID) async -> String? {
        switch await rpc.createInvite(groupId: groupID) {
        case .success(let token):
            return token
        case .failure(let error):
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteGroup(_ id: UUID) async -> Bool {
        switch await rpc.deleteGroup(groupId: id) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removeMember(groupID: UUID, memberID: UUID) async -> Bool {
        switch await rpc.removeMember(groupId: groupID, memberId: memberID) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    func transferOwnership(
        groupID: UUID,
        memberID: UUID
    ) async -> Bool {
        switch await rpc.transferOwnership(
            groupId: groupID,
            newFounderMemberId: memberID
        ) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    func previewInvite(code: String) async -> InvitePreview? {
        switch await rpc.previewInvite(token: code) {
        case .success(let preview) where preview.error == nil:
            return preview
        case .success:
            errorMessage = "Davet kodu geçersiz veya süresi dolmuş."
            return nil
        case .failure(let error):
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func previewGhosts(code: String) async -> [Member] {
        switch await rpc.previewGhosts(token: code) {
        case .success(let members):
            return members
        case .failure(let error):
            errorMessage = error.localizedDescription
            return []
        }
    }

    func join(
        code: String,
        claimGhostID: UUID?,
        displayName: String
    ) async -> Bool {
        do {
            let response: JoinInviteResponse = try await supabase.functions
                .invoke(
                    "join-via-invite",
                    options: FunctionInvokeOptions(
                        body: JoinInviteRequest(
                            token: code.uppercased(),
                            claimGhostMemberId: claimGhostID,
                            displayName: displayName
                        )
                    )
                )

            guard response.success else {
                errorMessage = response.error ?? "Gruba katılınamadı."
                return false
            }

            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private static func isLimitError(_ error: RPCError) -> Bool {
        let text = error.localizedDescription.lowercased()
        return text.contains("5 grup")
            || text.contains("ücretsiz plan")
            || text.contains("free plan")
    }
}

private struct GroupIDRow: Decodable {
    let groupId: UUID

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
    }
}

private struct GroupUpdate: Encodable {
    let name: String
    let description: String?
    let avatarEmoji: String?
    let avatarColor: String

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case avatarEmoji = "avatar_emoji"
        case avatarColor = "avatar_color"
    }
}

private struct GhostMemberInsert: Encodable {
    let groupId: UUID
    let userId: UUID? = nil
    let displayName: String
    let role = MemberRole.member

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case displayName = "display_name"
        case role
    }
}

private struct JoinInviteRequest: Encodable {
    let token: String
    let claimGhostMemberId: UUID?
    let displayName: String
}

private struct JoinInviteResponse: Decodable {
    let success: Bool
    let action: String?
    let groupId: UUID?
    let groupName: String?
    let memberId: UUID?
    let error: String?
}
