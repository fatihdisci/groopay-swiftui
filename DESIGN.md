# Groopay Design System · DESIGN.md

> **Durum: TASLAK** — renk yönü onayı bekliyor (son bölüme bak).
> Bu belge `DESIGN-AUDIT.md`'de tespit edilen 17 AI tell'in çözümüdür.
> Her karar para-uygulaması güveni gerekçesiyle bağlanmıştır.

---

## 0. Şu Anki Durum → Hedef Dönüşüm

| Boyut | Şu an (AI generic) | Hedef (güven sinyali) |
|---|---|---|
| Renk kimliği | İndigo-mor gradyan her yerde | Nötr/güvenli ana palet, **tek yerde gradyan (ya da hiç)** |
| Tipografi | Inter body + PJS display | SF Pro (para/rakam) + SF Pro Display (başlık) |
| Arka plan | #F7F6FF mor-tintli | Nötr sıcak gri veya saf sistem arka planı |
| Gölgeler | Mor-tintli, her kartta aynı | Nötr siyah, opacity kademeli |
| Radius | 8-10-12-14-16-18-20-22-34 | 4 token: sharp/soft/rounded/full |
| Spacing | Magic number'lar (6, 10, 14, 18, 22…) | 8pt grid: 4/8/12/16/20/24/32/40/48/56/64 |
| Dark mode | Yok | Tam destek, her token'ın dark varyantı var |
| Avatar | Herkes gradient circle | Solid palet + gradient sadece sahipsiz gruplar |

---

## 1. Marka Kimliği

**Groopay ne değildir:** Bir banka değildir. Bir muhasebe yazılımı değildir. Bir "AI wrapper" değildir.
**Groopay nedir:** Arkadaş gruplarının harcamalarını **şeffaf, adil ve insani** şekilde bölüştüren bir araçtır. Ton: sıcak ama ciddi, yakın ama sorumlu.

Groopay'in mevcut indigo-mor kimliği **"AI'ın ilk önerdiği palet"** klişesidir. Bunu kırıp para uygulamasına yakışan, özgün ve güven veren bir kimlik inşa etmeliyiz.

Aşağıda **iki alternatif yön** sunuyorum. İkisi de **indigo-mor gradyan, Inter/Roboto, mor gölge içermez.**

---

### Yön A — "Derin Lacivert + Bakır" (Kurumsal Güven)

**Strateji:** Bankacılık kurumlarının yüzyıllık güven rengi olan laciverti al, fintech sıcaklığı için bakır/tunç bir accent'le kır. Bu yön "paranız emin ellerde" der.

| Token | Light | Dark |
|---|---|---|
| `brand` | `#1A2744` (deep navy) | `#8FA4C0` (soft navy) |
| `brandMuted` | `#E8ECF1` (navy 8%) | `#1E2A3A` (navy surface) |
| `accent` | `#C2884B` (warm copper) | `#D4A46A` (light copper) |
| `accentMuted` | `#FBF5EF` (copper 6%) | `#2D231A` (copper surface) |
| `background` | `#F6F5F4` (warm gray 50) | `#111111` (near black) |
| `surface` | `#FFFFFF` | `#1C1C1E` |
| `surfaceMuted` | `#F2F1F0` (warm gray 100) | `#262628` |
| `textPrimary` | `#1A1A1A` | `#F5F5F5` |
| `textSecondary` | `#6B6B6B` | `#A0A0A0` |
| `textTertiary` | `#999999` | `#6B6B6B` |
| `credit` | `#10B981` (emerald) | `#34D399` |
| `debt` | `#EF4444` (rose) | `#F87171` |
| `warning` | `#F59E0B` (amber) | `#FBBF24` |

**Gradyan kuralı:** Yalnızca **Dashboard genel durum kartında** (tek bir hero element), o da `brand → #2D4A6E` gibi aynı aileden koyu lacivert ton geçişi. Buton, avatar, onboarding, paywall, header — hiçbirinde gradyan yok.

**Gerekçe:** Lacivert, Barclays/Chase/Amex'in kullandığı evrensel finans güven rengidir. Bakır accent sıcaklık katar ama agresif değildir. Morun "AI/default" çağrışımı tamamen kırılır. Arka planın sıcak gri olması (#F6F5F4) mor-tintli #F7F6FF'in yerine geçer — nötr ama soğuk değil.

---

### Yön B — "Sıcak Nötr + Ada Çamı" (Modern Fintech)

**Strateji:** Monzo/Revolut okulundan ilhamla, neredeyse tamamen nötr bir tuval ve tek bir cesur yeşil accent. Bu yön "her şey şeffaf, her şey net" der.

