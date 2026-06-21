import Foundation

/// Bir grup kartında kullanıcının durumunu özetleyen saf (test edilebilir)
/// sunum modeli. Para birimleri ASLA toplanmaz/çevrilmez; her para birimi ayrı
/// satır olarak taşınır. Renk tek başına anlam taşımaz — `kind` kelimesi ve
/// SF Symbol birlikte kullanılır.
enum GroupCardStatus: Equatable, Sendable {
    case settled
    case lines([GroupBalanceLine])

    /// Snapshot ve kullanıcı için kart durumunu üretir. Kullanıcı grupta aktif
    /// üye değilse de geçmiş kayıtlarla (ledger) borç/alacağı görünür.
    static func make(snapshot: GroupSnapshot, userID: UUID?) -> GroupCardStatus {
        guard let userID,
              let member = memberID(in: snapshot, userID: userID) else {
            return .settled
        }

        let balance = computeBalance(
            expenses: snapshot.expenses,
            splits: snapshot.splits,
            settlements: snapshot.settlements,
            for: member
        )

        let lines: [GroupBalanceLine] = balance
            .compactMap { currency, amount in
                guard amount != 0 else { return nil }
                return GroupBalanceLine(
                    currency: currency.uppercased(),
                    amount: abs(amount),
                    kind: amount < 0 ? .debt : .credit
                )
            }
            // Önce borçlar, sonra alacaklar; her grup içinde büyük tutar üstte.
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind { return lhs.kind == .debt }
                if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
                return lhs.currency < rhs.currency
            }

        return lines.isEmpty ? .settled : .lines(lines)
    }

    /// Aktif üye yoksa pasif (çıkarılmış) üye kaydı üzerinden geçmiş bakiyeyi de
    /// bulmaya çalışır; böylece ledger borç/alacağı kartta kaybolmaz.
    private static func memberID(in snapshot: GroupSnapshot, userID: UUID) -> UUID? {
        if let active = snapshot.members.first(where: { $0.userId == userID && $0.isActive }) {
            return active.id
        }
        return snapshot.members.first { $0.userId == userID }?.id
    }
}

struct GroupBalanceLine: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case debt
        case credit
    }

    let currency: String
    /// Her zaman pozitif (mutlak) tutar; yön `kind` ile taşınır. İşaret yok.
    let amount: Int
    let kind: Kind

    var id: String { "\(currency)-\(kind == .debt ? "d" : "c")" }
}
