# Groopay UX-Psikoloji Denetimi — Codex Değişiklik Listesi

> Tarih: 24 Haziran 2026
> Kapsam: Güven akışı, hata mesajları, boş durumlar, paywall psikolojisi
> Format: Her madde dosya:satır referanslı, değişiklik talimatı içerir. KOD YAZILMAMIŞTIR.

---

## 1. GÜVEN AKIŞI — AddExpenseView, PaymentSheet, SettleDebtsSheet

### 1.1 Başarı mesajları: "kime / ne kadar / hangi grup" eksik

**Sorun:** DESIGN.md §6.2 "Her para işleminden sonra kullanıcı kime/ne kadar/hangi grup sorularının cevabını ANINDA görmeli" diyor. Mevcut tüm başarı mesajları generic.

| Konum | Mevcut | Sorun |
|---|---|---|
| `AddExpenseView.swift:866` | `"Masraf eklendi."` | Kime, ne kadar, hangi grup? Yok. |
| `AddExpenseView.swift:867` | `"Masraf güncellendi."` | Aynı. |
| `GroupDetailView.swift:279` | `"Masraf geri alındı."` | Hangi masraf? Yok. |
| `GroupDetailView.swift:267` | `"Masraf silindi."` | Hangi masraf? "Geri Al" butonu var ama metin eksik. |
| `BalancesView.swift:37` | `"Ödeme onaya gönderildi."` | Kime, ne kadar? Yok. |
| `BalancesView.swift:188` | `"Ödeme onaylandı."` | Aynı. |
| `BalancesView.swift:173` | `"Ödeme reddedildi."` | Aynı. |
| `SettleDebtsSheet.swift:58` | `"Ödeme onaya gönderildi."` | Aynı. |

**Değişiklik talimatı:**

```
[AddExpenseView.swift:866]
ESKI: "Masraf eklendi."
YENI: "Açıklama — Tutar, Ödeyen kişisine kaydedildi · GrupAdı 🏖️"
ÖRNEK: "Akşam yemeği — 450,00 ₺, Ayşe kişisine kaydedildi · Hafta Sonu 🏖️"

[AddExpenseView.swift:867]
ESKI: "Masraf güncellendi."
YENI: "Açıklama — Tutar güncellendi · GrupAdı"

[GroupDetailView.swift:267,279]
ESKI: "Masraf silindi." / "Masraf geri alındı."
YENI: "Açıklama — Tutar silindi · Geri Al" (zaten action var, metni uzat)

[BalancesView.swift:37, SettleDebtsSheet.swift:58]
ESKI: "Ödeme onaya gönderildi."
YENI: "AlacaklıAdı kişisine Tutar ödendi bildirimi gönderildi · GrupAdı"

[BalancesView.swift:188]
ESKI: "Ödeme onaylandı."
YENI: "BorçluAdı kişisinden Tutar ödemesi onaylandı · GrupAdı"

[BalancesView.swift:173]
ESKI: "Ödeme reddedildi."
YENI: "BorçluAdı kişisinin Tutar ödeme bildirimi reddedildi · GrupAdı"
```

**Uygulama notu:** `AddExpenseView.swift`'te `handleSave()` fonksiyonu (satır ~816), `feedback.success(message)` çağrısından ÖNCE `description`, `amountMinor`, `selectedCurrency`, `paidBy` (isim lookup), ve `snapshot.group.name` değerlerine erişime sahip. Bu değerleri `String(format:)` ile birleştir.

---

### 1.2 PaymentSheet: "kime" bilgisi zayıf

| Konum | Mevcut | Sorun |
|---|---|---|
| `PaymentSheet.swift:57-65` | `"Ne kadar ödedin?"` + `"Ahmet kişisine"` | Group context YOK. Kullanıcı hangi grupta ödeme yaptığını görmüyor. |
| `PaymentSheet.swift:94` | `"Toplam borç: ₺500,00"` | İyi ama hangi grup? |

**Değişiklik talimatı:**

```
[PaymentSheet.swift:57-65]
ESKI: "Ne kadar ödedin?" / "Ahmet kişisine"
YENI: "Ahmet'e ne kadar ödedin?" / "GrupAdı grubunda"

// config yapısına `groupName: String` ekle (şu an sadece groupID var).
// PaymentSheetConfig(groupName: snapshot.group.name) ile çağır.
// BalancesView.swift:134'te PaymentSheetConfig oluşturulurken groupName'i geç.
```

