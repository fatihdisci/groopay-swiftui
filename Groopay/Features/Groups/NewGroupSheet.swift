import SwiftUI

struct NewGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore
    let store: GroupsStore

    @State private var name = ""
    @State private var isCreating = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Hero kartı
            hero

            // İsim girişi
            VStack(alignment: .trailing, spacing: 6) {
                TextField("Grup adı", text: $name)
                    .font(.body(17, weight: .semibold))
                    .padding(16)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
                    .focused($isFocused)
                    .onChange(of: name) { _, value in
                        if value.count > 30 {
                            name = String(value.prefix(30))
                        }
                    }

                Text("\(name.count)/30")
                    .font(.body(11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.trailing, 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Buton
            Button {
                Task { await create() }
            } label: {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            LinearGradient(
                                colors: [.gradientStart, .gradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
                } else {
                    Label("Grubu Oluştur", systemImage: "plus")
                        .font(.body(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            LinearGradient(
                                colors: trimmedName.isEmpty
                                    ? [.textTertiary, .textTertiary]
                                    : [.gradientStart, .gradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
                }
            }
            .disabled(trimmedName.isEmpty || isCreating)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()
        }
        .background(Color.background)
        .task {
            isFocused = true
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 34))
            Text("Yeni Grup Oluştur")
                .font(.display(22, weight: .extraBold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            LinearGradient(
                colors: [.gradientStart, .gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func create() async {
        guard !trimmedName.isEmpty else { return }
        isCreating = true
        let success = await store.createGroup(
            name: trimmedName,
            displayName: authStore.currentProfile?.displayName ?? "Kullanıcı"
        )
        isCreating = false
        if success {
            dismiss()
        }
    }
}

#Preview {
    NewGroupSheet(store: PreviewSupport.groupsStore)
        .environment(PreviewSupport.authStore)
}
