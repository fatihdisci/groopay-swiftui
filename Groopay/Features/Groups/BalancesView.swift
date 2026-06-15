import SwiftUI

struct BalancesTabView: View {
    let snapshot: GroupSnapshot
    let currentMemberID: UUID?

    @State private var mode: BalanceMode = .raw
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var balances: [UUID: [String: Int]] {
        snapshot.memberBalances()
    }

    var body: some View {
        VStack(spacing: 16) {
            selfSummaryCard
            modePicker
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .animation(reduceMotion ? nil : .default, value: mode)
    }

    // MARK: - Self summary

    private var selfBalance: [String: Int] {
        guard let currentMemberID else { return [:] }
        return balances[currentMemberID] ?? [:]
    }

    private var selfSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SENİN DURUMUN")
                .font(.body(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.75))

            if selfBalance.isEmpty {
                Text("Ödeştin")
                    .font(.display(30, weight: .extraBold))
                    .foregroundStyle(.white)
            } else {
                let currencies = selfBalance.keys.sorted()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(currencies.enumerated()), id: \.element) { index, currency in
                        let amount = selfBalance[currency, default: 0]
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(formatAmount(abs(amount), currency: currency))
                                .font(.display(index == 0 ? 34 : 20, weight: .extraBold))
                                .foregroundStyle(.white)
                            Text(amount >= 0 ? "alacaklısın" : "borçlusun")
                                .font(.body(13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [.gradientStart, .gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .purpleTintedShadow(radius: 18, y: 9)
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(BalanceMode.allCases) { item in
                let selected = item == mode
                Button {
                    mode = item
                } label: {
                    Text(item.title)
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(selected ? .white : Color.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(selected ? Color.primaryTheme : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.surface)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .raw:
            rawList
        case .simplified:
            simplifiedList
        }
    }

    // MARK: - Raw list

    private var rawList: some View {
        VStack(spacing: 0) {
            ForEach(snapshot.activeMembers) { member in
                rawRow(member: member, balance: balances[member.id] ?? [:])
                if member.id != snapshot.activeMembers.last?.id {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .padding(.vertical, 6)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow()
    }

    private func rawRow(member: Member, balance: [String: Int]) -> some View {
        HStack(spacing: 12) {
            GradientAvatar(
                name: member.displayName,
                color: member.avatarColor,
                size: 38
            )
            Text(member.displayName)
                .font(.body(15, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()

            if balance.isEmpty {
                Text("ödeşti")
                    .font(.body(13, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(balance.keys.sorted(), id: \.self) { currency in
                        let amount = balance[currency, default: 0]
                        HStack(spacing: 6) {
                            Text(formatAmount(abs(amount), currency: currency))
                                .font(.body(15, weight: .semibold))
                                .foregroundStyle(amount >= 0 ? Color.credit : Color.debt)
                            Text(amount >= 0 ? "alacaklı" : "borçlu")
                                .font(.body(11, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Simplified list

    private var transfers: [Transfer] {
        simplifyDebts(balances: balances)
    }

    @ViewBuilder
    private var simplifiedList: some View {
        if transfers.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.credit)
                Text("Herkes ödeşti")
                    .font(.body(15, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(transfers.enumerated()), id: \.offset) { index, transfer in
                    transferRow(transfer)
                    if index != transfers.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 6)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
            .purpleTintedShadow()
        }
    }

    private func transferRow(_ transfer: Transfer) -> some View {
        let debtor = snapshot.member(id: transfer.fromMemberId)?.displayName ?? "?"
        let creditor = snapshot.member(id: transfer.toMemberId)?.displayName ?? "?"
        return HStack(spacing: 10) {
            Text(debtor)
                .font(.body(14, weight: .semibold))
                .foregroundStyle(Color.debt)
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.textTertiary)
            Text(creditor)
                .font(.body(14, weight: .semibold))
                .foregroundStyle(Color.credit)
                .lineLimit(1)
            Spacer()
            Text(formatAmount(transfer.amount, currency: transfer.currency))
                .font(.display(15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

enum BalanceMode: String, CaseIterable, Identifiable {
    case raw
    case simplified

    var id: String { rawValue }
    var title: String {
        switch self {
        case .raw: "Ham liste"
        case .simplified: "Sadeleştirilmiş"
        }
    }
}

#Preview {
    ScrollView {
        BalancesTabView(
            snapshot: PreviewSupport.snapshot,
            currentMemberID: PreviewSupport.founderID
        )
    }
    .background(Color.background)
}