---

### 1.3 FX kilit görünürlüğü — TAMAMEN EKSİK

**Sorun:** `AddExpenseView.swift`'te kullanıcı para birimi seçiyor (TRY, EUR, USD…). Eğer grubun baz para biriminden farklı bir birim seçerse, canlı kur uygulanıyor. Ama bu kur kullanıcıya **hiçbir yerde gösterilmiyor.** DESIGN.md §6.4: "Canlı kur bilgisi hangi saat itibarıyla geçerli olduğuyla birlikte göster."

| Konum | Durum |
|---|---|
| `AddExpenseView.swift:220-244` (currencyPills) | Yalnızca para birimi kodu gösteriyor, kur yok. |
| `AddExpenseView.swift:198-213` (amountSection) | `formatAmount(amountMinor, currency:)` alt satırda — bu zaten seçili para biriminde. Ama kur bilgisi yok. |
| Proje geneli | `getDecimals(currency)` dışında FX kodu yok. `GROOPAY-SWIFT-SPEC.md:52` "çevrim sadece görüntüleme" diyor ama görüntülenen bir şey yok. |

**Değişiklik talimatı:**

```
[AddExpenseView.swift:198-213 civarı]
YENI ELEMAN: currencyPills ile amountSection arasına, seçili para birimi grubun
baz para biriminden farklıysa görünen bir info bar ekle:

"1 EUR ≈ 38,42 TRY · 24 Haz 2026 09:15'te kilitlendi · Bu kur yaklaşıktır, kesinleşmiş borç değildir"

GÖRÜNME KOŞULU: selectedCurrency != snapshot.group.baseCurrency
KAYNAK: canlı kur API'si henüz yoksa şimdilik placeholder — Supabase Edge Function
olarak `get-fx-rate` eklenebilir. Ama info bar'ı şimdiden yerleştir, "kur bilgisi
yakında" notuyla.
```

---

### 1.4 Gradient BUTON: PaymentSheet + SettleDebtsSheet (Adım 3'ten KAÇAN)

**Sorun:** `PaymentSheet.swift:144-151` ve `SettleDebtsSheet.swift:147-154` — Gradyan temizliğinden KAÇMIŞ. Bu iki dosya önceki adımda taranmadı.

| Konum | Durum |
|---|---|
| `PaymentSheet.swift:144-151` | `LinearGradient(colors: [.gradientStart, .gradientEnd])` |
| `SettleDebtsSheet.swift:147-154` | `LinearGradient(colors: [.gradientStart, .gradientEnd])` |
| `ActivityView.swift:146-152` | `LinearGradient(colors: [.gradientStart, .gradientEnd])` (emptyState CTA) |

**Değişiklik talimatı:**

```
[PaymentSheet.swift:144-151]
ESKI: LinearGradient(colors: [.gradientStart, .gradientEnd], ...)
YENI: Color.brand

[SettleDebtsSheet.swift:147-154]
ESKI: LinearGradient(colors: [.gradientStart, .gradientEnd], ...)
YENI: Color.brand

[ActivityView.swift:146-152]
ESKI: LinearGradient(colors: [.gradientStart, .gradientEnd], ...)
YENI: Color.brand
```

---

### 1.5 PaymentSheet: iptal/ödeme onayı sonrası sheet kapanıyor ama geri bildirim yok

**Sorun:** `PaymentSheet.swift:133-135` — `onPay(parsedAmount)` sonrası `dismiss()` çağrılıyor. Ama başarı feedback'i paymentSheet'i açan parent'ta (`BalancesView.swift:37` veya `SettleDebtsSheet.swift:58`) veriliyor. Bu feedback sheet kapandıktan SONRA geliyor — kullanıcı "acaba oldu mu?" diye bekliyor.

**Değişiklik talimatı:**

```
[PaymentSheet.swift:133-135]
onPay callback'ine bir completion handler ekle VEYA onPay çağrıldıktan sonra
küçük bir haptik + 300ms gecikmeyle dismiss yap. Bu sayede kullanıcı sheet
kapanmadan "işlem başladı" hissini alır.

.sensoryFeedback(.success, trigger: didSubmit)  // yeni @State
```

---

## 2. HATA MESAJLARI — "Ne oldu / Neden / Ne yapmalı" formatına çevirme

### 2.1 `error.localizedDescription` kullanımı — KRİTİK

