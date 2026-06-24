# Groopay Tasarım Sistemi — AI Tell Denetim Raporu

> Tarih: 24 Haziran 2026
> Kapsam: Tüm DesignSystem/ + ana feature view'ları + GROOPAY-SWIFT-SPEC.md
> Amaç: "AI ile üretilmiş / generic" görünümünü sistematik olarak teşhis etmek ve para uygulaması güven perspektifinden önceliklendirmek.

---

## P0 — Kimlik (Identity)

Bu maddeler uygulamanın **herhangi bir para uygulaması mı yoksa Groopay mi** olduğunu ayırt ettiren sinyalleri yok ediyor. Kullanıcı 2 saniyede "bu generic" diyorsa sebebi bunlar.

### P0.1 — İndigo-mor gradyan her yerde

| Konum | Dosya:Satır | Açıklama |
|---|---|---|
| Renk tanımı | `Color+Theme.swift:7-9` | `primaryTheme = #4F46E5`, `gradientStart = #4F46E5`, `gradientEnd = #7C3AED` |
| GradientAvatar varsayılanı | `GroupComponents.swift:40` | `return [.gradientStart, .gradientEnd]` — avatar fallback |
| GradientButtonLabel | `GroupComponents.swift:58-63` | Buton arka planı yatay gradyan |
| Onboarding arka plan | `OnboardingFlow.swift:47-52` | Tam ekran `[.gradientStart, .gradientEnd]` |
| Dashboard genel durum kartı | `DashboardView.swift:186-193` | `#4F46E5 → #5B54E8` gradyan kart |
| Dashboard empty-state buton | `DashboardView.swift:127-131` | `[.gradientStart, .gradientEnd]` CTA |
| Dashboard free teaser | `DashboardView.swift:396-400` | `[.gradientStart, .gradientEnd]` CTA |
| Balances self-summary kartı | `BalancesView.swift:117-123` | `[.gradientStart, .gradientEnd]` bakiye özet kartı |
| Paywall hero arka plan | `PaywallView.swift:96-108` | 3-duraklı `#312E81 → #6D28D9 → #A855F7` |
| Paywall CTA butonu | `PaywallView.swift:306-311` | `[.gradientStart, .gradientEnd]` |

**Neden sorun:** `#4F46E5 → #7C3AED` indigo-mor gradyanı, 2023-2026 arası AI kod asistanlarının (Claude, GPT, Copilot) "modern UI" için ezberlediği varsayılan renk paletidir — para uygulaması güveni soğuk/mesafeli tonlar ve tek bir akılda kalıcı accent üzerine kurulur, "bir AI'nın ürettiği belli" hissi güveni sıfırlar.

### P0.2 — Inter body fontu

| Konum | Dosya:Satır | Açıklama |
|---|---|---|
| Body font tanımı | `Font+Theme.swift:36` | `private static let bodyFontName = "Inter-Regular"` |
| Tüm body kullanımları | Proje geneli | `.font(.body(...))` her yerde Inter render eder |

**Neden sorun:** Inter, 2024 sonrası AI modellerin "sana güzel bir UI yapayım" prompt'una verdiği ezber yanıttır — Figma'nın varsayılan fontu olması + her AI'ın önermesi, uygulamanın tipografi kararının bilinçli değil otomatik alındığını bağırır; para uygulamasında tipografi güvenin temel taşıyıcısıdır.

### P0.3 — Mor-tintli gölgeler (her kartta aynı)

| Konum | Dosya:Satır | Açıklama |
|---|---|---|
| Gölge modifier tanımı | `Shadow+Theme.swift:8-9` | `Color.primaryTheme.opacity(0.06)` — mor renkli gölge |
| GroupCard | `GroupsListView.swift:163` | `.purpleTintedShadow()` |
| SkeletonCard | `Skeleton.swift:94` | `.purpleTintedShadow()` |
| Balance raw/simplified listeler | `BalancesView.swift:154,259,260,336` | `.purpleTintedShadow()` her kartta |
| Balances self-summary | `BalancesView.swift:125` | `.purpleTintedShadow(radius: 18, y: 9)` |
| Dashboard tüm kartlar | `DashboardView.swift:196,256,409,504,549,679` | `.purpleTintedShadow()` 6 farklı yerde |
| Paywall pricing card | `PaywallView.swift:253` | `.purpleTintedShadow(radius: 18, y: 8)` |
| Paywall feature card | `PaywallView.swift:198` | `.purpleTintedShadow(radius: 12, y: 6)` |
| AddExpense detaylar | `AddExpenseView.swift:453` | `.purpleTintedShadow(radius: 8, y: 3)` |
| AddExpense numpad tuşları | `AddExpenseView.swift:267` | `.purpleTintedShadow(radius: 6, y: 2)` |
| Spec kararı | `GROOPAY-SWIFT-SPEC.md:83` | "Gölge: mor tintli (primary rengi, opacity ~0.04–0.12), nötr siyah değil" |

