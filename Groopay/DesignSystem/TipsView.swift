import SwiftUI

// MARK: - Tips Content

private struct TipItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
}

private let tipsTR: [TipItem] = [
    TipItem(
        id: "groups",
        icon: "person.2.fill",
        title: "Grup Yönetimi",
        description: "Grup oluşturun, arkadaşlarınızı davet edin ve ortak masrafları takip edin. Hayalet üye ekleyerek henüz uygulamada olmayan kişileri de gruba dahil edebilirsiniz."
    ),
    TipItem(
        id: "expenses",
        icon: "plus.circle.fill",
        title: "Masraf Ekleme",
        description: "Masraf eklerken ödeyen kişiyi ve bölüşme şeklini seçin. Eşit, özel miktar veya belirli kişiler arasında bölüşme seçenekleri mevcut."
    ),
    TipItem(
        id: "settlements",
        icon: "checkmark.circle.fill",
        title: "Ödeme Bildirimi",
        description: "Borçlu olduğunuz kişiye ödeme yaptığınızda 'Ödedim' butonuna basın. Karşı taraf onaylayınca borcunuz düşer."
    ),
    TipItem(
        id: "dashboard",
        icon: "chart.bar.fill",
        title: "Panel",
        description: "Tüm gruplarınızın para birimi bazında özetini, harcama trendlerini ve kategorilerini tek ekranda görün. (Pro özelliği)"
    ),
    TipItem(
        id: "pro",
        icon: "diamond.fill",
        title: "Pro Abonelik",
        description: "Sınırsız grup oluşturma, gelişmiş panel ve kategori analizi gibi özelliklere erişmek için Groopay User Pro'ya abone olun."
    ),
    TipItem(
        id: "invite",
        icon: "link",
        title: "Davet Linki",
        description: "Grup detay sayfasından 'Davet Linki' oluşturarak arkadaşlarınızı gruba davet edebilirsiniz. Kod 7 gün geçerlidir."
    ),
]

private let tipsEN: [TipItem] = [
    TipItem(
        id: "groups",
        icon: "person.2.fill",
        title: "Group Management",
        description: "Create groups, invite friends, and track shared expenses. Add ghost members to include people who aren't on the app yet."
    ),
    TipItem(
        id: "expenses",
        icon: "plus.circle.fill",
        title: "Adding Expenses",
        description: "When adding an expense, select who paid and how to split. Options include equal split, custom amounts, or split among selected members."
    ),
    TipItem(
        id: "settlements",
        icon: "checkmark.circle.fill",
        title: "Payment Confirmation",
        description: "When you pay someone you owe, tap 'Mark as Paid'. Once the other party confirms, your debt is settled."
    ),
    TipItem(
        id: "dashboard",
        icon: "chart.bar.fill",
        title: "Dashboard",
        description: "View summaries of all your groups by currency, spending trends, and categories on a single screen. (Pro feature)"
    ),
    TipItem(
        id: "pro",
        icon: "diamond.fill",
        title: "Pro Subscription",
        description: "Subscribe to Groopay User Pro for unlimited groups, advanced dashboard, and category analytics."
    ),
    TipItem(
        id: "invite",
        icon: "link",
        title: "Invite Link",
        description: "Generate an invite link from the group detail page to invite friends. The code is valid for 7 days."
    ),
]

// MARK: - TipsView

struct TipsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var isTurkish: Bool {
        locale.language.languageCode?.identifier == "tr"
    }

    private var tips: [TipItem] {
        isTurkish ? tipsTR : tipsEN
    }

    var body: some View {
        NavigationStack {
            List(tips) { tip in
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.primaryTheme.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: tip.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.primaryTheme)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tip.title)
                            .font(.body(14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text(tip.description)
                            .font(.body(12))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 6)
            }
            .listStyle(.plain)
            .navigationTitle(isTurkish ? "İpuçları" : "Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isTurkish ? "Kapat" : "Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Tips Button Modifier

struct TipsButtonModifier: ViewModifier {
    @State private var showTips = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showTips = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showTips) {
                TipsView()
            }
    }
}

extension View {
    func tipsButton() -> some View {
        modifier(TipsButtonModifier())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        Text("Ana Sayfa")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.background)
            .tipsButton()
    }
}
