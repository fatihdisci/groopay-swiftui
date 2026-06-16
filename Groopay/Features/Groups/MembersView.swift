import SwiftUI

struct MembersView: View {
    @Environment(AuthStore.self) private var authStore
    let groupID: UUID
    let store: GroupsStore
    @State private var showGhostForm = false
    @State private var ghostName = ""
    @State private var inviteCode: String?
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                actionSection

                ForEach(snapshot?.members ?? []) { member in
                    memberRow(member)
                }
            }
            .padding(20)
        }
        .background(Color.background)
        .navigationTitle("Üyeler")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "İşlem başarısız",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.clearError() } }
            )
        ) {
            Button("Tamam", role: .cancel) { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "")
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

    private var actionSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    if isFounder {
                        withAnimation {
                            showGhostForm.toggle()
                        }
                    }
                } label: {
                    Label("Hayalet Ekle", systemImage: "person.badge.plus")
                        .font(.body(13, weight: .semibold))
                        .foregroundStyle(
                            isFounder
                                ? Color.primaryTheme
                                : Color.textTertiary
                        )
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: ThemeRadius.button)
                                .stroke(
                                    isFounder
                                        ? Color.primaryTheme.opacity(0.3)
                                        : Color.textTertiary.opacity(0.2)
                                )
                        )
                }
                .disabled(!isFounder)

                Button {
                    Task { await createInvite() }
                } label: {
                    GradientButtonLabel(
                        title: "Davet Linki",
                        systemImage: "link"
                    )
                }
                .disabled(isWorking)
            }

            if !isFounder {
                Text("Yalnızca grup kurucusu hayalet üye ekleyebilir.")
                    .font(.body(12))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showGhostForm {
                HStack(spacing: 10) {
                    TextField("Üye adı", text: $ghostName)
                        .font(.body(14))
                        .padding(13)
                        .background(Color.surfaceTinted)
                        .clipShape(
                            RoundedRectangle(cornerRadius: ThemeRadius.button)
                        )

                    Button("Ekle") {
                        Task { await addGhost() }
                    }
                    .font(.body(14, weight: .semibold))
                    .disabled(ghostName.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty || isWorking)
                }
                .padding(14)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
            }

            if let inviteCode {
                VStack(spacing: 12) {
                    Text(inviteCode)
                        .font(.display(25, weight: .extraBold))
                        .tracking(4)
                        .foregroundStyle(Color.primaryTheme)

                    ShareLink(
                        item: "Groopay davet kodu: \(inviteCode)",
                        subject: Text("Groopay grup daveti")
                    ) {
                        Label("Kodu Paylaş", systemImage: "square.and.arrow.up")
                            .font(.body(14, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(Color.surfaceTinted)
                .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
            }
        }
    }

    private func memberRow(_ member: Member) -> some View {
        HStack(spacing: 13) {
            GradientAvatar(
                name: member.displayName,
                color: member.avatarColor,
                size: 46
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(member.displayName)
                        .font(.body(15, weight: .semibold))
                        .foregroundStyle(
                            member.isActive
                                ? Color.textPrimary
                                : Color.textTertiary
                        )
                    if member.role == .founder {
                        Text("KURUCU")
                            .font(.body(9, weight: .semibold))
                            .foregroundStyle(Color.primaryTheme)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.primaryTheme.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Text(member.isGhost ? "Hayalet" : "Gerçek üye")
                    .font(.body(12, weight: .medium))
                    .foregroundStyle(
                        member.isGhost
                            ? Color.warning
                            : Color.textSecondary
                    )
            }

            Spacer()

            if isFounder
                && member.role != .founder
                && member.isActive {
                Button(role: .destructive) {
                    Task {
                        _ = await store.removeMember(
                            groupID: groupID,
                            memberID: member.id
                        )
                    }
                } label: {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .opacity(member.isActive ? 1 : 0.6)
    }

    private func addGhost() async {
        let name = ghostName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !name.isEmpty else { return }
        isWorking = true
        if await store.addGhost(groupID: groupID, displayName: name) {
            ghostName = ""
            showGhostForm = false
        }
        isWorking = false
    }

    private func createInvite() async {
        isWorking = true
        inviteCode = await store.createInvite(groupID: groupID)
        isWorking = false
    }
}

#Preview {
    NavigationStack {
        MembersView(
            groupID: PreviewSupport.groupID,
            store: PreviewSupport.groupsStore
        )
    }
    .environment(PreviewSupport.authStore)
}