**Neden sorun:** Gerçek dünyada gölgeler ışık kaynağına göre nötr-gridir, renkli gölge "tasarım aracı efekti"dir — para uygulamasında her kartın aynı mor gölgeyle yükselmesi, yapay bir oyuncak hissi verir ve kartlar arası görsel hiyerarşiyi yok eder; gölgenin rengi değil derinliği bilgi taşımalıdır.

### P0.4 — Mor-tintli arka plan + mor-tintli surface

| Konum | Dosya:Satır | Açıklama |
|---|---|---|
| Arka plan rengi | `Color+Theme.swift:4` | `background = #F7F6FF` (off-white, mor tonlu) |
| Surface tint | `Color+Theme.swift:6` | `surfaceTinted = #EFEEFC` (açık mor) |
| Spec kararı | `GROOPAY-SWIFT-SPEC.md:69` | "background #F7F6FF — off-white, mor tonlu" |
| Tüm ekranlar | `GroupsListView.swift:11`, `AddExpenseView.swift:148`, `DashboardView.swift:23`, `PaywallView.swift:93` | Hepsi `Color.background.ignoresSafeArea()` |

**Neden sorun:** Arka planın hafif mor tonlu olması (L* ≈ 97, a* ≈ +3) "AI'ın safe off-white'ı"dır — gerçek finans uygulamaları (Apple Wallet, Revolut, Monzo, Wise) nötr gri-beyaz veya koyu arka plan kullanır; mor-tintli arka plan uygulamanın "para" değil "meditasyon/wellness" kategorisinde algılanmasına yol açar.

---

## P1 — Tutarlılık (Consistency)

Bu maddeler ilk bakışta fark edilmez ama kullanıcı "bir şeyler garip" hisseder. Para uygulamasında tutarlılık = güvenilirlik.

### P1.1 — Aynı gradyanın farklı tonlarda tekrarı (sıfır hiyerarşi)

| Konum | Dosya:Satır | Renkler |
|---|---|---|
| Ana gradyan | `Color+Theme.swift:8-9` | `#4F46E5 → #7C3AED` |
| Dashboard kart | `DashboardView.swift:188-189` | `#4F46E5 → #5B54E8` (manuel override, daha koyu) |
| Paywall hero | `PaywallView.swift:98-100` | `#312E81 → #6D28D9 → #A855F7` (3-durak, daha koyu) |
| Spec header gradyan | `GROOPAY-SWIFT-SPEC.md:82` | `#6366F1 → #8B5CF6` (daha açık, "avatar moruyla kontrast") |

**Neden sorun:** Aynı mor ailesinden 4 farklı gradyan varyantı bilinçli bir sistem değil "her ekran için ayrı deneme-yanılma" izlenimi verir — para uygulaması matematiksel tutarlılık ister, her sayfada farklı mor tonu görmek "bu şirketin tasarımcısı yok" sinyalidir.

### P1.2 — Radius karnavalı

| Değer | Kullanım Yerleri |
|---|---|
| 8 | `SkeletonBlock.swift:51` (varsayılan cornerRadius) |
| 10 | `PaywallView.swift:181` (feature icon) |
| 12 | `AddExpenseView.swift:516`, `DashboardView.swift:217,402`, `BalancesView.swift:110` |
| 14 | `ThemeRadius.button`, `AddExpenseView.swift:266,401,404,595,690` |
| 16 | `ThemeRadius.card`, `GroupsListView.swift:162`, `Skeleton.swift:93`, `DashboardView.swift:255,387,408,496,548,679` |
| 18 | `PaywallView.swift:118,120` (app logo) |
| 20 | `BalancesView.swift:124`, `DashboardView.swift:81 (skeleton),195` |
| 22 | `PaywallView.swift:248,250` (pricing card) |
| 34 | `BalancesView.swift:266` (GradientAvatar size) |

**Neden sorun:** 8-10-12-14-16-18-20-22-34 = 9 farklı radius değeri, sistem yok — "her view kendi beğendiğini seçmiş." Para uygulamasında tipografik ızgara gibi radius da sınırlı bir ölçeğe oturmalı; her bileşenin farklı yuvarlaklıkta olması amatör bir 3. parti component karışımı hissi verir.

### P1.3 — Spacing ızgarası yok

