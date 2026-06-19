# Groopay

Groopay, grup harcamalarını farklı para birimlerini birbirine karıştırmadan takip eden, borçları sadeleştiren ve ödeme sürecini yöneten native iOS uygulamasıdır.

Bu depo, Expo/React Native istemcisinin yerine geliştirilen SwiftUI uygulamasını, widget hedefini ve uygulamaya ait Supabase bileşenlerini içerir.

## Güncel durum

- Uygulama sürümü: **1.1.1 (build 32)**
- Platform: **iPhone, iOS 17.0+**
- Arayüz: **SwiftUI**
- Diller: **Türkçe ve İngilizce**
- Backend: **Supabase** (Auth, Postgres, RLS, RPC, Realtime ve Edge Functions)
- Satın alma: **RevenueCat + StoreKit 2**
- Bildirim: **APNs + Supabase Edge Function**
- Widget: para birimi bazında toplam borç ve alacak özeti

Son sürümde ödeme sonrasında verinin yenilenmesi iyileştirildi ve grup masraf bildirimlerinin güvenilirliği artırıldı.

## Özellikler

- Anonim kullanım ve Apple ile giriş
- Grup oluşturma, davet koduyla katılma ve üye yönetimi
- Hesabı olmayan kişiler için hayalet üye oluşturma ve üyeliği sonradan sahiplenme
- Eşit, özel tutarlı veya seçili kişiler arasında masraf bölüştürme
- Masraf ekleme, düzenleme ve silme
- Para birimi bazında bakiye ve borç sadeleştirme
- Tek akıştan “Ödedim” bildirimi, ödeme onayı/reddi ve WhatsApp üzerinden IBAN isteme
- Supabase Realtime ile grup verilerini güncel tutma
- Dashboard, kategori analizi, aktivite akışı ve filtreleme
- RevenueCat üzerinden aylık Groopay User Pro aboneliği ve satın alımları geri yükleme
- Türkçe/İngilizce uygulama içi dil seçimi
- Veri dışa aktarma ve uygulama içinden hesap silme
- Yeni grup masrafları için push bildirimleri ve bildirime dokununca ilgili grubu açma
- Ana ekranda borç/alacak özeti gösteren orta boy widget

## Teknik yaklaşım

Para hesapları kayan noktalı türlerle yapılmaz. Tutarlar istemcide `Int` minor unit olarak tutulur; her para birimi ayrı hesaplanır ve çevrim yapılmadan gösterilir. Bakiye ayrıca saklanmaz, masraflar, paylar ve onaylanmış ödemelerden türetilir.

Hassas yazma işlemleri Supabase tarafındaki RLS kuralları ve `SECURITY DEFINER` RPC’leri üzerinden yürür. IBAN uygulama veritabanında saklanmaz. Pro erişiminin kalıcı doğruluk kaynağı `profiles.user_pro` alanıdır; RevenueCat sonucu satın alma sırasında iyimser UI güncellemesi için de kullanılır.

## Gereksinimler

- macOS ve Xcode 16 veya daha yeni bir sürüm
- iOS 17+ simülatör ya da cihaz
- Proje erişimi olan bir Supabase ortamı
- RevenueCat iOS public SDK anahtarı
- Push bildirimleri için Apple Developer üyeliği ve APNs anahtarı
- Supabase CLI (migration veya Edge Function dağıtılacaksa)

Swift Package Manager bağımlılıkları Xcode tarafından otomatik çözülür:

- `supabase-swift` 2.47.0
- `purchases-ios` 5.78.0

## Yerel kurulum

1. Depoyu klonlayın ve proje dizinine geçin.
2. Yerel ayar dosyasını oluşturun:

   ```sh
   cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
   ```

3. `Config/Secrets.xcconfig` içindeki değerleri kendi ortamınızla güncelleyin:

   ```xcconfig
   SUPABASE_URL = https:/$()/PROJECT_REF.supabase.co
   SUPABASE_ANON_KEY = sb_publishable_...
   REVENUECAT_API_KEY = appl_...
   ```

   `https:/$()/` biçimi xcconfig içinde `//` karakterlerinin yorum başlangıcı sayılmasını engeller. Yalnızca Supabase publishable/anon key kullanın; service role veya başka bir gizli sunucu anahtarını istemciye koymayın.

