import Foundation
import Supabase

struct ExpenseSplitRPCInput: Encodable, Sendable {
    let memberId: UUID
    let shareAmount: Int
    let currency: String

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case shareAmount = "share_amount"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(
            decimalAmount(fromMinor: shareAmount, currency: currency),
            forKey: .shareAmount
        )
    }
}

struct AddExpenseRPCInput: Encodable, Sendable {
    let groupId: UUID
    let description: String
    let note: String?
    let amount: Int
    let currency: String
    let category: String
    let splitType: SplitType
    let paidBy: UUID
    let createdBy: UUID
    let expenseDate: String
    let splits: [ExpenseSplitRPCInput]

    enum CodingKeys: String, CodingKey {
        case groupId = "p_group_id"
        case description = "p_description"
        case note = "p_note"
        case amount = "p_amount"
        case currency = "p_currency"
        case category = "p_category"
        case splitType = "p_split_type"
        case paidBy = "p_paid_by"
        case createdBy = "p_created_by"
        case expenseDate = "p_expense_date"
        case splits = "p_splits"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(description, forKey: .description)
        // p_note her zaman gönderilir (nil ise null). PostgREST fonksiyonu
        // isimli argüman kümesine göre çözer; alanı atlarsak imza eşleşmez.
        try container.encode(note, forKey: .note)
        try container.encode(
            decimalAmount(fromMinor: amount, currency: currency),
            forKey: .amount
        )
        try container.encode(currency.uppercased(), forKey: .currency)
        try container.encode(category, forKey: .category)
        try container.encode(splitType, forKey: .splitType)
        try container.encode(paidBy, forKey: .paidBy)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(expenseDate, forKey: .expenseDate)
        try container.encode(splits, forKey: .splits)
    }
}

struct UpdateExpenseRPCInput: Encodable, Sendable {
    let expenseId: UUID
    let description: String
    let note: String?
    let amount: Int
    let currency: String
    let category: String
    let splitType: SplitType
    let paidBy: UUID
    let actorMemberId: UUID
    let expenseDate: String
    let splits: [ExpenseSplitRPCInput]

    enum CodingKeys: String, CodingKey {
        case expenseId = "p_expense_id"
        case description = "p_description"
        case note = "p_note"
        case amount = "p_amount"
        case currency = "p_currency"
        case category = "p_category"
        case splitType = "p_split_type"
        case paidBy = "p_paid_by"
        case actorMemberId = "p_actor_member_id"
        case expenseDate = "p_expense_date"
        case splits = "p_splits"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(expenseId, forKey: .expenseId)
        try container.encode(description, forKey: .description)
        // p_note her zaman gönderilir (nil ise null) — bkz. AddExpenseRPCInput.
        try container.encode(note, forKey: .note)
        try container.encode(
            decimalAmount(fromMinor: amount, currency: currency),
            forKey: .amount
        )
        try container.encode(currency.uppercased(), forKey: .currency)
        try container.encode(category, forKey: .category)
        try container.encode(splitType, forKey: .splitType)
        try container.encode(paidBy, forKey: .paidBy)
        try container.encode(actorMemberId, forKey: .actorMemberId)
        try container.encode(expenseDate, forKey: .expenseDate)
        try container.encode(splits, forKey: .splits)
    }
}

struct AddSettlementRPCInput: Encodable, Sendable {
    let groupId: UUID
    let fromMember: UUID
    let toMember: UUID
    let amount: Int
    let currency: String
    let markedBy: UUID
    let note: String?

    enum CodingKeys: String, CodingKey {
        case groupId = "p_group_id"
        case fromMember = "p_from_member"
        case toMember = "p_to_member"
        case amount = "p_amount"
        case currency = "p_currency"
        case markedBy = "p_marked_by"
        case note = "p_note"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(fromMember, forKey: .fromMember)
        try container.encode(toMember, forKey: .toMember)
        try container.encode(
            decimalAmount(fromMinor: amount, currency: currency),
            forKey: .amount
        )
        try container.encode(currency.uppercased(), forKey: .currency)
        try container.encode(markedBy, forKey: .markedBy)
        // p_note her zaman gönderilir (nil ise null) — bkz. AddExpenseRPCInput.
        try container.encode(note, forKey: .note)
    }
}

struct CreateGroupRPCInput: Encodable, Sendable {
    let name: String
    let baseCurrency: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case name = "p_name"
        case baseCurrency = "p_base_currency"
        case displayName = "p_display_name"
    }
}

struct InvitePreview: Codable, Equatable, Sendable {
    let token: String?
    let groupId: UUID?
    let groupName: String?
    let memberCount: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case token
        case groupId = "group_id"
        case groupName = "group_name"
        case memberCount = "member_count"
        case error
    }
}

enum RPCError: LocalizedError, Equatable, Sendable {
    case postgrest(
        code: String?,
        message: String,
        detail: String?,
        hint: String?
    )
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .postgrest(_, let message, _, _):
            return message
        case .transport(let message):
            return message
        }
    }
}

