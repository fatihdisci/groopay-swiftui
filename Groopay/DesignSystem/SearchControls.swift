import SwiftUI

/// Standart arama alanı. ActivityView ve Dashboard son aktivite araması aynı
/// padding, radius, ikon, temizle butonu ve focus davranışını paylaşsın diye
/// tek bileşene çıkarıldı. Reduce Motion'da temizleme animasyonsuz yapılır.
struct AppSearchField: View {
    @Binding var text: String
    var placeholder: LocalizedStringResource
    var onClear: (() -> Void)? = nil

    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textTertiary)

            TextField(text: $text, prompt: Text(placeholder)) {
                Text(placeholder)
            }
            .font(.body(15))
            .foregroundStyle(Color.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focused)
            .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    if reduceMotion {
                        clear()
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) { clear() }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aramayı temizle")
            }
        }
        .padding(12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.button))
        .frame(maxWidth: .infinity)
    }

    private func clear() {
        text = ""
        onClear?()
    }
}

/// Standart filtre butonu (kapsül + aktif filtre sayısı badge'i). Filtre
/// sunumunu çağıran yönetir; buton yalnız stil + sayaç sağlar.
struct AppFilterButton: View {
    var title: LocalizedStringResource = "Filtrele"
    var activeCount: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(title)
                if activeCount > 0 {
                    ActiveFilterBadge(count: activeCount)
                }
            }
            .font(.body(13, weight: .semibold))
            .foregroundStyle(Color.primaryTheme)
            .padding(.horizontal, 12)
            .frame(minHeight: 42)
            .background(Color.surfaceTinted)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(
            activeCount > 0
                ? Text("\(activeCount) etkin filtre")
                : Text("Etkin filtre yok")
        )
    }
}

/// Aktif filtre sayısını gösteren küçük rozet.
struct ActiveFilterBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(minWidth: 20, minHeight: 20)
            .background(Color.primaryTheme)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}
