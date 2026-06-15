import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Color.primaryTheme)

                Text("Groopay User Pro")
                    .font(.display(26, weight: .extraBold))

                Text("Sınırsız grup oluşturmak ve Pro özelliklerini kullanmak için Apple ile giriş yapıp Pro'ya geç.")
                    .font(.body(15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text("Satın alma akışı sonraki fazda bağlanacak.")
                    .font(.body(13, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PaywallView()
}
