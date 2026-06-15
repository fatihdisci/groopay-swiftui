import SwiftUI

struct OnboardingFlow: View {
    @Environment(AuthStore.self) private var authStore
    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false
    @State private var selection = 0

    private let pages = [
        OnboardingPage(
            title: "onboarding.groups.title",
            message: "onboarding.groups.message",
            systemImage: "person.2.fill"
        ),
        OnboardingPage(
            title: "onboarding.expenses.title",
            message: "onboarding.expenses.message",
            systemImage: "chart.pie.fill"
        ),
        OnboardingPage(
            title: "onboarding.settle.title",
            message: "onboarding.settle.message",
            systemImage: "checkmark.circle.fill"
        ),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.gradientStart, .gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Spacer()

                    Button("onboarding.skip") {
                        finish()
                    }
                    .font(.body(15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(minWidth: 44, minHeight: 44)
                }

                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) {
                        index,
                        page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if selection == pages.count - 1 {
                        finish()
                    } else {
                        withAnimation {
                            selection += 1
                        }
                    }
                } label: {
                    Text(
                        selection == pages.count - 1
                            ? "onboarding.start"
                            : "onboarding.next"
                    )
                    .font(.body(17, weight: .semibold))
                    .foregroundStyle(Color.primaryTheme)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.white)
                    .clipShape(
                        RoundedRectangle(cornerRadius: ThemeRadius.button)
                    )
                }
                .disabled(authStore.isLoading)
            }
            .padding(24)

            if authStore.isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private func finish() {
        Task {
            await authStore.signInAnonymously()
            if authStore.sessionState != .signedOut {
                hasCompletedOnboarding = true
            }
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.systemImage)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 148, height: 148)
                .background(.white.opacity(0.14))
                .clipShape(Circle())

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.display(32, weight: .extraBold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.message)
                    .font(.body(17))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

private struct OnboardingPage {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
}

#Preview {
    OnboardingFlow()
        .environment(PreviewSupport.authStore)
}
