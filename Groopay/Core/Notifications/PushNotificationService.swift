import Foundation
import Supabase
import UIKit
@preconcurrency import UserNotifications

@MainActor
final class PushNotificationService {
    static let shared = PushNotificationService()

    private let supabase: SupabaseClient
    private var latestToken: String?
    private let permissionPromptedKey = "groopay.push.permission-prompted"
    private static let pendingGroupKey = "groopay.push.pending-group"

    init(supabase: SupabaseClient = SupabaseService.shared) {
        self.supabase = supabase
    }

    func requestAuthorizationIfNeeded(hasGroups: Bool) async {
        guard hasGroups else { return }

        if UserDefaults.standard.bool(forKey: permissionPromptedKey) {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                UIApplication.shared.registerForRemoteNotifications()
            }
            await syncLatestToken()
            return
        }

        UserDefaults.standard.set(true, forKey: permissionPromptedKey)
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) == true
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func received(deviceToken: Data) async {
        latestToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        await syncLatestToken()
    }

    func syncLatestToken() async {
        guard let token = latestToken,
              let userID = supabase.auth.currentUser?.id else { return }

        let row = PushTokenRow(
            userID: userID,
            token: token,
            environment: Self.environment,
            deviceID: UIDevice.current.identifierForVendor?.uuidString
        )
        _ = try? await supabase
            .from("push_tokens")
            .upsert(row, onConflict: "token")
            .execute()
    }

    func removeCurrentToken() async {
        guard let token = latestToken,
              let userID = supabase.auth.currentUser?.id else { return }
        _ = try? await supabase
            .from("push_tokens")
            .delete()
            .eq("token", value: token)
            .eq("user_id", value: userID)
            .execute()
    }

    static func storePendingGroup(_ groupID: UUID) {
        UserDefaults.standard.set(groupID.uuidString, forKey: pendingGroupKey)
    }

    static func consumePendingGroup() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: pendingGroupKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingGroupKey)
        return UUID(uuidString: raw)
    }

    private static var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}

private struct PushTokenRow: Encodable {
    let userID: UUID
    let token: String
    let environment: String
    let deviceID: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case token
        case environment
        case deviceID = "device_id"
    }
}

final class GroopayAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await PushNotificationService.shared.received(deviceToken: deviceToken)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo["group_id"] as? String,
              let groupID = UUID(uuidString: raw) else { return }
        await MainActor.run {
            PushNotificationService.storePendingGroup(groupID)
            NotificationCenter.default.post(
                name: .groopayOpenGroup,
                object: groupID
            )
        }
    }
}
