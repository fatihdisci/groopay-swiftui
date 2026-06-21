import SwiftUI

/// Kritik async işlemler için tekrar kullanılabilir buton. İşlem sürerken:
/// - buton disabled olur, ikinci kez başlatılamaz (duplicate-submit koruması),
/// - metin korunur, üzerine bir ProgressIndicator gösterilir,
/// - VoiceOver "işlem sürüyor" durumunu bildirir.
/// Başarısızlıkta buton yeniden kullanılabilir hale gelir (işlem bitince
/// `isRunning` her durumda sıfırlanır).
struct AsyncActionButton<Label: View>: View {
    let action: () async -> Void
    var isEnabled: Bool = true
    @ViewBuilder var label: () -> Label

    @State private var isRunning = false
    @Environment(\.locale) private var locale

    var body: some View {
        Button {
            guard !isRunning else { return }
            isRunning = true
            Task {
                await action()
                isRunning = false
            }
        } label: {
            label()
                .opacity(isRunning ? 0.55 : 1)
                .overlay {
                    if isRunning {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                }
        }
        .disabled(isRunning || !isEnabled)
        .accessibilityValue(
            isRunning
                ? Text(String(localized: "İşlem sürüyor", locale: locale))
                : Text("")
        )
    }
}
