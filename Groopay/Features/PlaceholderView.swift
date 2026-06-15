import SwiftUI

struct PlaceholderView: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.primaryTheme)

                Text("placeholder.comingSoon")
                    .font(.body(16, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        PlaceholderView(
            title: "Önizleme",
            systemImage: "sparkles"
        )
    }
}