**Sorun:** Bu ham sistem hatasını kullanıcıya gösteriyor. İngilizce, teknik, ve genelde "ne yapmalı" içermiyor.

| Konum | Dosya:Satır | Sorun |
|---|---|---|
| GroupsStore | `GroupsStore.swift:196,260,289,345,391` | `error.localizedDescription` → İngilizce DB hatası |
| AuthStore | `AuthStore.swift:152,177,292,310` | `error.localizedDescription` → İngilizce auth hatası |
| PurchasesManager | `PurchasesManager.swift:59,107,128,142` | `error.localizedDescription` → İngilizce IAP hatası |
| AccountView | `AccountView.swift:652,669,682` | `error.localizedDescription` → direkt gösteriliyor |

**Değişiklik talimatı:**

```
HER `error.localizedDescription` KULLANIMI İÇİN:

1. error.localizedDescription'ı log'a yaz (debugging için)
2. Kullanıcıya gösterilecek mesajı semantic hataya göre switch'le:

[GroupsStore.swift:196 civarı — load()]
ESKI: errorMessage = error.localizedDescription
YENI: 
  errorMessage = switch error {
    case let postgrestError where isNetworkError: 
      "Gruplar yüklenemedi · İnternet bağlantını kontrol et · Tekrar dene"
    default: 
      "Gruplar yüklenemedi · Sunucu geçici olarak yanıt vermiyor · Biraz sonra tekrar dene"
  }

[Aynı pattern tüm error.localizedDescription kullanımlarına uygulanacak]
```

### 2.2 Kategorize edilmiş hata mesajı düzeltme listesi

Her mesaj için ESKİ → YENİ:

```
[GroupsStore.swift:323,364,398,418,446,472,487 — 7 yer]
ESKI: "Üyelik bilgisi bulunamadı."
YENI: "Bu gruba erişimin yok · Grup sana ait değil veya çıkarıldın · Grup sahibiyle iletişime geç"

[GroupsStore.swift:368]
ESKI: "Yalnızca masrafı ekleyen kişi düzenleyebilir."
YENI: "Bu masrafı düzenleyemezsin · Masrafı sen eklemedin · Masrafı ekleyen kişiden düzenlemesini iste"

[GroupsStore.swift:402]
ESKI: "Yalnızca masrafı ekleyen kişi silebilir."
YENI: "Bu masrafı silemezsin · Masrafı sen eklemedin · Masrafı ekleyen kişiden silmesini iste"

[GroupsStore.swift:592]
ESKI: "Davet kodu geçersiz veya süresi dolmuş."
YENI: "Bu davet kodu çalışmıyor · Kod geçersiz veya süresi dolmuş olabilir · Yeni bir davet kodu iste veya kodu tekrar kontrol et"

[GroupsStore.swift:653]
ESKI: "Gruba katılınamadı."
YENI: "Gruba katılamadın · Beklenmeyen bir hata oluştu · Tekrar dene veya grup sahibinden yeni davet iste"

[GroupsStore.swift:657]
ESKI: "Bu gruptan çıkarıldığın için davet koduyla tekrar katılamazsın."
YENI: (BU İYİ — DEĞİŞTİRME) Zaten ne oldu/ne yapmalı içeriyor.

[AddExpenseView.swift:873]
ESKI: store.errorMessage ?? "Masraf kaydedilemedi"
YENI: store.errorMessage ?? "Masraf kaydedilemedi · Bilgileri kontrol et · Eksik alanları doldurup tekrar dene"

[AddExpenseView.swift:889-893]
ESKI: store.errorMessage ?? "Masraf silinemedi."
YENI: store.errorMessage ?? "Masraf silinemedi · İnternet bağlantını kontrol et · Tekrar dene"

[BalancesView.swift:417, SettleDebtsSheet.swift:223]
ESKI: store.errorMessage ?? "İşlem başarısız"
YENI: store.errorMessage ?? "İşlem tamamlanamadı · İnternet bağlantını kontrol et · Tekrar dene"

[AccountView.swift:112,726]
ESKI: "Dışa aktarma başarısız."
YENI: "Veriler dışa aktarılamadı · Dosya oluşturulamadı · Depolama izinlerini kontrol et ve tekrar dene"

[AccountView.swift:742]
ESKI: "Hesap silme başarısız."
YENI: "Hesap silinemedi · İnternet bağlantını kontrol et · Tekrar dene veya destekle iletişime geç"

[ProfileEditView.swift:178]
ESKI: "Profil güncellenemedi. Lütfen tekrar deneyin."
YENI: "Profil güncellenemedi · İsim 1-40 karakter arası olmalı · Kontrol edip tekrar dene"

[PurchasesManager.swift:118]
ESKI: "Ürün bilgisi yüklenemedi."
YENI: "Fiyat bilgisi alınamadı · App Store bağlantısı kurulamadı · İnternetini kontrol edip tekrar dene"

[GroupsView.swift:48]
ESKI: alert title "Bir sorun oluştu"
YENI: alert title "İşlem tamamlanamadı"
```