4. `Groopay.xcodeproj` dosyasını Xcode ile açın.
5. `Groopay` scheme’ini ve bir iPhone simülatörünü seçip çalıştırın.

`Config/Secrets.xcconfig` git tarafından izlenmez. Xcode Cloud derlemelerinde `ci_scripts/ci_post_clone.sh`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` ve `REVENUECAT_API_KEY` ortam değişkenlerinden bu dosyayı üretir.

## Satın alma testi

Yerel StoreKit testi için scheme ayarlarında `Config/Groopay.storekit` dosyasını StoreKit Configuration olarak seçin. Gerçek ürün ve abonelik durumları için RevenueCat offering, entitlement ve `com.groopay.app.userpro` ürün bağlantılarının ilgili ortamda tanımlı olması gerekir.

## Testler

Xcode’dan `Product > Test` kullanılabilir. Komut satırından uygun bir simülatör adıyla:

```sh
xcodebuild test \
  -project Groopay.xcodeproj \
  -scheme Groopay \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Test paketi para modeli ve formatlama, masraf bölüştürme, bakiye hesaplama, borç sadeleştirme, model kodlama, dashboard analitiği, lokalizasyon ve sürüm özelliklerini kapsar.

## Supabase ve push bildirimleri

Depodaki `supabase/` dizini push token tablolarını, RLS politikalarını, masraf aktivitesi trigger’ını ve APNs’e bildirim gönderen `send-push` Edge Function’ını içerir.

Bağlı proje için migration ve function dağıtımı:

```sh
npx supabase link --project-ref <project-ref>
npx supabase db push
npx supabase functions deploy send-push
```

Edge Function ortamında aşağıdaki secret’lar bulunmalıdır:

- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_PRIVATE_KEY`
- `WEBHOOK_SECRET`
- Supabase tarafından sağlanan `SUPABASE_URL` ve `SUPABASE_SERVICE_ROLE_KEY`

Migration içindeki `push_webhook_secret` Vault değeri ile Edge Function’daki `WEBHOOK_SECRET` aynı olmalıdır. Push bildirimlerini gerçek cihazda test edin; simülatör standart APNs cihaz token akışını temsil etmez.

## Proje yapısı

```text
Groopay/
  App/                 Uygulama başlangıcı, router ve tab yapısı
  Core/
    Auth/              Oturum ve Apple ile giriş
    Finance/           Para, bölüştürme, bakiye ve sadeleştirme
    Localization/      String Catalog ve dil tercihi
    Models/            Uygulama modelleri
    Notifications/     APNs kaydı ve bildirim yönlendirme
    Purchases/         RevenueCat entegrasyonu
    Supabase/          İstemci, RPC, store ve Realtime
  DesignSystem/        Renk, tipografi ve ortak bileşenler
  Features/            Ekran ve kullanıcı akışları
  Resources/           Asset catalog, fontlar ve Info.plist
GroopayWidget/          Ana ekran widget extension
GroopayTests/           Unit testler
Config/                 Build, secret şablonu ve StoreKit ayarları
supabase/               Migration, config ve Edge Function
docs/sql/               Operasyonel/tek seferlik SQL yardımcıları
AppStore/               Sürüm notları
```

## Build ve dağıtım

Uygulama hedefi `com.groopay.app`, widget hedefi `com.groopay.app.widget` bundle kimliğini kullanır. Signing sırasında Sign in with Apple, Push Notifications ve `group.com.groopay.app` App Group yeteneklerinin provisioning profile ile uyumlu olması gerekir.

App Store dağıtımı için:

1. `MARKETING_VERSION` ve `CURRENT_PROJECT_VERSION` değerlerini güncelleyin.
2. Release konfigürasyonuyla testleri çalıştırın.
3. Gerçek cihazda Apple ile giriş, satın alma/restore, push ve widget senaryolarını doğrulayın.
4. Xcode’da `Product > Archive` ile arşiv oluşturup App Store Connect’e yükleyin.

## Ek dokümantasyon

İstemci dönüşüm kararları, backend sözleşmeleri ve finans kuralları için [`GROOPAY-SWIFT-SPEC.md`](GROOPAY-SWIFT-SPEC.md) dosyasına bakın. `docs/sql/` altındaki dosyalar migration zincirinin yerine geçmez; yalnızca adlandırıldıkları operasyonel düzeltmeler için kullanılır.
