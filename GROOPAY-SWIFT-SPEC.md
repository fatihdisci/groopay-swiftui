# Groopay — SwiftUI Native Rebuild Spec

> Karar (Haziran 2026): Groopay istemcisi React Native/Expo'dan **native SwiftUI**'a taşınıyor.
> **Backend AYNEN korunuyor:** Supabase (DB + RLS + SECURITY DEFINER RPC'ler + Edge Functions) + RevenueCat (webhook dahil).
> Yalnızca istemci sıfırdan yazılıyor. Bu, mevcut güvenlik ve para mimarini hazır getirir.
> Hedef: iOS-only. Android yok.

---

## 0. Temel Karar Tablosu

| Katman | RN/Expo (eski) | SwiftUI (yeni) | Not |
|---|---|---|---|
| UI | RN + Expo Router | SwiftUI + `NavigationStack` / `TabView` | Deployment target **iOS 17.0** (`@Observable`, modern SwiftUI). İstersen 16'ya inilebilir. |
| State | Zustand + React Query | `@Observable` ViewModel + `@MainActor` + async/await | React Query'nin yerini manuel cache + `.task`/`.refreshable` alır |
| Backend | Supabase JS | **Supabase Swift SDK** (`supabase-community/supabase-swift`) | Aynı proje ref, aynı tablolar, aynı RPC'ler |
| Auth | Supabase anonim + web OAuth | Supabase anonim + **native Sign in with Apple** (`AuthenticationServices`) | Native modal → eski web OAuth edge case'leri biter |
| IAP | RevenueCat RN SDK | **RevenueCat iOS SDK** (`purchases-ios`) | Webhook ve `profiles.user_pro` AYNEN. StoreKit 2 altında çalışır |
| i18n | i18next (tr.json/en.json) | **String Catalog** (`Localizable.xcstrings`) | TR + EN. Default tr |
| Para | parseMoneyInputToMinor (TS) | Swift port: `Int` minor units + `Decimal` görüntüleme | ASLA `Double` |
| Realtime | Supabase channel | Supabase Swift Realtime | Bakiye/aktivite/IBAN broadcast |
| Push | Expo Push | APNs + `send-push` Edge Function (revize) | Faz 8 |
| Fontlar | Plus Jakarta Sans + Inter | Aynı `.ttf` dosyaları bundle'a | `UIAppFonts` Info.plist |
| İkonlar | Ionicons | **SF Symbols** | Aşağıda eşleme tablosu |
| CI/Build | EAS Build + EAS Submit | **Xcode Archive → Distribute** (veya Xcode Cloud) | EAS capability-sync sorunu tamamen biter |

**Sabitler (değişmiyor):**
- Bundle ID: `com.groopay.app`
- App Store Connect App ID: `6776313459`
- Apple Team: `8XPP7Z37GF`
- Supabase project ref: `dtlnujqtwlncwrxunihj`
- RevenueCat product: `com.groopay.app.userpro` (User Pro, aylık)

---

## 1. Değişmeyen Mimari Kurallar (KRİTİK — backend ile birebir)

Bunlar CLAUDE.md'den taşınıyor ve SwiftUI'da da aynen geçerli. Backend değişmediği için bunların çoğu "bedava" gelir:

1. **Para — ASLA float.** Hesap `Int` minor unit (kuruş). Postgres'te `numeric(14,2)`. Görüntüleme `Decimal` + `NumberFormatter`. `Double` kullanımı yasak.
2. **Para birimleri ASLA toplanmaz/çevrilmez.** Her para birimi ayrı hesaplanır. Trend/kategori/dashboard tek para birimi bazında. Dominant otomatik belirlenir.
3. **Bakiye türetilmiştir, saklanmaz.** `expenses + splits + confirmed settlements`'tan para birimi bazında hesaplanır.
4. **IBAN hiçbir tabloda kalıcı saklanmaz.** Sadece Realtime broadcast channel ile anlık iletilir.
5. **Tüm hassas yazma işlemleri SECURITY DEFINER RPC + `auth.uid()` kontrolü.** İstemci doğrudan tablo yazamaz (RLS dar). Swift istemci sadece mevcut RPC'leri çağırır:
   - `add_expense_with_splits`, `update_expense_with_splits`, `delete_expense`
   - `add_settlement`, `confirm_settlement`, `reject_settlement`
   - `create_group_with_limit`, `delete_group`, `remove_member`, `transfer_ownership`
   - `preview_invite`, `preview_ghosts`, `join-via-invite` (Edge Function)
6. **Grup limiti 5** (demo hariç) — `create_group_with_limit` server-side enforce eder. İstemci sadece RPC döndürdüğü hatayı gösterir.
7. **Hayalet üye:** `group_members.user_id = NULL`. Claim → aynı satıra `user_id` yazılır (RPC ile).
8. **FX:** Masraf orijinal para biriminde saklanır; çevrim sadece görüntüleme (canlı kur, kaydedilmez).
9. **Pro entitlement sunucuda:** `profiles.user_pro`. İstemci sadece okur. Webhook yazar. `hasProAccess` = sadece `user_pro`. Group Pro UI yok (kod backend'de duruyor).
10. **RLS `auth.uid()` JWT `sub`'tan gelir.** Supabase Swift SDK oturum açınca JWT otomatik gönderilir → `auth.uid()` dolu olur. RN'deki "iki client" hilesine gerek YOK; Swift SDK tek client'ta doğru davranır (Faz 1'de doğrula).

---

## 2. Para Birimi Kısıtı (taşınıyor)

- `numeric(14,2)` → sadece 2-ondalıklı para birimleri aktif (TRY, USD, EUR, GBP, vb. — 18 adet).
- JPY/KRW (0 ondalık) ve KWD/BHD/OMR/TND (3 ondalık) UI'da gizli. Integer-minor-unit migration (Faz 9) sonrası açılır.
- Swift `getDecimals(currency)` fonksiyonu yine de doğru çalışmalı (gizli olsalar bile).

---

## 3. Tasarım Sistemi (birebir taşınıyor)

### 3.1 Renkler — `Color+Theme.swift`
```
background      #F7F6FF   // off-white, mor tonlu
surface         #FFFFFF
surfaceTinted   #EFEEFC   // section bg
primary         #4F46E5
gradientStart   #4F46E5
gradientEnd     #7C3AED
debt (borç)     #F43F5E   // rose
credit (alacak) #10B981   // emerald
warning         #F59E0B   // amber
textPrimary     #0D0D14
textSecondary   #6B7280
textTertiary    #9CA3AF
```
Header gradient (grup detay): `#6366F1 → #8B5CF6` (daha açık, avatar moruyla kontrast).
Gölge: **mor tintli** (`primary` rengi, `opacity ~0.04–0.12`), nötr siyah değil.

### 3.2 Tipografi — `Font+Theme.swift`
- Display / rakam: **Plus Jakarta Sans** (600/700/800)
- Body / UI: **Inter** (400/500/600)
- Poppins KULLANMA.
- `.ttf` dosyalarını bundle'a ekle + `Info.plist > UIAppFonts`. `Font.custom("PlusJakartaSans-Bold", size:)` helper'ları yaz.
- **Dynamic Type:** custom font'larda `.font(.custom(... relativeTo: .body))` kullan (erişilebilirlik).

### 3.3 Şekil
- Radius: kart **16**, buton **12–14**, pill **full** (`Capsule()`).
- Spacing 4px grid: 4/8/12/16/20/24/32/40/48/64.
- Gradient avatarlar, gradient FAB, gradient hero kartlar.

### 3.4 Para formatı + yön
- `formatAmount(_ minor: Int, currency: String) -> String`: `NumberFormatter`, `locale = tr_TR`, currency style, sembol (₺/€/$), binlik nokta + ondalık virgül. `₺591,63`, `€50,00`.
- **Yön bilgisi = renk + kelime** ("borçlusun" kırmızı / "alacaklısın" yeşil). **İşaret (+/−) KULLANMA.**

### 3.5 SF Symbols eşlemesi (Ionicons → SF Symbol)
| İşlev | Ionicons | SF Symbol |
|---|---|---|
| Gruplar | people | `person.2.fill` |
| Panel | stats-chart | `chart.bar.fill` |
| Aktivite | time | `clock.fill` |
| Hesap | person | `person.crop.circle.fill` |
| Masraf ekle | add | `plus` |
| Üye ekle | person-add | `person.badge.plus` |
| Davet linki | link | `link` |
| Ödedim | checkmark | `checkmark.circle.fill` |
| IBAN iste | card | `creditcard.fill` |
| Kategori | pie-chart | `chart.pie.fill` |
| Pro/elmas | diamond | `diamond.fill` |
| Geri | chevron-back | `chevron.left` |
> SVG ikon yok; SF Symbols native ölçeklenir, tema rengi alır.

### 3.6 UI/UX kuralları (taşınıyor)
- Min dokunma alanı **44pt**.
- Büyük harf: `textTransform: uppercase` yerine `.uppercased(with: Locale(identifier: "tr_TR"))` — Türkçe İ/ı doğru olsun.
- `prefers-reduced-motion` → `@Environment(\.accessibilityReduceMotion)` ile animasyonları kapat.
- Boş durumlar (empty state) her zaman gösterilsin.
- Tüm tıklanabilirler `Button`/`.contentShape(Rectangle())` ile net dokunma alanı.

---

## 4. Ekran Envanteri (RN'deki tüm ekranlar)

```
GroopayApp (entry)
 └─ RootView (auth gate)
     ├─ OnboardingFlow            // 3 slide, gradient
     ├─ AuthView                  // anonim + Sign in with Apple
     └─ MainTabView (4 tab)
         ├─ DashboardTab          // Panel: hero + stats + kategori + Pro analitik (bar chart)
         ├─ GroupsTab
         │   ├─ GroupsListView    // liste + genel bakiye + Yeni/Katıl (sheet)
         │   ├─ NewGroupSheet
         │   ├─ JoinGroupView     // kod → preview (ghost claim) → join
         │   └─ GroupDetailView   // tab: Masraflar | Bakiyeler, gradient header, FAB
         │       ├─ AddExpenseView    // Wise numpad, split (equal/custom/subset), para birimi, tarih
         │       ├─ MembersView       // hayalet ekle (founder), davet linki, üye yönetimi
         │       ├─ EditGroupView     // ad/açıklama/emoji/renk, sil, ayrıl, devret
         │       └─ SettlementFlow    // ödedim → onay, IBAN realtime broadcast
         ├─ ActivityTab           // tüm gruplar akışı + arama (Pro-gated)
         └─ AccountTab            // profil, dil, Pro, restore, hesap silme, veri dışa aktarma
     └─ PaywallView (modal)       // App Store uyumlu (bkz. §6)
```

---

## 5. BUILD — Kesin Çözümler (EAS sorununun karşılığı)

EAS'in `EXPO_NO_CAPABILITY_SYNC=1` gerektiren capability-sync çakışması **native Xcode'da tamamen ortadan kalkar**. Ama yerine yeni tuzaklar gelir; hepsini baştan kapat:

1. **Signing:** Xcode > Signing & Capabilities > **Automatically manage signing** açık. Team `8XPP7Z37GF`. Bundle ID `com.groopay.app` (zaten kayıtlı, App ID `6776313459`).
2. **Capabilities (Xcode + Apple Developer portal'da AYNI olmalı):**
   - **In-App Purchase** (zorunlu — RevenueCat)
   - **Sign in with Apple** (native auth)
   - **Push Notifications** (Faz 8'de aktifleşecekse şimdiden ekle)
   - **Associated Domains** (`applinks:groopay.app` — davet deep link / universal link)
3. **Build sürümü:** `MARKETING_VERSION` (örn 1.0.0) + `CURRENT_PROJECT_VERSION` (build no). Her submit'te build no artır.
4. **Dağıtım (solo, basit yol):** Xcode > Product > **Archive** > Distribute App > App Store Connect > Upload. Transporter gerekmez.
5. **Alternatif CI:** Xcode Cloud (Apple-native, EAS yerine). İstersen Faz 8'de kurulur; başta gereksiz.
6. **`.gitignore`:** `*.xcuserstate`, `DerivedData/`, `*.mobileprovision`, `GoogleService-Info.plist` (varsa), gizli `Secrets.xcconfig`.
7. **Gizli anahtarlar:** Supabase anon key + RevenueCat public SDK key → `Secrets.xcconfig` (commit edilmez) veya Info.plist build setting. Anon key zaten public'tir ama yine de xcconfig'te tut.

> Sonuç: tek bir `Archive → Upload` akışı. Capability senkron hatası yok, EAS kuyruğu yok.

---

## 6. IAP / PAYWALL — Kesin Çözümler (Build 5 reddinin karşılığı)

Build 5'in reddedildiği maddeler tekrar etmesin diye paywall ve IAP **baştan kurala uygun** kurulur. RevenueCat iOS SDK kullan (webhook + `profiles.user_pro` aynen çalışır).

### 6.1 Paywall zorunlu içerik (Guideline 3.1.2 — bunlar eksikse RED)
- [ ] Abonelik **adı**: "Groopay User Pro"
- [ ] **Fiyat** + **süre**: "₺X / ay" (RevenueCat `StoreProduct.localizedPriceString` — hardcode etme)
- [ ] **Otomatik yenileme** açıklaması: "Abonelik dönem sonunda otomatik yenilenir, iptal edilmezse..." metni
- [ ] **Privacy Policy** linki (Vercel) — tıklanabilir
- [ ] **Terms of Use / EULA** linki (kendi EULA'n veya Apple standart EULA) — tıklanabilir
- [ ] **Restore Purchases** butonu (zorunlu)
- [ ] Vaporware YOK — sadece çalışan 3 özellik: tek panel (Dashboard), sınırsız grup, kategori analizi
- [ ] **Platform-nötr dil** — "App Store/Google Play" gibi platform referansı YOK (B121). "mağaza" yerine nötr ifade.

### 6.2 IAP'ın "products yüklenmiyor" tuzağı
- App Store Connect'te ürün `com.groopay.app.userpro` durumu **"Ready to Submit"** olmalı (Missing Metadata / Waiting değil).
- **Paid Apps Agreement** + **License Agreement** kabul edilmiş olmalı (License zaten kabul edildi ✅; Paid Apps'i kontrol et).
- RevenueCat dashboard'da product + entitlement + offering bağlı.
- **StoreKit local testing:** `.storekit` configuration file ekle → sandbox'sız simülatörde paywall test et. Sandbox tester ile gerçek satın alma akışını TestFlight'ta dene.
- Subscription Group + lokalize ekran adı/açıklaması doldurulmuş olmalı (boşsa "Missing Metadata").

### 6.3 Account deletion (Guideline 5.1.1(v) — zorunlu)
- Hesap > "Hesabımı Sil" → mevcut `delete-account` Edge Function'ı çağır. Onay diyaloğu + geri dönüşsüz uyarı. (Bu zaten var, Swift'te bağla.)

### 6.4 Auth tamlığı (Guideline 2.1)
- Anonim auth + Sign in with Apple. Token yenileme native SDK'da otomatik (RN'deki `autoRefreshToken: false` + manuel 50dk refresh hilesine GEREK YOK — Supabase Swift SDK kendi yönetir). Faz 1'de production'da doğrula.
- Sign in with Apple zorunluluğu: başka 3. parti sosyal login eklenirse Apple ile giriş de sunulmalı. Şimdilik anon + Apple yeterli.

---

## 7. Önceki Buglardan Öğrenilenler → SwiftUI Önlemi

| Eski bug | Kök neden | SwiftUI önlemi |
|---|---|---|
| simplifyDebts kuruş crash (B18) | float yuvarlama | `Int` minor unit + birim testleri (Faz 2'de portla) |
| Para formatı tutarsızlığı (B63) | yer yer `toFixed` | Tek `formatAmount()` — her yerde. Lint kuralı: ham string format yasak |
| Dashboard para birimi karışması (B54-57) | para birimleri toplanmış | Tip seviyesinde ayır: `Balance` her zaman `[Currency: Int]` |
| Header mimarisi (B42, B45-46) | nested layout + tab/stack çakışması | SwiftUI: her tab kendi `NavigationStack`'ine sahip; `.toolbar` tutarlı. RN'deki "_layout" kâbusu yok |
| add-expense regresyon (B47-53) | split type uygulanmıyordu | `enum SplitType` + tek `computeSplits()` fonksiyonu + test |
| Profil adı cache (B5, B79) | manuel invalidate kaçtı | `@Observable` store tek kaynak; isim değişince publish |
| i18n mükerrer key (B5.4) | JSON çakışması | String Catalog derleme zamanı kontrol eder; mükerrer key build'de yakalanır |
| RevenueCat Expo Go'da çalışmıyor | native module | Native zaten; `.storekit` ile simülatörde test edilir, DEV toggle `#if DEBUG` |
| Webhook iptal/expiry (B67) | event eksikti | Backend AYNEN korunuyor — bu fix zaten yerinde |

---

## 8. Klasör Yapısı (öneri)

```
Groopay/
  App/
    GroopayApp.swift
    RootView.swift
  DesignSystem/
    Color+Theme.swift
    Font+Theme.swift
    Shadow+Theme.swift
    GradientAvatar.swift
    PrimaryButton.swift  GradientFAB.swift  Card.swift
  Core/
    Supabase/
      SupabaseClient.swift        // shared client
      RPC.swift                    // tüm RPC çağrıları (typed)
      Realtime.swift
    Models/                        // Codable: Group, Member, Expense, Split, Settlement, Profile, Activity
    Finance/                       // money, split, balance, simplify (PURE) + Tests
    Localization/  Localizable.xcstrings
    Auth/  AuthStore.swift (@Observable)
    Purchases/  PurchasesManager.swift (RevenueCat)
  Features/
    Onboarding/  Auth/  Groups/  GroupDetail/  AddExpense/  Members/
    Dashboard/  Activity/  Account/  Paywall/  Settlement/
  Resources/  Fonts/  Assets.xcassets
  Config/  Secrets.xcconfig (gitignore)  Groopay.storekit
GroopayTests/                       // XCTest — finance pure functions
```

---

## 9. Çalışma Tarzı (taşınıyor)

- Her oturum başında: `SESSION-OZET-SWIFT.md` + bu spec + faz planını oku.
- Migration gerekirse (nadiren — backend hazır): SQL'i önce ver, Fatih çalıştırsın, ✅ sonra devam.
- Her önemli iş sonrası: `BUGFIX-SWIFT.md`'ye kaydet (S1, S2… numaralı) + git commit + push.
- Prompt sonunda: **build temiz mi** (`xcodebuild` veya Cmd+B), test adımları, ne değişti özeti.
- Pro/Flash model kullanımı: yeni feature/RPC/güvenlik/çoklu dosya → Pro; tek dosya UI/i18n/küçük düzeltme → Flash.

---

## 10. Acceptance — "Bitti" Tanımı (her faz)
- Build temiz (uyarı kabul, hata yok).
- İlgili ekran simülatörde çalışıyor.
- TR locale doğru (İ/ı, virgül-ondalık).
- Para asla float; `formatAmount` her yerde.
- Hassas yazma RPC üzerinden; doğrudan tablo yazımı yok.
- Faz kabul kriterleri (bkz. FAZ-PLAN) geçti.