---

## 3. BOŞ DURUMLAR — Ghost/real üye eğitimi, tek CTA, aktivite feed

### 3.1 GroupsListView emptyState — ghost üye bilgisi EKSİK

| Konum | `GroupsListView.swift:50-67` |
|---|---|
| Mevcut | `person.2` ikonu, "Henüz grubun yok", "Yeni bir grup oluştur veya davet koduyla katıl." |
| Sorun | Ghost/real üye konsepti hiç anlatılmıyor. Yeni kullanıcı "arkadaşlarım uygulamada değilse ne yapacağım?" diye düşünüyor. |

**Değişiklik talimatı:**

```
[GroupsListView.swift:50-67]
YENI TASARIM (zengin boş durum):

VStack(spacing: 20) {
    // Ana ikon — grup konsepti
    ZStack {
        Circle().fill(Color.brand.opacity(0.08)).frame(width: 88, height: 88)
        Image(systemName: "person.2.fill")
            .font(.system(size: 40))
            .foregroundStyle(Color.brand)
    }
    
    VStack(spacing: 6) {
        Text("Henüz grubun yok")
            .font(.display)
            .foregroundStyle(Color.themeTextPrimary)
        Text("Arkadaşlarınla ortak harcamaları bölüşmek için bir grup oluştur.")
            .font(.bodyFont)
            .foregroundStyle(Color.themeTextSecondary)
            .multilineTextAlignment(.center)
    }
    
    // Ghost üye bilgi kartı
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: "person.badge.plus")
            .font(.system(size: 18))
            .foregroundStyle(Color.themeAccent)
        VStack(alignment: .leading, spacing: 3) {
            Text("Uygulamada olmayan arkadaşlarını da ekleyebilirsin")
                .font(.bodySmall, weight: .semibold)
            Text("Hayalet üye olarak ekle, borç/alacak takibi yap. Uygulamaya katıldıklarında hesapları otomatik eşleşir.")
                .font(.captionFont)
                .foregroundStyle(Color.themeTextSecondary)
        }
    }
    .padding(14)
    .background(Color.themeSurface)
    .clipShape(RoundedRectangle(cornerRadius: ThemeRadius.soft))
    
    // Çift CTA — biri primary biri secondary
    VStack(spacing: 10) {
        Button("Yeni Grup Oluştur") { onCreate() }
            .buttonStyle(PrimaryButtonStyle())  // solid brand
        
        Button("Davet Koduyla Katıl") { onJoin() }
            .buttonStyle(SecondaryButtonStyle())  // outline brand
    }
    .padding(.top, 8)
}
.padding(.horizontal, 32)
```

---

### 3.2 ActivityView emptyState — iki ayrı boş durum gerek

| Konum | `ActivityView.swift:127-158` |
|---|---|
| Mevcut | `clock.fill`, "Henüz aktivite yok", "Gruplarındaki masraf ve ödemeler burada görünecek." + "Gruplara Git" CTA |
| Sorun | Kullanıcının GRUBU VAR ama AKTİVİTESİ YOK durumu ile HİÇ GRUBU YOK durumu aynı boş durum. İlkinde "Gruplara Git" CTA'sı anlamsız (zaten grupları var). |

**Değişiklik talimatı:**

