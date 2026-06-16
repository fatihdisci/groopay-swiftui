import SwiftUI

struct EditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore
    let groupID: UUID
    let store: GroupsStore

    @State private var name = ""
    @State private var description = ""
    @State private var emoji: String?
    @State private var color = "#6366F1"
    @State private var initialized = false
    @State private var isWorking = false
    @State private var showDeleteConfirmation = false
    @State private var showLeaveConfirmation = false
    @State private var showTransferPicker = false

    private let colors = [
        "#6366F1", "#8B5CF6", "#EC4899", "#F59E0B",
        "#10B981", "#0EA5E9", "#F43F5E", "#64748B"
    ]
    private let emojis = [
        "🏠", "🍽", "✈️", "🎉", "🚗", "🛒", "💰", "🏖",
        "🎬", "⚽", "🎓", "☕", "🎵", "💻"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let previewSnapshot {
                    GroupHeader(snapshot: previewSnapshot)
                        .clipShape(
                            RoundedRectangle(cornerRadius: ThemeRadius.card)
                        )
                }

                fields
                saveButton
                managementButtons
            }
            .padding(20)
        }
        .background(Color.background)
        .navigationTitle("Grubu Düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .task { initialize() }
        .confirmationDialog(
            "Grubu kalıcı olarak silmek istiyor musun?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Grubu Sil", role: .destructive) {
                Task {
                    if await store.deleteGroup(groupID) {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog(
            "Gruptan ayrılmak istiyor musun?",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Ayrıl", role: .destructive) {
                Task { await leave() }
            }
        }
        .sheet(isPresented: $showTransferPicker) {
            transferSheet
                .presentationDetents([.medium])
                .presentationCornerRadius(24)
        }
    }

    private var snapshot: GroupSnapshot? {
        store.groups.first { $0.id == groupID }
    }

    private var currentMember: Member? {
        snapshot?.currentMember(
            userID: authStore.currentProfile?.id
                ?? SupabaseService.shared.auth.currentUser?.id
        )
    }

    private var isFounder: Bool {
        currentMember?.role == .founder
    }

    private var transferCandidates: [Member] {
        (snapshot?.activeMembers ?? []).filter {
            $0.id != currentMember?.id && !$0.isGhost
        }
    }

    private var previewSnapshot: GroupSnapshot? {
        guard var snapshot else { return nil }
        snapshot.group.name = name.isEmpty ? snapshot.group.name : name
        snapshot.group.description = description
        snapshot.group.avatarEmoji = emoji
        snapshot.group.avatarColor = color
        return snapshot
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 18) {
            field("Grup adı") {
                TextField("Grup adı", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            field("Açıklama") {
                TextField(
                    "Kısa açıklama",
                    text: $description,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            }

            field("Renk") {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible()),
                        count: 8
                    ),
                    spacing: 10
                ) {
                    ForEach(self.colors, id: \.self) { (item: String) in
                        Button {
                            color = item
                        } label: {
                            Circle()
                                .fill(
                                    Color(cssHex: item)
                                        ?? Color.primaryTheme
                                )
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if color == item {
                                        Circle()
                                            .stroke(
                                                Color.textPrimary,
                                                lineWidth: 2
                                            )
                                            .padding(-3)
                                    }
                                }
                        }
                    }
                }
            }

            field("Emoji") {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible()),
                        count: 7
                    ),
                    spacing: 10
                ) {
                    ForEach(self.emojis, id: \.self) { (item: String) in
                        Button {
                            emoji = emoji == item ? nil : item
                        } label: {
                            Text(item)
                                .font(.system(size: 23))
                                .frame(width: 38, height: 38)
                                .background(
                                    emoji == item
                                        ? Color.primaryTheme.opacity(0.12)
                                        : Color.surface
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 10)
                                )
                        }
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            GradientButtonLabel(
                title: "Değişiklikleri Kaydet",
                systemImage: "checkmark"
            )
        }
        .disabled(
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || isWorking
        )
    }

    private var managementButtons: some View {
        VStack(spacing: 12) {
            Button {
                if isFounder {
                    if transferCandidates.isEmpty {
                        showDeleteConfirmation = true
                    } else {
                        showTransferPicker = true
                    }
                } else {
                    showLeaveConfirmation = true
                }
            } label: {
                Label(
                    isFounder ? "Devret ve Ayrıl" : "Gruptan Ayrıl",
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            .tint(.debt)

            if isFounder {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Grubu Sil", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var transferSheet: some View {
        NavigationStack {
            List(transferCandidates) { member in
                Button {
                    Task { await transferAndLeave(to: member) }
                } label: {
                    HStack {
                        GradientAvatar(
                            name: member.displayName,
                            color: member.avatarColor,
                            size: 38
                        )
                        Text(member.displayName)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
            }
            .navigationTitle("Kuruculuğu Devret")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func field<Content: View>(
        _ title: LocalizedStringResource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body(13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            content()
        }
    }

    private func initialize() {
        guard !initialized, let group = snapshot?.group else { return }
        initialized = true
        name = group.name
        description = group.description ?? ""
        emoji = group.avatarEmoji
        color = group.avatarColor
    }

    private func save() async {
        isWorking = true
        let success = await store.updateGroup(
            id: groupID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            emoji: emoji,
            color: color
        )
        isWorking = false
        if success {
            dismiss()
        }
    }

    private func leave() async {
        guard let currentMember else { return }
        if await store.removeMember(
            groupID: groupID,
            memberID: currentMember.id
        ) {
            dismiss()
        }
    }

    private func transferAndLeave(to member: Member) async {
        guard let currentMember else { return }
        isWorking = true
        defer { isWorking = false }

        guard await store.transferOwnership(
            groupID: groupID,
            memberID: member.id
        ) else { return }

        if await store.removeMember(
            groupID: groupID,
            memberID: currentMember.id
        ) {
            showTransferPicker = false
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        EditGroupView(
            groupID: PreviewSupport.groupID,
            store: PreviewSupport.groupsStore
        )
    }
    .environment(PreviewSupport.authStore)
}
