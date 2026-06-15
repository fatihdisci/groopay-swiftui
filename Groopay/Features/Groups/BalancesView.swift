import SwiftUI
import UIKit

struct BalancesTabView: View {
    let store: GroupsStore
    let groupID: UUID

    @State private var mode: BalanceMode = .raw
    @State private var ibanCopied = false
    @State private var busy = false
    @State private var paymentSheet: PaymentSheetConfig?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    private var snapshot: GroupSnapshot? { store.snapshot(groupID) }
    private var currentMemberID: UUID? { store.currentMemberID(in: groupID) }

    private var balances: [UUID: [String: Int]] {
        snapshot?.memberBalances() ?? [:]
    }

    var body: some View {
        if let snapshot {
            VStack(spacing: 16) {
                selfSummaryCard
                approvalSection(snapshot)
                modePicker
                content(snapshot)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .animation(reduceMotion ? nil : .default, value: mode)
            .sheet(item: $paymentSheet) { config in
                PaymentSheet(config: config) { amount in
                    runSettlementAction {
                        await store.markPaid(
                            groupID: config.groupID,
                            fromMember: config.fromMember,
                            toMember: config.toMember,
                            amount: amount,
                            currency: config.currency
                        )
                    }
                }
            }
            .alert("WhatsApp açılamadı", isPresented: $ibanCopied) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text("IBAN isteme mesajı panoya kopyalandı; dilediğin uygulamada yapıştırabilirsin.")
            }
        }
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

    // MARK: - Approval section (current user is recipient)

    @ViewBuilder
    private func approvalSection(_ snapshot: GroupSnapshot) -> some View {
        if let currentMemberID {
            let pending = snapshot.pendingSettlements(forRecipient: currentMemberID)
            if !pending.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ONAYINI BEKLEYEN ÖDEMELER")
                        .font(.body(11, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(Color.textSecondary)
                    VStack(spacing: 0) {
                        ForEach(pending) { settlement in
                            approvalRow(settlement, snapshot: snapshot)
                            if settlement.id != pending.last?.id {
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
        }
    }

    private func approvalRow(_ settlement: Settlement, snapshot: GroupSnapshot) -> some View {
        let payer = snapshot.member(id: settlement.fromMember)?.displayName ?? "Birisi"
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(payer) ödedi diyor")
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(formatAmount(settlement.amount, currency: settlement.currency))
                    .font(.body(13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Button {
                runSettlementAction { await store.rejectSettlement(groupID: groupID, settlementID: settlement.id) }
            } label: {
                Text("Reddet")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Color.debt)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.debt.opacity(0.1))
                    .clipShape(Capsule())
            }
            Button {
                runSettlementAction { await store.confirmSettlement(groupID: groupID, settlementID: settlement.id) }
            } label: {
                Text("Onayla")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.credit)
                    .clipShape(Capsule())
            }
        }
        .disabled(busy)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
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
    private func content(_ snapshot: GroupSnapshot) -> some View {
        switch mode {
        case .raw:
            rawList(snapshot)
        case .simplified:
            simplifiedList(snapshot)
        }
    }

    // MARK: - Raw list

    private func rawList(_ snapshot: GroupSnapshot) -> some View {
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

    @ViewBuilder
    private func simplifiedList(_ snapshot: GroupSnapshot) -> some View {
        let transfers = simplifyDebts(balances: balances)
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
                    transferRow(transfer, snapshot: snapshot)
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

    private func transferRow(_ transfer: Transfer, snapshot: GroupSnapshot) -> some View {
        let debtor = snapshot.member(id: transfer.fromMemberId)?.displayName ?? "?"
        let creditor = snapshot.member(id: transfer.toMemberId)?.displayName ?? "?"
        let isMyDebt = currentMemberID == transfer.fromMemberId
        let pending = snapshot.pendingSettlement(
            from: transfer.fromMemberId,
            to: transfer.toMemberId,
            currency: transfer.currency
        )

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
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

            if isMyDebt {
                if let pending = pending {
                    HStack(spacing: 8) {
                        Spacer()
                        Button {
                            runSettlementAction {
                                await store.rejectSettlement(groupID: groupID, settlementID: pending.id)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.textTertiary)
                        }
                        Label(
                            "\(formatAmount(pending.amount, currency: pending.currency)) onay bekliyor",
                            systemImage: "clock.fill"
                        )
                            .font(.body(12, weight: .semibold))
                            .foregroundStyle(Color.warning)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.warning.opacity(0.12))
                            .clipShape(Capsule())
                    }
                } else {
                    HStack(spacing: 12) {
                        Spacer()
                        circleAction(
                            title: "Ödedim",
                            icon: "checkmark",
                            tint: .credit
                        ) {
                            paymentSheet = PaymentSheetConfig(
                                debtAmount: transfer.amount,
                                currency: transfer.currency,
                                debtorName: creditor,
                                groupID: groupID,
                                fromMember: transfer.fromMemberId,
                                toMember: transfer.toMemberId
                            )
                        }
                        circleAction(
                            title: "IBAN İste",
                            icon: "creditcard.fill",
                            tint: Color(cssHex: "#8B5CF6") ?? .gradientEnd
                        ) {
                            sendIBANRequest(
                                creditor: creditor,
                                amount: transfer.amount,
                                currency: transfer.currency,
                                groupName: snapshot.group.name
                            )
                        }
                    }
                }
            }
        }
        .disabled(busy)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private func circleAction(
        title: LocalizedStringResource,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.body(10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - Actions

    private func runSettlementAction(_ operation: @escaping () async -> Bool) {
        busy = true
        Task {
            _ = await operation()
            busy = false
        }
    }

    /// IBAN HİÇBİR yerde saklanmaz. Alacaklıdan IBAN istemek için hazır bir mesajla
    /// doğrudan WhatsApp açılır (kişiyi kullanıcı seçer). WhatsApp uygulaması yoksa
    /// wa.me web bağlantısına, o da açılamazsa panoya kopyalamaya düşer.
    private func sendIBANRequest(
        creditor: String,
        amount: Int,
        currency: String,
        groupName: String
    ) {
        let formatted = formatAmount(amount, currency: currency)
        let message = String(
            format: String(
                localized: "Merhaba %@! \"%@\" grubunda sana %@ ödemem var. Ödemeyi yapabilmem için IBAN'ını paylaşır mısın? Teşekkürler!",
                locale: locale
            ),
            locale: locale,
            creditor,
            groupName,
            formatted
        )
        // Her durumda panoya da koy (en son çare).
        UIPasteboard.general.string = message

        let encoded = message.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""
        let appURL = URL(string: "whatsapp://send?text=\(encoded)")
        let webURL = URL(string: "https://wa.me/?text=\(encoded)")

        if let appURL {
            UIApplication.shared.open(appURL, options: [:]) { opened in
                if !opened {
                    if let webURL {
                        UIApplication.shared.open(webURL, options: [:]) { webOpened in
                            if !webOpened { ibanCopied = true }
                        }
                    } else {
                        ibanCopied = true
                    }
                }
            }
        } else {
            ibanCopied = true
        }
    }
}

enum BalanceMode: String, CaseIterable, Identifiable {
    case raw
    case simplified

    var id: String { rawValue }
    var title: LocalizedStringResource {
        switch self {
        case .raw: "Ham liste"
        case .simplified: "Sadeleştirilmiş"
        }
    }
}

#Preview {
    ScrollView {
        BalancesTabView(
            store: PreviewSupport.groupsStore,
            groupID: PreviewSupport.groupID
        )
    }
    .background(Color.background)
    .environment(PreviewSupport.authStore)
}
