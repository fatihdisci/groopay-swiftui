import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security
import Supabase

@MainActor
@Observable
final class AuthStore {
    enum SessionState: Equatable {
        case signedOut
        case anonymous
        case identified
    }

    private(set) var sessionState: SessionState = .signedOut
    private(set) var currentProfile: Profile?
    private(set) var isRestoringSession = true
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var canPurchase: Bool {
        sessionState == .identified
    }

    private let supabase: SupabaseClient
    private var authListenerTask: Task<Void, Never>?
    private var appleNonce: String?

    init(supabase: SupabaseClient = SupabaseService.shared) {
        self.supabase = supabase
        observeAuthState()
    }

    func signInAnonymously() async {
        await performAuthAction {
            try await supabase.auth.signInAnonymously()
        }
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func signInWithApple(
        result: Result<ASAuthorization, any Error>
    ) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
            appleNonce = nil
        }

        do {
            let authorization = try result.get()

            guard
                let credential = authorization.credential
                    as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = appleNonce
            else {
                throw AuthStoreError.invalidAppleCredential
            }

            let credentials = OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )

            let wasAnonymous = supabase.auth.currentUser?.isAnonymous ?? false
            let previousUserID = supabase.auth.currentUser?.id

            var session: Session
            if wasAnonymous {
                do {
                    session = try await supabase.auth.linkIdentityWithIdToken(
                        credentials: credentials
                    )
                    if let previousUserID, session.user.id != previousUserID {
                        throw AuthStoreError.identityMismatch
                    }
                } catch {
                    // Kimlik zaten başka bir hesaba bağlıysa (ör. eski oturum),
                    // o hesaba giriş yap. Anonim veriler korunamaz ama kullanıcı
                    // eski hesabına döner.
                    session = try await supabase.auth.signInWithIdToken(
                        credentials: credentials
                    )
                }
            } else {
                session = try await supabase.auth.signInWithIdToken(
                    credentials: credentials
                )
            }
            await apply(session: session)
        } catch let error as ASAuthorizationError
            where error.code == .canceled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadProfile() async {
        guard let userID = supabase.auth.currentUser?.id else {
            currentProfile = nil
            return
        }

        do {
            currentProfile = try await supabase
                .from("profiles")
                .select(
                    """
                    id, display_name, avatar_color, locale, preferred_currency,
                    expo_push_token, user_pro, user_pro_purchased_at, created_at
                    """
                )
                .eq("id", value: userID)
                .single()
                .execute()
                .value
        } catch {
            currentProfile = nil
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(name: String, color: String) async throws {
        let userID = try await supabase.auth.session.user.id
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 40 else {
            throw AuthStoreError.invalidDisplayName
        }
        guard AvatarPalette.colors.contains(color) else {
            throw AuthStoreError.invalidAvatarColor
        }

        let update = ProfileUpdate(
            displayName: trimmedName,
            avatarColor: color
        )

        try await supabase
            .from("profiles")
            .update(update)
            .eq("id", value: userID)
            .execute()

        try await supabase
            .from("group_members")
            .update(GroupMemberNameUpdate(displayName: update.displayName))
            .eq("user_id", value: userID)
            .execute()

        await loadProfile()
    }

    func clearError() {
        errorMessage = nil
    }

    private func observeAuthState() {
        authListenerTask = Task { [weak self, supabase] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }

                if event == .initialSession, session?.isExpired == true {
                    continue
                }

                await self.apply(session: session)
            }
        }
    }

    private func apply(session: Session?) async {
        isRestoringSession = false

        guard let session else {
            sessionState = .signedOut
            currentProfile = nil
            return
        }

        sessionState = session.user.isAnonymous ? .anonymous : .identified
        await loadProfile()
    }

    private func performAuthAction(
        _ action: () async throws -> Session
    ) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let session = try await action()
            await apply(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)

        let characters = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(
                kSecRandomDefault,
                randomBytes.count,
                &randomBytes
            )
            precondition(status == errSecSuccess)

            for byte in randomBytes where remainingLength > 0 {
                guard byte < characters.count else { continue }
                result.append(characters[Int(byte)])
                remainingLength -= 1
            }
        }

        return result
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private struct ProfileUpdate: Encodable {
    let displayName: String
    let avatarColor: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarColor = "avatar_color"
    }
}

private struct GroupMemberNameUpdate: Encodable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

private enum AuthStoreError: LocalizedError {
    case invalidAppleCredential
    case identityMismatch
    case invalidDisplayName
    case invalidAvatarColor

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            String(localized: "auth.error.invalidAppleCredential")
        case .identityMismatch:
            "Apple kimliği bağlanamadı; misafir verileriniz korundu."
        case .invalidDisplayName:
            "Görünen ad 1-40 karakter olmalıdır."
        case .invalidAvatarColor:
            "Geçersiz avatar rengi."
        }
    }
}