| Token | Light | Dark |
|---|---|---|
| `brand` | `#2D3436` (warm charcoal) | `#B2BEC3` (soft gray) |
| `brandMuted` | `#EEF0F0` (charcoal 6%) | `#25282A` (charcoal surface) |
| `accent` | `#0D7B63` (deep teal-green) | `#2DD4A8` (bright teal) |
| `accentMuted` | `#EDF7F4` (teal 6%) | `#1A2824` (teal surface) |
| `background` | `#FAFAFA` (neutral white) | `#0D0D0D` (true black) |
| `surface` | `#FFFFFF` | `#1C1C1E` |
| `surfaceMuted` | `#F5F5F5` (neutral gray 100) | `#262628` |
| `textPrimary` | `#171717` | `#FAFAFA` |
| `textSecondary` | `#737373` | `#A3A3A3` |
| `textTertiary` | `#A3A3A3` | `#666666` |
| `credit` | `#10B981` (emerald) | `#34D399` |
| `debt` | `#EF4444` (rose) | `#F87171` |
| `warning` | `#F59E0B` (amber) | `#FBBF24` |

**Gradyan kuralı:** **Hiçbir yerde.** Brand rengi düz kullanılır. Gölgelendirme/derinlik yalnızca nötr gölge katmanlarıyla sağlanır.

**Gerekçe:** Nötr tuval veriyi öne çıkarır — para uygulamasında asıl içerik rakamlardır, marka değil. Accent yeşili (`#0D7B63`) credit yeşilinden (`#10B981`) belirgin şekilde farklıdır (daha koyu, daha mavi-altlı "çam" tonu vs. daha parlak "zümrüt") — karışmaz. Bu yön daha cesur, daha modern, daha "tasarım bilinçli yapılmış" hissi verir.

> ⚠️ İki yönde de `debt = kırmızı`, `credit = yeşil` **korunur.** Bu finansal konvansiyondur, değiştirilmesi kullanıcı hatasına yol açar.

---

## 2. Renk Token'ları (Rol-Bazlı Semantik)

Yukarıdaki iki yönden hangisi seçilirse seçilsin, token isimleri **rol-bazlı ve semantik** olacak. Kodda asla `Color(hex: 0x...)` geçmeyecek; her renk bu token üzerinden referanslanacak.

### 2.1 Token kataloğu

```swift
// MARK: - Brand
static let brand          // Ana marka rengi. Buton, link, seçili durum.
static let brandMuted     // brand'in %6-8 opaque hali. Chip arka planı, seçili satır.

// MARK: - Accent
static let accent         // Vurgu rengi. Öne çıkan CTA, bildirim dot'u, fiyat vurgusu.
static let accentMuted    // accent'in %6-8 opaque hali.

// MARK: - Surface
static let background     // Ana ekran arka planı
static let surface        // Kartlar, sheet'ler, list row'ları
static let surfaceMuted   // İkincil yüzey: iç içe kart, alternatif satır, disabled

// MARK: - Text
static let textPrimary    // Başlık, body, önemli rakamlar
static let textSecondary  // Açıklama, meta bilgi
static let textTertiary   // Placeholder, disabled, legal fine print

// MARK: - Semantic (FİNANSAL KONVANSİYON — DEĞİŞMEZ)
static let credit         // Alacak, pozitif bakiye, ödeştin, onay — HER ZAMAN YEŞİL
static let debt           // Borç, negatif bakiye, reddet, sil — HER ZAMAN KIRMIZI
static let warning        // Bekleyen onay, süre dolacak, limit — HER ZAMAN AMBER/SARI
```

### 2.2 Kullanım kuralları

- **Asla** `Color(hex: 0x...)` kullanma. Her renk yukarıdaki token'lar üzerinden.
- Her token'ın light ve dark varyantı olacak. `@Environment(\.colorScheme)` otomatik geçiş yapacak.
- `credit`/`debt`/`warning` semantik renkleri yalnızca bakiye/borç/onay bağlamında. Dekoratif kullanım YASAK.
- `brand` rengi metin üzerinde opacity ile KULLANILMAZ (contrast ratio kaybı). Onun yerine `textSecondary`/`textTertiary` kullan.

---

## 3. Tipografi

### 3.1 Font seçimi

| Rol | Mevcut | Yeni | Gerekçe |
|---|---|---|---|
| Display / başlık | Plus Jakarta Sans | **SF Pro Display** (system) | Native rendering, Dynamic Type, sıfır bundle yükü |
| Body / UI | Inter | **SF Pro Text** (system) | Inter = AI varsayılanı. SF Pro = iOS'un native para fontu (Wallet, Stocks, Health) |
| Rakam / tabular | Yok | **SF Mono** (tabular figures) | Para uygulamasında rakamların hizalanması KRİTİK — `.monospacedDigit()` modifier ile |

