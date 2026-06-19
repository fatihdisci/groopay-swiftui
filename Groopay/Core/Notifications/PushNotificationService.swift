import Foundation
import Supabase
import UIKit
@preconcurrency import UserNotifications

@MainActor
final class PushNotificationService {
    static let shared = PushNotificationService()

    private let supabase: SupabaseClient
    private var latestToken: String?
    private static let latestTokenKey = "groopay.push.latest-token"
    private static let pendingGroupKey = "groopay.push.pending-group"

    init(supabase: SupabaseClient = SupabaseService.shared) {
        self.supabase = supabase
        latestToken = UserDefaults.standard.string(forKey: Self.latestTokenKey)
    }

    func requestAuthorizationIfNeeded(hasGroups: Bool) async {
        guard hasGroups else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let granted: Bool

        switch settings.authorizationStatus {
        case .notDetermined:
            granted = (try? await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )) == true
        case .authorized, .provisional, .ephemeral:
            granted = true
        case .denied:
            granted = false
        @unknown default:
            granted = false
        }

        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        await syncLatestToken()
    }

    func received(deviceToken: Data) async {
        latestToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(latestToken, forKey: Self.latestTokenKey)
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
        do {
            try await supabase
                .from("push_tokens")
                .upsert(row, onConflict: "token")
                .execute()
        } catch {
            #if DEBUG
            print("Push token sync failed: \(error)")
            #endif
        }
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

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        #if DEBUG
        print("APNs registration failed: \(error)")
        #endif
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
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
