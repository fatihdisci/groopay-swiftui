import SwiftUI
import Observation

enum FeedbackStyle: Equatable, Sendable {
    case success
    case error
    case warning
    case info

    var icon: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: .credit
        case .error: .debt
        case .warning: .warning
        case .info: .primaryTheme
        }
    }
}

/// Tek bir geri bildirim mesajı. `action`/`actionTitle` opsiyoneldir ("Geri Al"
/// gibi aksiyonlu toast'lar için). `action` closure olduğundan Equatable yalnız
/// kimlik + metin + stil üzerinden karşılaştırılır.
struct FeedbackMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let style: FeedbackStyle
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        text: String,
        style: FeedbackStyle,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.text = text
        self.style = style
        self.actionTitle = actionTitle
        self.action = action
    }

    static func == (lhs: FeedbackMessage, rhs: FeedbackMessage) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.style == rhs.style
    }
}

/// Uygulama genelinde başarı/hata/uyarı/bilgi geri bildirimlerini tek noktadan
/// yönetir. Yeni mesaj geldiğinde bir önceki iptal edilir (üst üste binme yok),
/// otomatik kapanır. `GroopayApp` seviyesinde environment'a enjekte edilir.
/// Tüm çağrılar SwiftUI ana iş parçacığından gelir; otomatik kapanma Task'i
/// güncellemeyi `MainActor.run` ile yapar.
@Observable
final class AppFeedbackCenter {
    private(set) var current: FeedbackMessage?

    private var dismissTask: Task<Void, Never>?

    func show(
        _ text: String,
        style: FeedbackStyle,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        duration: Duration = .seconds(3)
    ) {
        // Önceki mesajı iptal et (replace) → aynı anda tek banner.
        dismissTask?.cancel()
        current = FeedbackMessage(
            text: text,
            style: style,
            actionTitle: actionTitle,
            action: action
        )
        let id = current?.id
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.current?.id == id else { return }
                self?.current = nil
            }
        }
    }

    func success(_ text: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        show(text, style: .success, actionTitle: actionTitle, action: action,
             duration: action == nil ? .seconds(2.5) : .seconds(6))
    }

    func error(_ text: String) {
        show(text, style: .error, duration: .seconds(3.5))
    }

    func warning(_ text: String) {
        show(text, style: .warning)
    }

    func info(_ text: String) {
        show(text, style: .info)
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

private struct AppFeedbackKey: EnvironmentKey {
    static let defaultValue = AppFeedbackCenter()
}

extension EnvironmentValues {
    var appFeedback: AppFeedbackCenter {
        get { self[AppFeedbackKey.self] }
        set { self[AppFeedbackKey.self] = newValue }
    }
}

/// Bütün tab'lerin üstünde çalışan tek banner host'u. `MainTabView` kökünde
/// yerleştirilir. Reduce Motion'da geçiş animasyonu kapanır; mesaj VoiceOver
/// announcement olarak okunur; başarı/hata için haptik üretir.
struct FeedbackHost: ViewModifier {
    var center: AppFeedbackCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = center.current {
                    banner(message)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .top).combined(with: .opacity)
                        )
                        .id(message.id)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86),
                       value: center.current)
            .sensoryFeedback(trigger: center.current?.id) { _, _ in
                switch center.current?.style {
                case .success: .success
                case .error: .error
                case .warning: .warning
                case .none, .info: nil
                }
            }
            .onChange(of: center.current?.id) { _, _ in
                if let text = center.current?.text {
                    AccessibilityNotification.Announcement(text).post()
                }
            }
    }

    private func banner(_ message: FeedbackMessage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: message.style.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(message.style.tint)

            Text(message.text)
                .font(.body(14, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            if let actionTitle = message.actionTitle, let action = message.action {
                Button {
                    action()
                    center.dismiss()
                } label: {
                    Text(actionTitle)
                        .font(.body(14, weight: .semibold))
                        .foregroundStyle(Color.primaryTheme)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ThemeRadius.card)
                .stroke(message.style.tint.opacity(0.25), lineWidth: 1)
        )
        .purpleTintedShadow(radius: 16, y: 8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text(message.text))
    }
}

extension View {
    func feedbackHost(_ center: AppFeedbackCenter) -> some View {
        modifier(FeedbackHost(center: center))
    }
}