| Değer | Örnek Konum |
|---|---|
| 4px | `GroupsListView.swift:183`, `BalancesView.swift:270` (VF fonksiyonu grid tabanı) |
| 6px | `GroupsListView.swift:143`, `AddExpenseView.swift:198` |
| 8px | `GroupsListView.swift:46`, `Skeleton.swift:79`, birçok yerde |
| 10px | `AddExpenseView.swift:256,258,521,557`, `BalancesView.swift:138,321` |
| 12px | `GroupsListView.swift:51,71,97`, `AddExpenseView.swift:197,514` |
| 14px | `GroupsListView.swift:29,105,135`, `AddExpenseView.swift:402,486` |
| 16px | `GroupsListView.swift:160`, `BalancesView.swift:23`, `Skeleton.swift:91` |
| 18px | `DashboardView.swift:32,80,252` |
| 20px | `GroupsListView.swift:44,96`, `AddExpenseView.swift:142`, `BalancesView.swift:31` |
| 22px | `AddExpenseView.swift:130,426` |
| 24px | `AddExpenseView.swift:143` |

**Neden sorun:** Spec'te "spacing 4px grid: 4/8/12/16/20/24/32/40/48/64" yazıyor ama gerçek kodda 6, 10, 14, 18, 22 gibi değerler grid dışı — token sistemi yok, her view'da magic number. Para uygulamasında spacing tutarlılığı "hesap kitap bilen" izlenimi verir.

### P1.4 — Gradient avatar her yerde, sıfır varyant

| Konum | Dosya:Satır |
|---|---|
| Grup kartı | `GroupsListView.swift:136` |
| Ödeyen seçici | `AddExpenseView.swift:575,697` |
| Ham bakiye listesi | `BalancesView.swift:265` |
| Onboarding demo | `OnboardingFlow.swift:279` |

**Neden sorun:** Her üye/grubun aynı gradyan circle içinde render edilmesi görsel monotonluk yaratır — fotoğraf yükleme olmasa bile en azından farklı dolgu stilleri (solid, soft gradient, initial) arasında geçiş olmalı; para uygulamasında kişileri ayırt edebilmek kritiktir.

### P1.5 — Karanlık mod desteği sıfır

| Konum | Dosya:Satır |
|---|---|
| Tüm renkler | `Color+Theme.swift:3-15` — hepsi hex başlatıcı, light/dark ayrımı yok |
| Skeleton shimmer | `Skeleton.swift:17-19` — `.white.opacity(...)` sadece light mode'da çalışır |
| Paywall | `PaywallView.swift:196` — `.white.opacity(0.92)` dark mode'da patlar |
| Onboarding buton | `OnboardingFlow.swift:296` — `.background(.white)` dark mode'da görünmez olur |
| Tüm gölgeler | `Shadow+Theme.swift:9` — mor gölge dark mode'da görünmez |

**Neden sorun:** iOS kullanıcılarının ~40%'ı dark mode kullanır — dark mode'u olmayan bir finans uygulaması "özensiz" ve "yarım" izlenimi verir; gece hesap kontrol eden kullanıcı için erişilebilirlik ve güven sorunudur.

---

## P2 — Cila (Polish)

Bu maddeler uygulama "idare eder" seviyesinde. Kullanıcı tek tek fark etmez ama toplamda " premium değil" hissi verir.

### P2.1 — Plus Jakarta Sans display fontu

| Konum | Dosya:Satır | Açıklama |
|---|---|---|
| Display font tanımı | `Font+Theme.swift:35` | `"PlusJakartaSans-Regular"` |

**Neden sorun:** PJS, Inter kadar olmasa da AI önerilerinde sık çıkar — para uygulaması için rakamların okunabilirliği ve güven hissi kritiktir; SF Pro (native) veya tabular-figures destekleyen bir font daha güvenli para hissi verir.

### P2.2 — Onboarding tam ekran gradyan

| Konum | Dosya:Satır | Açıklama |
|---|---|---|
| Arka plan | `OnboardingFlow.swift:47-52` | Tam ekran indigo-mor gradyan |

**Neden sorun:** Tam ekran mor gradyan onboarding "2024 AI template" klişesidir — onboarding, marka kimliğinin en güçlü ilk izlenimi olmalıdır; tek renkli koyu arka plan + tek accent daha güçlü ve daha az "template" durur.

### P2.3 — Skeleton shimmer light mode'a kilitli

| Konum | Dosya:Satır | Açıklama |
|---|---|---|
| Shimmer renkleri | `Skeleton.swift:17-19` | `.white.opacity(0) → .white.opacity(0.55) → .white.opacity(0)` |

