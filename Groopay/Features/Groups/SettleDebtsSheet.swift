import SwiftUI

/// Kullanıcının yalnızca KENDİ borçlarını tek yerde, scroll/arama gerektirmeden
/// gösteren odaklı ödeme ekranı. Her satırda "Ödedim" (PaymentSheet) ve
/// "IBAN İste" (WhatsApp) aksiyonları bulunur. PaymentSheet ve IBAN akışları bu
/// görünümün kendi state'iyle yönetilir; böylece üst ekranla iç içe sheet
/// çakışması olmaz.
struct SettleDebtsSheet: View {
    let store: GroupsStore
    let groupID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.appFeedback) private var feedback
    @State private var paymentSheet: PaymentSheetConfig?
    @State private var busy = false

    private var snapshot: GroupSnapshot? { store.snapshot(groupID) }
    private var currentMemberID: UUID? { store.currentMemberID(in: groupID) }

    /// Sadeleştirilmiş borçlardan yalnızca kullanıcının ödeyeceği olanlar,
    /// büyükten küçüğe sıralı.
    private var myDebts: [Transfer] {
        guard let snapshot, let me = currentMemberID else { return [] }
        return simplifyDebts(balances: snapshot.ledgerBalances())
            .filter { $0.fromMemberId == me }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let snapshot, !myDebts.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(Array(myDebts.enumerated()), id: \.offset) { _, transfer in
                            debtRow(transfer, snapshot: snapshot)
                        }
                    }
                    .padding(20)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.background)
            .navigationTitle("Borçların")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundStyle(Color.primaryTheme)
                }
            }
        }
        .sheet(item: $paymentSheet) { config in
            PaymentSheet(config: config) { amount in
                runAction(
                    successMessage: String(localized: "Ödeme onaya gönderildi.", locale: locale)
                ) {
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
    }

    // MARK: - Row

    @ViewBuilder
    private func debtRow(_ transfer: Transfer, snapshot: GroupSnapshot) -> some View {
        let creditor = snapshot.member(id: transfer.toMemberId)
        let creditorName = creditor?.displayName ?? "?"
        let creditorActive = creditor?.isActive == true
        let pending = snapshot.pendingSettlement(
            from: transfer.fromMemberId,
            to: transfer.toMemberId,
            currency: transfer.currency
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                GradientAvatar(
                    name: creditorName,
                    color: creditor?.avatarColor,
                    size: 42
                )
                Text(creditorName)
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(formatAmount(transfer.amount, currency: transfer.currency))
                    .font(.display(18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }

            if let pending {
                HStack(spacing: 8) {
                    Label(
                        "\(formatAmount(pending.amount, currency: pending.currency)) onay bekliyor",
                        systemImage: "clock.fill"
                    )
                        .font(.body(12, weight: .semibold))
                        .foregroundStyle(Color.warning)
                    Spacer()
                    Button {
                        runAction(
                            successMessage: String(localized: "Ödeme isteği iptal edildi.", locale: locale)
                        ) {
                            await store.rejectSettlement(
                                groupID: groupID,
                                settlementID: pending.id
                            )
                        }
                    } label: {
                        Text("İptal")
                            .font(.body(13, weight: .semibold))
                            .foregroundStyle(Color.debt)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.warning.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if creditorActive {
                HStack(spacing: 10) {
                    Button {
                        paymentSheet = PaymentSheetConfig(
                            debtAmount: transfer.amount,
                            currency: transfer.currency,
                            debtorName: creditorName,
                            groupID: groupID,
                            fromMember: transfer.fromMemberId,
                            toMember: transfer.toMemberId
                        )
                    } label: {
                        Label("Ödedim", systemImage: "checkmark")
                            .font(.body(14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(
                                LinearGradient(
                                    colors: [.gradientStart, .gradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        sendIBANRequestViaWhatsApp(
                            creditor: creditorName,
                            amount: transfer.amount,
                            currency: transfer.currency,
                            groupName: snapshot.group.name,
                            locale: locale,
                            onClipboardFallback: {
                                feedback.info(
                                    String(
                                        localized: "IBAN isteme mesajı panoya kopyalandı; dilediğin uygulamada yapıştırabilirsin.",
                                        locale: locale
                                    )
                                )
                            }
                        )
                    } label: {
                        Label("IBAN İste", systemImage: "creditcard.fill")
                            .font(.body(14, weight: .semibold))
                            .foregroundStyle(Color.primaryTheme)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Color.primaryTheme.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                Text("Eski üye — ödeşme yapılamaz")
                    .font(.body(12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .disabled(busy)
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .purpleTintedShadow()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(Color.credit)
            Text("Bu grupta borcun yok")
                .font(.body(15, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func runAction(
        successMessage: String? = nil,
        _ operation: @escaping () async -> Bool
    ) {
        guard !busy else { return }
        busy = true
        Task {
            let success = await operation()
            busy = false
            if success {
                if let successMessage { feedback.success(successMessage) }
            } else {
                feedback.error(
                    store.errorMessage
                        ?? String(localized: "İşlem başarısız", locale: locale)
                )
                store.clearError()
            }
        }
    }
}