```
[ActivityView.swift:18-21 civarı]
İKİ FARKLI BOŞ DURUM:

// DURUM A: Hiç grup yok (store.groups.isEmpty)
→ "Henüz aktivite yok" + "Gruplar sekmesinden bir grup oluştur veya davet koduyla katıl." + "Gruplara Git" CTA

// DURUM B: Grup var ama aktivite yok (store.groups.isEmpty == false && store.activities.isEmpty)
→ "Henüz aktivite yok" + "Grubuna masraf eklediğinde veya bir ödeme yapıldığında burada görünecek." (CTA YOK — kullanıcı zaten grup içinde)

MEVCUT KOD:
  } else if store.activities.isEmpty {
      emptyState  // ← HER ZAMAN "Gruplara Git" CTA'sı gösteriyor
  }

YENI KOD:
  } else if store.activities.isEmpty {
      if store.groups.isEmpty {
          emptyStateNoGroups   // "Gruplara Git" CTA'lı
      } else {
          emptyStateNoActivity // CTA'sız, bilgilendirme odaklı
      }
  }
```

---

### 3.3 DashboardView actionCenterEmptyState — iyi, koru

| Konum | `DashboardView.swift:259-269` |
|---|---|
| Mevcut | `checkmark.circle.fill`, "Şu an yapman gereken bir işlem yok" |
| Durum | ✅ BU İYİ. Pozitif framing ("yapman gereken yok" yerine "yapman gereken bir işlem yok" — "işlem" kelimesi sorumluluk hissi vermiyor). DEĞİŞTİRME. |

---

### 3.4 BalancesView boş durum (herkes ödeşti) — iyi ama güçlendirilebilir

| Konum | `BalancesView.swift:314-322` |
|---|---|
| Mevcut | `checkmark.circle.fill`, "Herkes ödeşti" |
| Durum | ✅ İyi. İsteğe bağlı güçlendirme: altına "Grupta hiç borç/alacak yok." caption'ı ekle. |

---

### 3.5 DashboardView freeTeaser — zenginleştir

| Konum | `DashboardView.swift:366-410` |
|---|---|
| Mevcut | Elmas ikonu, "Panel Pro'ya Özel", açıklama, "Pro'ya Geç" CTA |
| Sorun | 3 Pro özelliğini sayıyor ama bunları GÖRSEL olarak göstermiyor. |

**Değişiklik talimatı:**

```
[DashboardView.swift:366-410]
YENI: PaywallView'daki 3'lü feature grid'in minik versiyonunu teaser kartın içine
yerleştir (ikon + başlık, alt başlık yok). Bu sayede kullanıcı "ne kaçırıyorum"u
görsel olarak anlar, sadece metin okumaz.

ÖRNEK:
"Panel Pro'ya Özel"
[chart.bar.fill Gelişmiş Panel] [person.2.fill Sınırsız Grup] [chart.pie.fill Kategori Analizi]
[Pro'ya Geç →]
```

---

## 4. PAYWALL — Endowment etkisi, "Cancel anytime", restore purchases

### 4.1 Endowment etkisi — trigger zamanlaması yanlış

**Sorun:** Paywall şu an **kullanıcı değeri deneyimlemeden ÖNCE** tetikleniyor. Kullanıcı 5 grup oluşturup 6.'yı denerken karşısına çıkıyor. Bu klasik "limit-based" trigger. Endowment etkisi için paywall, kullanıcının **"bu iyiymiş, daha fazlasını istiyorum"** dediği anda çıkmalı.

| Konum | Mevcut Trigger |
|---|---|
| `GroupsView.swift:63-67` | 5 grup limiti dolunca "Yeni Grup" butonu paywall'a dönüşüyor |
| `DashboardView.swift:375` | Free teaser'daki "Pro'ya Geç" butonu |
| `AccountView.swift:85-86` | Hesap sayfasından manuel |

**Analiz:** Mevcut trigger ENDOWMENT ETKİSİNE UYGUN DEĞİL. Kullanıcı "grup oluşturamıyorum, engellendim" hissediyor — bu negatif motivasyon. Pozitif motivasyon: "bu uygulama işimi gördü, Pro ile daha da iyi olacak."

**Değişiklik talimatı (davranışsal, 3 aşamalı):**

```
AŞAMA 1 — Hemen yap (1 satır):
[DashboardView.swift:40-43 civarı]
DashboardView body içinde, isPro == false ise, kullanıcının EN AZ 1 masrafı
varsa freeTeaser'ı DAHA BELİRGİN göster. Şu an freeTeaser her zaman aynı.
Değişiklik: hasAnyExpense == true ise teaser kartın başlığını değiştir:

"Panel Pro'ya Özel" → "Groopay'i kullanmaya başladın. Pro ile devam et."

Bu minik değişiklik "sen zaten değer gördün, şimdi yükselt" mesajı verir.

AŞAMA 2 — Sonraki sürüm (tartışmalı):
Paywall trigger'ını 5. grupta değil, 3. grupta + 3. masrafta tetikle.
"3 grupla sınır" free tier, "sınırsız" Pro. Bu sayede kullanıcı 2-3 grupta
değeri görüp "keşke daha fazla grup ekleyebilsem" diyor, "engellendim" değil.

AŞAMA 3 — Uzun vadeli:
İlk masraftan 48 saat sonra push notification: "Groopay'de 3 grubun ve 12
masrafın var. Pro ile sınırsız gruba geç, ilk ay %50 indirimli."
```

