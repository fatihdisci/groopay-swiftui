import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class GroupsStore {
    static let freeCreatedGroupLimit = 10

    private(set) var groups: [GroupSnapshot] = []
    private(set) var activities: [Activity] = []
    private(set) var recurringRules: [UUID: [RecurringExpenseRule]] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var presentedPaywall = false
    var isUsingPreviewData: Bool {
        usesPreviewData
    }

    private let supabase: SupabaseClient
    private let rpc: RPCClient
    private let previewUserID: UUID?
    private let usesPreviewData: Bool
    private var needsReloadAfterCurrentLoad = false
    private var realtimeRefreshTask: Task<Void, Never>?

    init(supabase: SupabaseClient = SupabaseService.shared) {
        self.supabase = supabase
        rpc = RPCClient(supabase: supabase)
        previewUserID = nil
        usesPreviewData = false
    }

    init(
        previewGroups: [GroupSnapshot],
        previewActivities: [Activity] = [],
        previewUserID: UUID? = nil,
        supabase: SupabaseClient
    ) {
        self.supabase = supabase
        rpc = RPCClient(supabase: supabase)
        self.previewUserID = previewUserID
        usesPreviewData = true
        groups = previewGroups
        activities = previewActivities
    }

    var overallBalance: [String: Int] {
        guard let userID = currentUserID else { return [:] }
        var result: [String: Int] = [:]

        for snapshot in groups {
            guard let member = snapshot.currentMember(userID: userID) else {
                continue
            }

            let balance = computeBalance(
                expenses: snapshot.expenses,
                splits: snapshot.splits,
                settlements: snapshot.settlements,
                for: member.id
            )

            for (currency, amount) in balance {
                result[currency, default: 0] += amount
            }
        }

        return result.filter { $0.value != 0 }
    }

    var balanceSummary: BalanceSummary {
        BalanceSummary.calculate(groups: groups, userID: currentUserID)
    }

    var createdActiveNonDemoGroupCount: Int {
        guard let userID = currentUserID else { return 0 }
        return groups.filter {
            $0.group.createdBy == userID && !$0.group.isDemo && !$0.group.archived
        }.count
    }

    func load() async {
        guard !usesPreviewData else { return }
        guard !isLoading else {
            needsReloadAfterCurrentLoad = true
            return
        }

        isLoading = true
        errorMessage = nil

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
                activities = []
                WidgetBalanceSync.save(.empty)
                isLoading = false
                await runPendingReloadIfNeeded()
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

            // pending + confirmed çekilir (pending UI'da onay akışı için lazım).
            // computeBalance internally filters only confirmed settlements.
            async let settlementRows: [Settlement] = supabase
                .from("settlements")
                .select()
                .in("group_id", values: groupIDs)
                .in(
                    "status",
                    values: [
                        SettlementStatus.pending.rawValue,
                        SettlementStatus.confirmed.rawValue
                    ]
                )
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

            WidgetBalanceSync.save(balanceSummary)

            await loadActivities(groupIDs: groupIDs)
        } catch is CancellationError {
            // Cancellation is lifecycle/control flow, not a user-facing failure.
            // A later realtime event or view refresh will request another load.
        } catch {
            errorMessage = userErrorMessage(error)
        }

        isLoading = false
        await runPendingReloadIfNeeded()
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
        realtimeRefreshTask?.cancel()
        realtimeRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            // The debounce task must stop being the cancellable task before the
            // actual load starts. Otherwise a second realtime event cancels the
            // in-flight Supabase requests and surfaces Swift.CancellationError.
            self?.realtimeRefreshTask = nil
            await self?.load()
        }
    }

    private func runPendingReloadIfNeeded() async {
        guard needsReloadAfterCurrentLoad else { return }
        needsReloadAfterCurrentLoad = false
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
                errorMessage = userErrorMessage(error)
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
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    // MARK: - Expenses

    var currentUserID: UUID? {
        supabase.auth.currentUser?.id ?? previewUserID
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
            errorMessage = localized("Bu gruba erişimin yok · Grup sana ait değil veya çıkarıldın · Grup sahibiyle iletişime geç")
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
            errorMessage = userErrorMessage(error)
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
            errorMessage = localized("Bu gruba erişimin yok · Grup sana ait değil veya çıkarıldın · Grup sahibiyle iletişime geç")
            return false
        }
        guard snapshot(groupID)?.expenses.first(where: { $0.id == expenseID })?.createdBy == actor else {
            errorMessage = localized("Bu masrafı düzenleyemezsin · Masrafı sen eklemedin · Masrafı ekleyen kişiden düzenlemesini iste")
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
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    func deleteExpense(expenseID: UUID, groupID: UUID) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = localized("Bu gruba erişimin yok · Grup sana ait değil veya çıkarıldın · Grup sahibiyle iletişime geç")
            return false
        }
        guard snapshot(groupID)?.expenses.first(where: { $0.id == expenseID })?.createdBy == actor else {
            errorMessage = localized("Bu masrafı silemezsin · Masrafı sen eklemedin · Masrafı ekleyen kişiden silmesini iste")
            return false
        }

        switch await rpc.deleteExpense(expenseId: expenseID, actorMemberId: actor) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    func restoreExpense(expenseID: UUID, groupID: UUID) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = localized("Bu gruba erişimin yok · Grup sana ait değil veya çıkarıldın · Grup sahibiyle iletişime geç")
            return false
        }

        switch await rpc.restoreExpense(
            expenseId: expenseID,
            actorMemberId: actor
        ) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    // MARK: - Settlements

    /// Borçlu "Ödedim" der → pending settlement oluşturulur; karşı taraf onaylar.
    func markPaid(
        groupID: UUID,
        fromMember: UUID,
        toMember: UUID,
        amount: Int,
        currency: String
    ) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = localized("Bu gruba erişimin yok · Grup sana ait değil veya çıkarıldın · Grup sahibiyle iletişime geç")
            return false
        }

        let input = AddSettlementRPCInput(
            groupId: groupID,
            fromMember: fromMember,
            toMember: toMember,
            amount: amount,
            currency: currency,
            markedBy: actor,
            note: nil
        )

        switch await rpc.addSettlement(input) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    func confirmSettlement(groupID: UUID, settlementID: UUID) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = localized("Bu gruba erişimin yok · Grup sana ait değil veya çıkarıldın · Grup sahibiyle iletişime geç")
            return false
        }
        switch await rpc.confirmSettlement(settlementId: settlementID, confirmedBy: actor) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    func rejectSettlement(groupID: UUID, settlementID: UUID) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = localized("Bu gruba erişimin yok · Grup sana ait değil veya çıkarıldın · Grup sahibiyle iletişime geç")
            return false
        }
        switch await rpc.rejectSettlement(settlementId: settlementID, confirmedBy: actor) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = userErrorMessage(error)
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

    private static func recurringRuleSplitInputs(
        _ splits: [UUID: Int],
        currency: String
    ) -> [RecurringSplitRPCEntry] {
        splits.map {
            RecurringSplitRPCEntry(
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
        switch await rpc.addGhostMember(
            groupId: groupID,
            displayName: displayName
        ) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    func createInvite(groupID: UUID) async -> String? {
        switch await rpc.createInvite(groupId: groupID) {
        case .success(let token):
            return token
        case .failure(let error):
            errorMessage = userErrorMessage(error)
            return nil
        }
    }

    func deleteGroup(_ id: UUID) async -> Bool {
        switch await rpc.deleteGroup(groupId: id) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    func removeMember(groupID: UUID, memberID: UUID) async -> Bool {
        switch await rpc.removeMember(groupId: groupID, memberId: memberID) {
        case .success:
            await load()
            return true
        case .failure(let error):
            errorMessage = userErrorMessage(error)
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
            errorMessage = userErrorMessage(error)
            return false
        }
    }

    func previewInvite(code: String) async -> InvitePreview? {
        switch await rpc.previewInvite(token: code) {
        case .success(let preview) where preview.error == nil:
            return preview
        case .success:
            errorMessage = localized("Bu davet kodu çalışmıyor · Kod geçersiz veya süresi dolmuş olabilir · Yeni bir davet kodu iste veya kodu tekrar kontrol et")
            return nil
        case .failure(let error):
            errorMessage = userErrorMessage(error)
            return nil
        }
    }

    func previewGhosts(code: String) async -> [Member] {
        switch await rpc.previewGhosts(token: code) {
        case .success(let members):
            return members
        case .failure(let error):
            errorMessage = userErrorMessage(error)
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
                errorMessage = joinErrorMessage(response.error)
                return false
            }

            await load()
            return true
        } catch {
            errorMessage = joinErrorMessage(error.localizedDescription)
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func localized(_ key: String.LocalizationValue) -> String {
        String(
            localized: key,
            locale: LocalizationStore.currentLocale()
        )
    }

    /// Kullanıcıya gösterilecek [ne oldu]·[neden]·[ne yapmalı] formatlı hata mesajı.
    /// Ham `error.localizedDescription` ASLA doğrudan gösterilmez.
    private func userErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain || nsError.domain == "NSURLErrorDomain" {
            return localized("İşlem tamamlanamadı · İnternet bağlantını kontrol et · Tekrar dene")
        }
        return localized("İşlem tamamlanamadı · Beklenmeyen bir hata oluştu · Tekrar dene")
    }

    private func joinErrorMessage(_ message: String?) -> String {
        let fallback = localized("Gruba katılamadın · Beklenmeyen bir hata oluştu · Tekrar dene veya yeni davet kodu iste")
        guard let message else { return fallback }
        if message.localizedCaseInsensitiveContains("removed")
            || message.localizedCaseInsensitiveContains("cannot rejoin") {
            return localized("Bu gruptan çıkarıldığın için davet koduyla tekrar katılamazsın.")
        }
        return message
    }

    private static func isLimitError(_ error: RPCError) -> Bool {
        let text = error.localizedDescription.lowercased()
        return text.contains("10 grup")
            || text.contains("ücretsiz plan")
            || text.contains("free plan")
    }

    // MARK: - Recurring Expense Rules

    func recurringRules(for groupID: UUID) -> [RecurringExpenseRule] {
        recurringRules[groupID] ?? []
    }

    func loadRecurringRules(for groupID: UUID) async {
        do {
            let rules: [RecurringExpenseRule] = try await supabase
                .from("recurring_expenses_rules")
                .select()
                .eq("group_id", value: groupID)
                .order("created_at", ascending: false)
                .execute()
                .value
            recurringRules[groupID] = rules
        } catch {
            // En iyi çaba — hata olursa mevcut veriyi koru.
            errorMessage = error.localizedDescription
        }
    }

    func createRecurringRule(
        groupID: UUID,
        description: String,
        note: String?,
        amount: Int,
        currency: String,
        category: String,
        splitType: SplitType,
        paidBy: UUID,
        frequency: RecurringFrequency,
        startDate: Date,
        splits: [UUID: Int]
    ) async -> Bool {
        let input = CreateRecurringRuleRPCInput(
            groupId: groupID,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note?.isEmpty == true ? nil : note,
            amount: amount,
            currency: currency,
            category: category,
            splitType: splitType,
            paidBy: paidBy,
            frequency: frequency,
            startDate: Self.dateString(startDate),
            splits: Self.recurringRuleSplitInputs(splits, currency: currency)
        )

        switch await rpc.createRecurringRule(input) {
        case .success:
            await loadRecurringRules(for: groupID)
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateRecurringRule(
        ruleID: UUID,
        groupID: UUID,
        description: String,
        note: String?,
        amount: Int,
        currency: String,
        category: String,
        splitType: SplitType,
        paidBy: UUID,
        frequency: RecurringFrequency,
        isActive: Bool,
        splits: [UUID: Int]
    ) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = localized("Üyelik bilgisi bulunamadı.")
            return false
        }
        let input = UpdateRecurringRuleRPCInput(
            ruleId: ruleID,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note?.isEmpty == true ? nil : note,
            amount: amount,
            currency: currency,
            category: category,
            splitType: splitType,
            paidBy: paidBy,
            actorMemberId: actor,
            frequency: frequency,
            isActive: isActive,
            splits: Self.recurringRuleSplitInputs(splits, currency: currency)
        )

        switch await rpc.updateRecurringRule(input) {
        case .success:
            await loadRecurringRules(for: groupID)
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    func pauseRecurringRule(
        ruleID: UUID,
        groupID: UUID,
        isActive: Bool
    ) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = localized("Üyelik bilgisi bulunamadı.")
            return false
        }

        switch await rpc.pauseRecurringRule(
            ruleId: ruleID,
            actorMemberId: actor,
            isActive: isActive
        ) {
        case .success:
            await loadRecurringRules(for: groupID)
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteRecurringRule(
        ruleID: UUID,
        groupID: UUID
    ) async -> Bool {
        guard let actor = currentMemberID(in: groupID) else {
            errorMessage = localized("Üyelik bilgisi bulunamadı.")
            return false
        }

        switch await rpc.deleteRecurringRule(
            ruleId: ruleID,
            actorMemberId: actor
        ) {
        case .success:
            await loadRecurringRules(for: groupID)
            return true
        case .failure(let error):
            errorMessage = error.localizedDescription
            return false
        }
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