**Neden SF Pro?**
- Tüm Apple finans uygulamaları (Wallet, Stocks, Apple Card) SF Pro kullanır → kullanıcı bilinçaltında "bu Apple'ın onayladığı güvenli bir şey" hisseder.
- Sıfır bundle boyutu (sistem fontu), sıfır yükleme gecikmesi.
- Dynamic Type native destek — custom font'taki `relativeTo:` workaround'una gerek kalmaz.
- Inter'in "AI kokusu" tamamen gider.
- SF Pro'nun rakam formları (proportional vs monospace) para gösterimi için idealdir.

### 3.2 Tip ölçeği

```
Token           Size    Weight      Dynamic Type Baseline
──────────────────────────────────────────────────────────
displayLarge    34pt    .bold       .largeTitle
display         28pt    .bold       .title
h1              22pt    .semibold   .title2
h2              17pt    .semibold   .headline
body            15pt    .regular    .body
bodySmall       13pt    .regular    .subheadline
caption         11pt    .medium     .caption1
captionSmall    10pt    .semibold   .caption2
```

### 3.3 Dynamic Type — ZORUNLU

Tüm font kullanımları `Font.system(size:weight:relativeTo:)` ile yapılacak:

```swift
// DOĞRU
Text("Bakiyen")
    .font(.system(size: 28, weight: .bold, relativeTo: .title))

// YANLIŞ
Text("Bakiyen")
    .font(.system(size: 28, weight: .bold))
```

- En küçük font (captionSmall) AX5'e kadar okunabilir kalmalı.
- `minimumScaleFactor` sadece para tutarlarında, o da minimum 0.8.
- `lineLimit` + `truncationMode` her metinde tanımlı olmalı.

### 3.4 Rakam formatı (tabular figures)

Para tutarlarının alt alta hizalanması için:

```swift
Text(formatAmount(amount, currency: currency))
    .font(.system(size: 17, weight: .semibold, design: .monospaced))
    // veya
    .fontDesign(.monospaced)  // iOS 18+
```

---

## 4. Boşluk (Spacing)

### 4.1 8pt grid

Mevcut 4px grid kodu 8pt grid'e normalize edilecek:

```
Token       Değer   Kullanım
──────────────────────────────────────────
xs           4pt    İkon-metin arası, tight chip iç padding
sm           8pt    Aynı bileşen içi dikey boşluk, card iç padding
md          12pt    İlişkili bileşenler arası (label-input)
lg          16pt    Kart iç padding, list row arası
xl          20pt    Sectionlar arası, sayfa yatay padding
2xl         24pt    Büyük section arası, card'lar arası
3xl         32pt    Ekran üst/alt boşluğu, hero altı
4xl         40pt    Sayfa başlangıcı
5xl         48pt    Boş durum (empty state) dikey
6xl         56pt    —
7xl         64pt    —
```

**Değişken boşluk kuralı:** Aynı bileşende her zaman aynı spacing token'ı kullan. Sayfa seviyesinde VStack spacing'i **büyükten küçüğe**: ana section'lar arası `xl`(20), iç içe section'lar arası `lg`(16), aynı section içi `md`(12), birleşik öğeler arası `sm`(8).

Kodda:
```swift
enum ThemeSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let huge: CGFloat = 40
    // … 48, 56, 64
}
```

---

## 5. Şekil & Gölge

### 5.1 Radius (sadeleştirilmiş)

Mevcut 9 farklı radius değeri → **4 token**:

| Token | Değer | Kullanım |
|---|---|---|
| `sharp` | 4pt | TextField, picker, segmented control, toolbar |
| `soft` | 8pt | Kartlar (card), sheet'ler, list item |
| `rounded` | 12pt | Butonlar, chip'ler, FAB |
| `full` | .infinity | Pill, capsule, avatar, progress bar |

**Kural:** Bir view ağacında en fazla 2 farklı radius token'ı kullan. Kart içinde buton varsa kart `soft` (8), buton `rounded` (12) → OK. Kart içinde üç farklı radius → YASAK.

**Neden 8-12?** Apple HIG: card 8-12, button 10-14 aralığı. Daha küçük radius = daha ciddi/maskülen algı. Para uygulamasında 16+ radius "oyuncak" hissi verir; 8-12 aralığı "araç" hissi verir.

### 5.2 Gölge (nötr, mor değil)

Mevcut `purpleTintedShadow` → nötr siyah gölge kademesi:

| Token | Opacity | Radius | Y | Kullanım |
|---|---|---|---|---|
| `shadowSubtle` | black 3% | 4 | 2 | Kartlar arka plan üzerinde (default) |
| `shadowMedium` | black 6% | 8 | 4 | Yükseltilmiş kart (hover/selected) |
| `shadowStrong` | black 10% | 16 | 8 | Modal, bottom sheet, popover |
| `shadowNone` | — | 0 | 0 | Düz yüzeyler |

**Kural:** Gölge RENGİ her zaman `Color.black`. Asla marka rengi veya başka bir renk gölgeye karışmaz. Gölge yalnızca **derinlik hiyerarşisi** taşır; dekoratif değildir.

---

## 6. Güven Sinyali Kuralları (Para Uygulamasına Özel)

Bunlar "güzel tasarım"ın ötesinde, **para yöneten bir uygulamanın güvenilirlik altyapısıdır.**

### 6.1 Tutarlı grid — "bu uygulama hesap biliyor"

- Tüm para tutarları aynı hizada. Sağa yaslıysa her yerde sağa yaslı.
- Tabular figures (`monospacedDigit()`) ZORUNLU — alt alta gelen rakamların virgül/hane hizalaması kusursuz olmalı.
- Spacing token dışına çıkılmaz. 7px padding → build hatası (lint kuralı).

### 6.2 Anında onay — "kime, ne kadar, hangi grup"

Her para işleminden sonra kullanıcı şu 3 sorunun cevabını ANINDA görmeli:

1. **Kime?** → İsim/avatar + ok yönü (→ alacaklı, ← borçlu)
2. **Ne kadar?** → `formatAmount()` çıktısı, doğru para birimi
3. **Hangi grup?** → Grup adı + emoji

Bu format toast/feedback'te, aktivite row'unda ve push bildirimde AYNI olmalı.

```
❌ "İşlem başarılı" (güven sinyali: 0)
✅ "Ayşe'ye 450,00 ₺ borcun kaydedildi · Hafta Sonu 🏖️" (güven sinyali: 10)
```

### 6.3 Net hata mesajı formatı

Her hata mesajı şu üç parçayı içermeli:

```
[Ne oldu] · [Neden] · [Ne yapmalı]
```

```
❌ "Masraf kaydedilemedi"
✅ "Masraf kaydedilemedi · İnternet bağlantın kesilmiş olabilir · Tekrar dene veya daha sonra dene"
```

### 6.4 FX kilit şeffaflığı

Farklı para biriminde masraf eklendiğinde:
- Canlı kur bilgisi **hangi saat itibarıyla** geçerli olduğuyla birlikte göster.
- "Döviz kuru yaklaşık değerdir, kesinleşmiş borç değildir" uyarısı görünür olsun.
- Kur bilgisi ASLA kaydedilmez — bu bilgi kullanıcıya açıkça belirtilsin.

### 6.5 Dark pattern yasağı

- "Pro'ya Geç" butonu her zaman aynı yerde, aynı boyutta. Küçültme/gizleme/sahte aciliyet YASAK.
- Abonelik iptali en az "abone ol" kadar kolay bulunur olmalı.
- Silme işlemleri her zaman confirmation dialog + geri alınamaz uyarısı.
- "Sen ödedin" / "o ödedi" ayrımı renk + ikon + KELIME ile üçlü kodlama (renk körü erişilebilirliği).

---

## 7. İkonografi

### 7.1 SF Symbols — tek kaynak

- SVG/özel ikon YASAK. Her ikon SF Symbols kataloğundan.
- Render mode: `.font(.system(size:weight:))` ile. `Image(systemName:)` her zaman.
- Tutarlı weight: navigasyon `.semibold`(17), row ikonu `.semibold`(15), durum `.bold`(11).

### 7.2 Eşleme güncellemesi

Mevcut eşleme (`GROOPAY-SWIFT-SPEC.md:102-116`) korunur. Eklemeler:

| İşlev | SF Symbol |
|---|---|
| Borçlusun (ok) | `arrow.down.circle.fill` |
| Alacaklısın (ok) | `arrow.up.circle.fill` |
| Para birimi | `coloncurrencysign.circle.fill` (iOS 18+) veya `dollarsign.circle.fill` |
| Ödeştiniz (büyük) | `checkmark.seal.fill` |
| Borcunu öde | `creditcard.fill` |

---

## 8. Motion & Haptik

### 8.1 Spring animasyon — sadece vurgu anında

```swift
// SADECE onay/başarı anı:
withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
    showSuccessCheckmark = true
}

// Navigasyon/geçiş: yok ya da .easeInOut
withAnimation(.easeInOut(duration: 0.2)) {
    selection = newValue
}
```

