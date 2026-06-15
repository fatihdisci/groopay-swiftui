import SwiftUI

struct ProfileEditView: View {
    let profile: Profile
    let onSave: (_ name: String, _ color: String) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var selectedColor: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        profile: Profile,
        onSave: @escaping (_ name: String, _ color: String) async throws -> Void
    ) {
        self.profile = profile
        self.onSave = onSave
        _displayName = State(initialValue: profile.displayName)
        _selectedColor = State(initialValue: profile.avatarColor)
    }

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
            && trimmedName.count <= 40
            && !isSaving
            && (
                trimmedName != profile.displayName
                    || selectedColor != profile.avatarColor
            )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    GradientAvatar(
                        name: trimmedName.isEmpty ? "?" : trimmedName,
                        color: selectedColor,
                        size: 88
                    )
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Görünen ad")
                            .font(.body(14, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        TextField("Adınızı girin", text: $displayName)
                            .font(.body(16))
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 14)
                            .frame(minHeight: 50)
                            .background(Color.surface)
                            .clipShape(
                                RoundedRectangle(cornerRadius: ThemeRadius.button)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: ThemeRadius.button)
                                    .stroke(
                                        trimmedName.isEmpty
                                            ? Color.debt.opacity(0.5)
                                            : Color.primaryTheme.opacity(0.2),
                                        lineWidth: 1
                                    )
                            }
                            .onChange(of: displayName) { _, newValue in
                                if newValue.count > 40 {
                                    displayName = String(newValue.prefix(40))
                                }
                            }

                        HStack {
                            if trimmedName.isEmpty {
                                Text("Görünen ad boş bırakılamaz.")
                                    .foregroundStyle(Color.debt)
                            }
                            Spacer()
                            Text("\(displayName.count)/40")
                                .foregroundStyle(Color.textTertiary)
                        }
                        .font(.body(12))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Avatar rengi")
                            .font(.body(14, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 12),
                                count: 4
                            ),
                            spacing: 16
                        ) {
                            ForEach(AvatarPalette.colors, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(cssHex: color) ?? .primaryTheme)
                                            .frame(width: 48, height: 48)

                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(minWidth: 52, minHeight: 52)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Avatar rengi")
                                .accessibilityValue(color)
                                .accessibilityAddTraits(
                                    selectedColor == color ? .isSelected : []
                                )
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.body(13))
                            .foregroundStyle(Color.debt)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .background(Color.background.ignoresSafeArea())
            .navigationTitle("Profili Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Kaydet")
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil

        do {
            try await onSave(trimmedName, selectedColor)
            dismiss()
        } catch {
            errorMessage = "Profil güncellenemedi. Lütfen tekrar deneyin."
            isSaving = false
        }
    }
}