struct RPCClient: Sendable {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient = SupabaseService.shared) {
        self.supabase = supabase
    }

    func addExpenseWithSplits(
        _ input: AddExpenseRPCInput
    ) async -> Result<Void, RPCError> {
        // Dönüş değeri (varsa) kullanılmıyor; void olarak çalıştırıp gövdeyi
        // decode etmiyoruz — fonksiyon void/satır/UUID ne dönerse dönsün güvenli.
        await void("add_expense_with_splits", params: input)
    }

    func updateExpenseWithSplits(
        _ input: UpdateExpenseRPCInput
    ) async -> Result<Void, RPCError> {
        await void("update_expense_with_splits", params: input)
    }

    func deleteExpense(
        expenseId: UUID,
        actorMemberId: UUID
    ) async -> Result<Void, RPCError> {
        await void(
            "delete_expense",
            params: DeleteExpenseParams(
                expenseId: expenseId,
                actorMemberId: actorMemberId
            )
        )
    }

    func addSettlement(
        _ input: AddSettlementRPCInput
    ) async -> Result<Void, RPCError> {
        // Dönüş değeri kullanılmıyor; void çalıştır (bkz. addExpenseWithSplits).
        await void("add_settlement", params: input)
    }

    func confirmSettlement(
        settlementId: UUID,
        confirmedBy: UUID
    ) async -> Result<Void, RPCError> {
        await void(
            "confirm_settlement",
            params: SettlementDecisionParams(
                settlementId: settlementId,
                confirmedBy: confirmedBy
            )
        )
    }

    func rejectSettlement(
        settlementId: UUID,
        confirmedBy: UUID
    ) async -> Result<Void, RPCError> {
        await void(
            "reject_settlement",
            params: SettlementDecisionParams(
                settlementId: settlementId,
                confirmedBy: confirmedBy
            )
        )
    }

    func createGroupWithLimit(
        _ input: CreateGroupRPCInput
    ) async -> Result<UUID, RPCError> {
        await value("create_group_with_limit", params: input)
    }

    func deleteGroup(groupId: UUID) async -> Result<Void, RPCError> {
        await void(
            "delete_group",
            params: GroupIDParams(groupId: groupId)
        )
    }

    func removeMember(
        groupId: UUID,
        memberId: UUID
    ) async -> Result<Void, RPCError> {
        await void(
            "remove_member",
            params: RemoveMemberParams(
                groupId: groupId,
                memberId: memberId
            )
        )
    }

    func transferOwnership(
        groupId: UUID,
        newFounderMemberId: UUID
    ) async -> Result<Void, RPCError> {
        await void(
            "transfer_ownership",
            params: TransferOwnershipParams(
                groupId: groupId,
                newFounderMemberId: newFounderMemberId
            )
        )
    }

    func previewInvite(
        token: String
    ) async -> Result<InvitePreview, RPCError> {
        await value(
            "preview_invite",
            params: TokenParams(token: token.uppercased())
        )
    }

    func previewGhosts(
        token: String
    ) async -> Result<[Member], RPCError> {
        await value(
            "preview_ghosts",
            params: TokenParams(token: token.uppercased())
        )
    }

    func createInvite(
        groupId: UUID,
        expiresInDays: Int = 7
    ) async -> Result<String, RPCError> {
        await value(
            "create_invite",
            params: CreateInviteParams(
                groupId: groupId,
                expiresInDays: expiresInDays
            )
        )
    }

    private func value<Response: Decodable & Sendable>(
        _ function: String,
        params: some Encodable
    ) async -> Result<Response, RPCError> {
        do {
            let response: Response = try await supabase
                .rpc(function, params: params)
                .execute()
                .value
            return .success(response)
        } catch {
            return .failure(Self.map(error))
        }
    }

    private func void(
        _ function: String,
        params: some Encodable
    ) async -> Result<Void, RPCError> {
        do {
            try await supabase
                .rpc(function, params: params)
                .execute()
            return .success(())
        } catch {
            return .failure(Self.map(error))
        }
    }

    private static func map(_ error: any Error) -> RPCError {
        if let error = error as? PostgrestError {
            return .postgrest(
                code: error.code,
                message: error.message,
                detail: error.detail,
                hint: error.hint
            )
        }

        return .transport(error.localizedDescription)
    }
}

private struct DeleteExpenseParams: Encodable {
    let expenseId: UUID
    let actorMemberId: UUID

    enum CodingKeys: String, CodingKey {
        case expenseId = "p_expense_id"
        case actorMemberId = "p_actor_member_id"
    }
}

private struct SettlementDecisionParams: Encodable {
    let settlementId: UUID
    let confirmedBy: UUID

    enum CodingKeys: String, CodingKey {
        case settlementId = "p_settlement_id"
        case confirmedBy = "p_confirmed_by"
    }
}

private struct GroupIDParams: Encodable {
    let groupId: UUID

    enum CodingKeys: String, CodingKey {
        case groupId = "p_group_id"
    }
}

private struct RemoveMemberParams: Encodable {
    let groupId: UUID
    let memberId: UUID

    enum CodingKeys: String, CodingKey {
        case groupId = "p_group_id"
        case memberId = "p_member_id"
    }
}

private struct TransferOwnershipParams: Encodable {
    let groupId: UUID
    let newFounderMemberId: UUID

    enum CodingKeys: String, CodingKey {
        case groupId = "p_group_id"
        case newFounderMemberId = "p_new_founder_member_id"
    }
}

private struct TokenParams: Encodable {
    let token: String

    enum CodingKeys: String, CodingKey {
        case token = "p_token"
    }
}

private struct CreateInviteParams: Encodable {
    let groupId: UUID
    let expiresInDays: Int

    enum CodingKeys: String, CodingKey {
        case groupId = "p_group_id"
        case expiresInDays = "p_expires_in_days"
    }
}
