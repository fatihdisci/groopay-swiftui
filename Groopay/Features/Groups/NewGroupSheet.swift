import SwiftUI

struct NewGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore
    let store: GroupsStore
    @State private var name = ""
    @State private var isCreating = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Yeni Grup")
                .font(.display(24, weight: .extraBold))
                .foregroundStyle(Color.textPrimary)

            VStack(alignment: .trailing, spacing: 7) {
                TextField("Grup adı", text: $name)
                    .font(.body(16))
                    .padding(15)
                    .background(Color.surfaceTinted)
                    .clipShape(
                        RoundedRectangle(cornerRadius: ThemeRadius.button)
                    )
                    .focused($focused)
                    .onChange(of: name) { _, value in
                        if value.count > 30 {
                            name = String(value.prefix(30))
                        }
                    }

                Text("\(name.count)/30")
                    .font(.body(11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }

            Button {
                Task { await create() }
            } label: {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.primaryTheme)
                        .clipShape(
                            RoundedRectangle(cornerRadius: ThemeRadius.button)
                        )
                } else {
                    GradientButtonLabel(
                        title: "Grubu Oluştur",
                        systemImage: "plus"
                    )
                }
            }
            .disabled(trimmedName.isEmpty || isCreating)
            .opacity(trimmedName.isEmpty ? 0.5 : 1)
        }
        .padding(24)
        .background(Color.background)
        .task {
            focused = true
        }
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
