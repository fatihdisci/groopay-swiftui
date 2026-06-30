import Foundation
import UserNotifications

// MARK: - Endowment Notification (UX-AUDIT §4.1 Aşama 3)
//
// Kullanıcının ilk masrafından 48 saat sonra, Pro değilse ve bildirim izni varsa
// tek bir yerel bildirim gönderir. Pro olunca iptal edilir. Duplicate oluşmaz.

enum EndowmentNotificationScheduler {
    private static let identifier = "endowment-48h"

    /// İlk masraf anında çağrılır. Kullanıcı zaten Pro ise veya bildirim izni
    /// yoksa sessizce no-op olur. 48 saat sonrası için tek bir local notification
    /// zamanlar; eski pending varsa önce silinir.
    static func scheduleIfNeeded(afterFirstExpense date: Date) async {
        // Pro kullanıcıya bildirim gönderme
        guard await !isPro else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else {
            return
        }

        // Eski planlamayı temizle, duplicate oluşmasın
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Groopay'i kullanmaya başladın 👋")
        content.body = String(localized: "Pro ile sınırsız grup oluşturabilir, harcama trendlerini ve detaylı analizleri açabilirsin. Gözat ister misin?")
        content.userInfo = ["action": "open_paywall"]
        content.sound = .default

        // 48 saat sonra
        let triggerDate = Calendar.current.date(
            byAdding: .hour,
            value: 48,
            to: date
        ) ?? date.addingTimeInterval(48 * 3600)
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    /// Pro satın alındığında veya geri yüklendiğinde çağrılır.
    /// Pending endowment bildirimini iptal eder.
    static func cancelIfScheduled() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Endowment bildirimine tıklanıp tıklanmadığını kontrol eder.
    /// `didReceive response` handler'ından çağrılır.
    static func isEndowmentNotification(_ response: UNNotificationResponse) -> Bool {
        response.notification.request.content.userInfo["action"] as? String == "open_paywall"
    }

    /// AuthStore.hasProAccess async kontrol — ana aktörde.
    private static var isPro: Bool {
        get async {
            await MainActor.run {
                AuthStoreRelay.shared.hasProAccess
            }
        }
    }
}

// MARK: - AuthStore Relay (basit async proxy)

/// Endowment scheduler'ın AuthStore.hasProAccess'e async erişimi için
/// hafif singleton relay. GroopayApp init'inde `shared.hasProAccess` güncel tutulur.
@MainActor
final class AuthStoreRelay: ObservableObject {
    static let shared = AuthStoreRelay()

    @Published private(set) var hasProAccess = false

    private init() {}

    func update(hasProAccess: Bool) {
        self.hasProAccess = hasProAccess
    }
}
