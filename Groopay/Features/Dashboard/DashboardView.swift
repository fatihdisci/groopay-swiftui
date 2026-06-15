import SwiftUI

struct DashboardView: View {
    var body: some View {
        PlaceholderView(
            title: "tab.dashboard",
            systemImage: "chart.bar.fill"
        )
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