**Kural:** `.spring` yalnızca kullanıcının bir işlemi başarıyla tamamladığı anlarda. Liste filtreleme, sekme geçişi, sheet açma → `.easeInOut` veya animasyonsuz.

### 8.2 Haptik geri bildirim

```swift
// Başarı (masraf eklendi, ödeme onaylandı)
.sensoryFeedback(.success, trigger: didSucceed)

// Hata (kayıt başarısız, bağlantı yok)
.sensoryFeedback(.error, trigger: didFail)

// Seçim (picker, toggle)
.sensoryFeedback(.selection, trigger: selectedItem)

// Uyarı (limit doldu, süre yaklaştı)
.sensoryFeedback(.warning, trigger: limitReached)

// Numpad tuşu — hafif
.sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: pressedKey)
```

### 8.3 reduceMotion — ZORUNLU

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Animasyonlu:
withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { ... }

// Haptik:
.sensoryFeedback(.success, trigger: didSucceed) // sensoryFeedback reduceMotion'dan etkilenmez, her zaman çalışır
```

**Kural:** Her `withAnimation` bloğu `reduceMotion` kontrolü içermeli. Mevcut kodun bazı yerlerinde bu var (OnboardingFlow:239, BalancesView:33), ama DashboardView:62 gibi yerlerde eksik.

---

## 9. Uygulama Planı (Token Sistemi Mimarisi)

### 9.1 Yeni dosya yapısı

```
Groopay/DesignSystem/
  Theme/
    ThemeColor.swift      // Tüm renk token'ları, light/dark çiftleri
    ThemeFont.swift        // Tip ölçeği, Dynamic Type helper
    ThemeSpacing.swift     // 8pt grid token'ları
    ThemeRadius.swift      // sharp/soft/rounded/full
    ThemeShadow.swift      // Nötr gölge kademesi
  Components/
    GroupCard.swift        // GradientAvatar İÇERMEZ — solid/düz avatar
    Avatar.swift           // Solid palet avatar (sadece emoji/rengi olan gruplar ince gradient)
    ButtonStyles.swift     // PrimaryButton (solid brand), SecondaryButton (outline), CTAButton (accent)
    Skeleton.swift         // Dark mode uyumlu shimmer
    ...
```

### 9.2 Geçiş stratejisi

1. **Yeni token'ları tanımla** (ThemeColor.swift vb.) — mevcut Color+Theme'e DOKUNMA.
2. **`typealias` geçiş katmanı** — eski token isimlerini yeni token'lara bağla, build kırılmadan taşı.
3. **View'ları tek tek migration** — GroupsListView → DashboardView → AddExpenseView → BalancesView → PaywallView → OnboardingFlow.
4. **Eski token'ları kaldır** — Color+Theme.swift, Shadow+Theme.swift, Radius.swift sil.
5. **Dark mode QA** — her ekran light/dark test.

---

## 10. Karar Bekleyen: Renk Yönü Seçimi ⬇️

Bu belge şu an **tamamlanmamıştır.** Yukarıdaki tüm bölümler (tipografi, spacing, radius, gölge, motion) hangi renk yönü seçilirse seçilsin aynı kalacak şekilde yazıldı. Ama renk token'ları (`brand`, `accent`, `background` vb.) seçilen yöne göre finalize edilecek.

**Lütfen aşağıdaki iki yönden birini seç:**

| | Yön A: Derin Lacivert + Bakır | Yön B: Sıcak Nötr + Ada Çamı |
|---|---|---|
| **His** | "Paranız emin ellerde" — kurumsal, sıcak | "Her şey şeffaf, her şey net" — modern, cesur |
| **Gradyan** | 1 yerde (dashboard hero), aynı aile ton geçişi | Hiçbir yerde |
| **Risk** | "Fazla banka" algısı (fintech değil banka gibi) | "Fazla sade" algısı (karakter eksikliği) |
| **Farklılaşma** | Splitwise/Revolut'tan ayrışır, daha premium | Monzo/Revolut çizgisine yakın, daha fintech |
| **Özgünlük** | Lacivert+bakır kombinasyonu az kullanılır → akılda kalır | Nötr+tek yeşil sık kullanılır → uygulama ikonu/ismi öne çıkar |

**Seçiminizi söyleyin** (örn: "Yön A" veya "Yön B"), DESIGN.md'yi seçilen paletle finalize edip repoya ekleyeyim. İsterseniz hibrit bir yön de konuşabiliriz (örn: Yön A'nın lacivertini + Yön B'nin gradiansız kuralını).
