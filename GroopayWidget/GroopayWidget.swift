import SwiftUI
import WidgetKit

private struct WidgetAmounts: Codable {
    let receivable: Int
    let debt: Int
}

private struct WidgetBalanceSummary: Codable {
    let byCurrency: [String: WidgetAmounts]
    let updatedAt: Date

    static let empty = WidgetBalanceSummary(byCurrency: [:], updatedAt: .distantPast)
}

private struct BalanceEntry: TimelineEntry {
    let date: Date
    let summary: WidgetBalanceSummary
}

private struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(
            date: Date(),
            summary: WidgetBalanceSummary(
                byCurrency: ["TRY": WidgetAmounts(receivable: 12_450_00, debt: 3_200_00)],
                updatedAt: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        completion(BalanceEntry(date: Date(), summary: loadSummary()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        let entry = BalanceEntry(date: Date(), summary: loadSummary())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadSummary() -> WidgetBalanceSummary {
        guard let defaults = UserDefaults(suiteName: "group.com.groopay.app"),
              let data = defaults.data(forKey: "groopay.balance-summary"),
              let summary = try? JSONDecoder().decode(WidgetBalanceSummary.self, from: data) else {
            return .empty
        }
        return summary
    }
}

private struct GroopayBalanceWidgetView: View {
    let entry: BalanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Genel Durum", systemImage: "chart.bar.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x4F46E5))
                Spacer()
                Text("Groopay")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x6B7280))
            }

            if entry.summary.byCurrency.isEmpty {
                Spacer()
                Text("Henüz borç veya alacak yok")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0x6B7280))
                Spacer()
            } else {
                HStack(spacing: 12) {
                    metric(
                        title: "Toplam Alacak",
                        icon: "arrow.down.left",
                        color: Color(hex: 0x10B981),
                        keyPath: \.receivable
                    )
                    metric(
                        title: "Toplam Borç",
                        icon: "arrow.up.right",
                        color: Color(hex: 0xF43F5E),
                        keyPath: \.debt
                    )
                }
            }
        }
        .containerBackground(.white, for: .widget)
    }

    private func metric(
        title: String,
        icon: String,
        color: Color,
        keyPath: KeyPath<WidgetAmounts, Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            ForEach(entry.summary.byCurrency.keys.sorted(), id: \.self) { currency in
                let amount = entry.summary.byCurrency[currency]?[keyPath: keyPath] ?? 0
                Text(format(amount, currency: currency))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x0D0D14))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func format(_ minor: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "tr_TR")
        let amount = Decimal(minor) / Decimal(100)
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "\(minor) \(currency)"
    }
}

struct GroopayBalanceWidget: Widget {
    let kind = "GroopayBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BalanceProvider()) { entry in
            GroopayBalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Genel Durum")
        .description("Toplam alacak ve borçlarını hızlıca gör.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct GroopayWidgetBundle: WidgetBundle {
    var body: some Widget {
        GroopayBalanceWidget()
    }
}

private extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