**Neden sorun:** Shimmer efekti sadece açık arka planda çalışır — dark mode'da görünmez olur; yükleme anı, kullanıcının uygulamanın "canlı" olduğunu gördüğü kritik bir güven anıdır.

### P2.4 — Paywall hero'da 3-duraklı gradyan + floating logo

| Konum | Dosya:Satır | Açıklama |
|---|---|---|
| Hero arka plan | `PaywallView.swift:96-108` | Üç duraklı koyu mor gradyan |
| Logo animasyonu | `PaywallView.swift:124` | `scaleEffect(animateHero ? 1.04 : 1)` floating |

**Neden sorun:** "Koyu gradyan hero + ortalanmış logo + floating scale animasyonu" Kombinasyonu 2025 AI paywall template'idir — Apple'ın kendi Human Interface Guidelines'ı paywall'larda sade ve bilgi-odaklı tasarımı önerir.

### P2.5 — Capsule/pill aşırı kullanımı

Her yerde `clipShape(Capsule())`: `GroupsListView.swift:185,225`, `AddExpenseView.swift:234,236,346,394,545`, `BalancesView.swift:190,205,228,233,375`, `DashboardView.swift:448,527,580,712`, `PaywallView.swift:155`.

**Neden sorun:** AI modelleri "modern" = capsule/pill ezberine sahiptir — para uygulamasında aşırı yuvarlak hatlar ciddiyetsizlik hissi verir; status pill'leri için uygun olsa da buton, chip, ve etiketlerde çeşitlilik gerekir.

### P2.6 — Para tutarı font büyüklüğü şişmesi

| Konum | Dosya:Satır | Boyut |
|---|---|---|
| Masraf girişi | `AddExpenseView.swift:200` | `.display(52, weight: .extraBold)` |
| Paywall fiyat | `PaywallView.swift:214` | `.display(34, weight: .extraBold)` |
| Dashboard bakiye | `DashboardView.swift:211` | `.display(18, weight: .extraBold)` |
| Balances özet | `BalancesView.swift:82` | `.display(20, weight: .extraBold)` |
| Onboarding sonuç | `OnboardingFlow.swift:231` | `.display(28, weight: .extraBold)` |

**Neden sorun:** Para tutarlarının her yerde farklı boyutta ve hep `extraBold` olması tipografik bir hiyerarşi olmadığını gösterir — finans uygulamaları rakamları belirli bir ızgarada tutar; bağıran rakamlar güven değil "pazarlık" hissi verir.

### P2.7 — Animasyonlarda .spring(response: 0.35) kopyala-yapıştır

| Konum | Dosya:Satır |
|---|---|
| Dashboard filter | `DashboardView.swift:62` |
| Dashboard donut | `DashboardView.swift:431` |
| Dashboard activity | `DashboardView.swift:615` |
| Onboarding | `OnboardingFlow.swift:239` |

**Neden sorun:** Her etkileşimde aynı spring parametresi "animasyonlar düşünülmemiş, kopyala-yapıştır" izlenimi verir — para uygulamasında animasyonlar geri bildirim amaçlıdır, dekoratif değil.

### P2.8 — surfaceTinted (#EFEEFC) aşırı kullanımı

Her alternatif satır, chip arka planı, etiket, skeleton `Color.surfaceTinted` kullanıyor: `Skeleton.swift:61,75`, `DashboardView.swift:346,447,527,585,711`, `BalancesView.swift:374`, `AddExpenseView.swift:181,515`.

**Neden sorun:** Tek bir ara tonun her yerde kullanılması görsel monotonluk yaratır — Apple'ın HIG'ı `systemGray5`/`systemGray6` gibi en az 2-3 ara yüzey tonu önerir.

---

## Özet Matris

| Öncelik | Sayı | Tema |
|---|---|---|
| **P0** | 4 | İndigo-mor gradyan, Inter, mor gölge, mor arka plan — uygulamanın DNA'sını AI generic yapıyor |
| **P1** | 5 | Gradyan varyantları, radius karnavalı, spacing grid yok, avatar monotonluğu, dark mode yok — tutarlılık/güven zaafı |
| **P2** | 8 | PJS display font, onboarding gradyan, shimmer light-only, paywall hero, capsule aşırı, font büyüklüğü, spring copy-paste, surfaceTinted aşırı — cila eksikliği |

**Toplam: 17 AI tell tespit edildi.** Bunların hepsi bir kerede çözülmek zorunda değil; P0'ları çözmek uygulamanın kimliğini tek başına dönüştürür. P1'ler token sistemi kurulumuyla birlikte çözülür. P2'ler zaman içinde cilalanır.