---

### 4.2 "Cancel anytime" görünürlüğü

| Konum | `PaywallView.swift:240-243` |
|---|---|
| Mevcut | "Abonelik dönem sonunda otomatik yenilenir. İptal edilmezse ücret tahsil edilir. Hesap ayarlarından yönetebilirsiniz." |
| Sorun | Bu metin yasal zorunluluk, "Cancel anytime" güven sinyali DEĞİL. Kullanıcılar bu metni okumaz. |

**Değişiklik talimatı:**

```
[PaywallView.swift:203-253 civarı — pricingCard]
YENI: Fiyatın hemen altına, küçük yeşil pill:

HStack(spacing: 6) {
    Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 11))
        .foregroundStyle(Color.credit)
    Text("İstediğin zaman iptal et")
        .font(.captionFont)
        .foregroundStyle(Color.credit)
}
.padding(.top, 4)

Bu pill, yasal metinden AYRI ve ÖNCE gösterilmeli. Kullanıcı fiyatı gördükten
hemen sonra "iptal edebilirim" güvencesini almalı.
```

---

### 4.3 Restore purchases — mevcut, iyi

| Konum | `PaywallView.swift:328-330` |
|---|---|
| Durum | ✅ "Satın Almaları Geri Yükle" butonu mevcut, footer'da, tıklanabilir. DEĞİŞTİRME. |

---

### 4.4 Guest purchase gate — Apple Sign In zorunluluğu

| Konum | `PaywallView.swift:279-289` |
|---|---|
| Mevcut | Misafir kullanıcıya Apple Sign In butonu + "Apple hesabı gerekli" açıklaması |
| Sorun | "Neden Apple hesabı gerekiyor?" sorusuna cevap yok. |

**Değişiklik talimatı:**

```
[PaywallView.swift:284 civarı]
ESKI: "account.appleRequired"
YENI: "Satın almanı Apple hesabına bağlamak için giriş yap. Böylece yeni telefonunda da Pro'nu geri yükleyebilirsin."

Bu metin "neden" sorusunu cevaplar + endowment hissi verir ("yeni telefonda da").
```

---

## ÖZET: Değişiklik Öncelik Matrisi

| Öncelik | Madde | Etki | Efor |
|---|---|---|---|
| **P0** | 1.1 Başarı mesajları: kime/ne kadar/hangi grup | Güven hissi anında 2x | Orta (~15 satır) |
| **P0** | 1.3 FX kilit görünürlüğü | Para uygulaması güveni için kritik | Yüksek (API yoksa placeholder) |
| **P0** | 2.1 `error.localizedDescription` temizliği | Kullanıcıya İngilizce hata göstermek güveni sıfırlar | Orta (~20 yer) |
| **P1** | 1.4 Kaçan gradyanlar (3 dosya) | AI tell audit'ten kaçanlar | Düşük (3 satır) |
| **P1** | 2.2 Hata mesajı formatı (15+ mesaj) | Tutarlılık | Orta |
| **P1** | 3.1 GroupsListView zengin boş durum | İlk izlenim, ghost üye keşfi | Orta |
| **P1** | 4.2 "Cancel anytime" pill'i | Dönüşüm oranı | Düşük (5 satır) |
| **P2** | 1.2 PaymentSheet group context | Mikro güven | Düşük |
| **P2** | 1.5 PaymentSheet haptik | Mikro güven | Düşük |
| **P2** | 3.2 ActivityView çift boş durum | UX tutarlılığı | Düşük |
| **P2** | 3.5 Dashboard freeTeaser zenginleştirme | Pro dönüşümü | Orta |
| **P2** | 4.1 Endowment trigger (Aşama 1) | Pro dönüşümü | Düşük (1 satır) |
| **P2** | 4.4 Guest gate açıklaması | Pro dönüşümü | Düşük |
