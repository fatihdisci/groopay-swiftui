import SwiftUI

struct PaymentSheetConfig: Identifiable {
    let id = UUID()
    let debtAmount: Int
    let currency: String
    let debtorName: String
    let groupID: UUID
    let fromMember: UUID
    let toMember: UUID
}

struct PaymentSheet: View {
    let config: PaymentSheetConfig
    let onPay: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var amountText: String
    @State private var showError = false
    @FocusState private var isFocused: Bool

    private var parsedAmount: Int {
        Int(amountText.filter(\.isNumber)) ?? 0
    }

    private var isValid: Bool {
        parsedAmount > 0 && parsedAmount <= config.debtAmount
    }

    init(config: PaymentSheetConfig, onPay: @escaping (Int) -> Void) {
        self.config = config
        self.onPay = onPay
        _amountText = State(initialValue: String(config.debtAmount))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.textTertiary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Title
                Text("Ne kadar ödedin?")
                    .font(.display(20, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.bottom, 6)

                Text("\(config.debtorName) kişisine")
                    .font(.body(14))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.bottom, 28)

                // Amount input
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        TextField("0", text: $amountText)
                            .font(.display(38, weight: .extraBold))
                            .foregroundStyle(Color.textPrimary)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .focused($isFocused)
                            .onChange(of: amountText) { _, newValue in
                                // Sadece rakam karakterleri
                                let filtered = newValue.filter(\.isNumber)
                                if filtered != newValue {
                                    amountText = filtered
                                }
                                showError = false
                            }

                        Text(config.currency.currencySymbol)
                            .font(.display(20, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }

                    // Borç bilgisi
                    Text("Toplam borç: \(formatAmount(config.debtAmount, currency: config.currency))")
                        .font(.body(13))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background(Color.surfaceTinted)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Error message
                if showError {
                    Text(errorMessage)
                        .font(.body(13, weight: .medium))
                        .foregroundStyle(Color.debt)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                // Pay button
                Button {
                    if isValid {
                        onPay(parsedAmount)
                        dismiss()
                    } else {
                        withAnimation { showError = true }
                    }
                } label: {
                    Text("Ödeme Bildir")
                        .font(.body(16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            LinearGradient(
                                colors: isValid
                                    ? [.gradientStart, .gradientEnd]
                                    : [Color.textTertiary, Color.textTertiary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isValid && showError)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .background(Color.background)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isFocused = true
                }
            }
        }
    }

    private var errorMessage: String {
        if parsedAmount <= 0 {
            return String(
                localized: "Lütfen geçerli bir tutar girin.",
                locale: locale
            )
        }
        if parsedAmount > config.debtAmount {
            return String(
                format: String(
                    localized: "Ödeme tutarı borçtan (%@) fazla olamaz.",
                    locale: locale
                ),
                locale: locale,
                formatAmount(
                    config.debtAmount,
                    currency: config.currency,
                    locale: locale
                )
            )
        }
        return ""
    }
}

private extension String {
    var currencySymbol: String {
        switch uppercased() {
        case "TRY": "₺"
        case "USD": "$"
        case "EUR": "€"
        case "GBP": "£"
        default: self
        }
    }
}

#Preview {
    PaymentSheet(
        config: PaymentSheetConfig(
            debtAmount: 50000,
            currency: "TRY",
            debtorName: "Ahmet",
            groupID: UUID(),
            fromMember: UUID(),
            toMember: UUID()
        ),
        onPay: { _ in }
    )
    .environment(PreviewSupport.authStore)
}
