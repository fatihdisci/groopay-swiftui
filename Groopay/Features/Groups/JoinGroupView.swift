import SwiftUI

struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore
    @Environment(\.locale) private var locale
    let store: GroupsStore

    @State private var code = ""
    @State private var preview: InvitePreview?
    @State private var ghosts: [Member] = []
    @State private var selectedGhostID: UUID?
    @State private var isWorking = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero

                if let preview {
                    previewContent(preview)
                } else {
                    codeEntry
                }
            }
            .padding(20)
        }
        .background(Color.background)
        .navigationTitle("Gruba Katıl")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isFocused = true
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Kapat") { dismiss() }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 38))
            Text("Davet kodunla gruba katıl")
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
    }

    private var codeEntry: some View {
        VStack(spacing: 16) {
            TextField("ABC12345", text: $code)
                .font(.display(28, weight: .extraBold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .tracking(5)
                .padding(18)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
                .focused($isFocused)
                .onChange(of: code) { _, newValue in
                    let filtered = String(
                        newValue
                            .uppercased()
                            .filter { $0.isLetter || $0.isNumber }
                            .prefix(8)
                    )
                    code = filtered

                    // 8 karakter dolunca otomatik kontrol et
                    if filtered.count == 8 {
                        Task { await lookup() }
                    }
                }

            Button {
                Task { await lookup() }
            } label: {
                GradientButtonLabel(
                    title: "Kodu Kontrol Et",
                    systemImage: "magnifyingglass"
                )
            }
            .disabled(code.isEmpty || isWorking)
        }
    }

    private func previewContent(_ preview: InvitePreview) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                GradientAvatar(
                    name: preview.groupName
                        ?? String(localized: "Grup", locale: locale),
                    size: 60
                )
                Text(
                    preview.groupName
                        ?? String(localized: "Grup", locale: locale)
                )
                    .font(.display(22, weight: .extraBold))
                Text("\(preview.memberCount ?? 0) aktif üye")
                    .font(.body(13))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))

            if !ghosts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Bu kişilerden biri sen misin?")
                        .font(.body(14, weight: .semibold))

                    ForEach(ghosts) { member in
                        claimButton(
                            title: member.displayName,
                            id: member.id
                        )
                    }
                    claimButton(title: "Yeni üye olarak katıl", id: nil)
                }
            }

            Button {
                Task { await join() }
            } label: {
                if isWorking {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.primaryTheme)
                        .clipShape(
                            RoundedRectangle(cornerRadius: ThemeRadius.button)
                        )
                } else {
                    GradientButtonLabel(
                        title: "Gruba Katıl",
                        systemImage: "checkmark.circle"
                    )
                }
            }
            .disabled(isWorking)

            Button("Farklı kod gir") {
                self.preview = nil
                ghosts = []
                selectedGhostID = nil
            }
            .font(.body(14, weight: .medium))
        }
    }

    private func claimButton(title: String, id: UUID?) -> some View {
        Button {
            selectedGhostID = id
        } label: {
            HStack {
                Image(
                    systemName: selectedGhostID == id
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                if id == nil {
                    Text("Yeni üye olarak katıl")
                } else {
                    Text(verbatim: title)
                }
                Spacer()
            }
            .font(.body(14, weight: .medium))
            .foregroundStyle(
                selectedGhostID == id
                    ? Color.primaryTheme
                    : Color.textPrimary
            )
            .padding(14)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func lookup() async {
        isWorking = true
        guard let result = await store.previewInvite(code: code) else {
            isWorking = false
            return
        }
        preview = result
        ghosts = await store.previewGhosts(code: code)
        selectedGhostID = nil
        isWorking = false
    }

    private func join() async {
        guard let preview, let token = preview.token else { return }
        isWorking = true
        let success = await store.join(
            code: token,
            claimGhostID: selectedGhostID,
            displayName: authStore.currentProfile?.displayName
                ?? String(localized: "Kullanıcı", locale: locale)
        )
        isWorking = false
        if success {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        JoinGroupView(store: PreviewSupport.groupsStore)
    }
    .environment(PreviewSupport.authStore)
}
