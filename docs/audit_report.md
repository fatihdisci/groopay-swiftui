# Groopay Keşif & Uygulama Planı Raporu

Bu rapor, Groopay iOS SwiftUI uygulamasında gerçekleştirilecek iki majör özellik (1. On-device fiş tarama + kalem bölüştürme, 2. Tekrarlayan masraflar motoru) için keşif sonuçlarını ve uygulama planını detaylandırır.

---

## 1. MİMARİ KEŞİF (AUDIT) SONUÇLARI

### 1.1 Teknoloji Stack Analizi
*   **İstemci (Client):** iOS 17.0+ SwiftUI Native uygulama.
*   **Veri Tabanı & API Katmanı:** Supabase (Postgres, RLS politikaları, RPC).
*   **Para Hesaplama Mantığı:** Tutarlar veri tabanında `numeric(14,2)` formatında saklanır; istemcide ise **Int minor unit** (örn. kuruş) olarak işlenir ve formatlanır. `Double`/`Float` kullanımı yasaktır.

### 1.2 Mevcut Dosya ve Yapı Eşlemeleri
*   **Harcama Oluşturma Ekranı:** [AddExpenseView.swift](file:///Users/fatih/Apps/groopay-swiftui/Groopay/Features/Groups/AddExpenseView.swift)
*   **Bölüşüm Mantığı ve Fonksiyonlar:** [Split.swift](file:///Users/fatih/Apps/groopay-swiftui/Groopay/Core/Finance/Split.swift) (`equalSplits`, `computeSplits` fonksiyonları)
*   **Harcama / Split Modelleri:** [Expense.swift](file:///Users/fatih/Apps/groopay-swiftui/Groopay/Core/Models/Expense.swift) ve [ExpenseSplit.swift](file:///Users/fatih/Apps/groopay-swiftui/Groopay/Core/Models/ExpenseSplit.swift)
*   **Mevcut RPC Çağrıları:** [RPC.swift](file:///Users/fatih/Apps/groopay-swiftui/Groopay/Core/Supabase/RPC.swift) (`add_expense_with_splits`, `update_expense_with_splits` çağrıları)
*   **Supabase Realtime Aboneliği:** [Realtime.swift](file:///Users/fatih/Apps/groopay-swiftui/Groopay/Core/Supabase/Realtime.swift) (`RealtimeManager` ile grup tablosundaki değişiklikleri izler ve reload tetikler)
*   **Para Yardımcıları:** [Money.swift](file:///Users/fatih/Apps/groopay-swiftui/Groopay/Core/Finance/Money.swift) (`parseMoneyInputToMinor`, `formatAmount` vb.)

---

## 2. AŞAMA 1: FİŞ TARAMA (OCR) & KALEM BÖLÜŞTÜRME PLANI

### 2.1 OCR Parser Mantığı
*   iOS `Vision` framework'ünün `VNRecognizeTextRequest` API'si kullanılarak tamamen cihaz üzerinde (on-device) OCR yapılacaktır.
*   Regex ile satır sonlarındaki tutar ifadeleri (`150,50`, `1.250,50`, `150.50`, vb.) yakalanacaktır.
*   "Toplam", "KDV", "Nakit", "Kredi Kartı" vb. anahtar kelimeleri içeren satırlar kalem olarak eklenmeyecektir.
*   Tüm fiyat dönüşümleri `Money.swift` içerisindeki `parseMoneyInputToMinor` metoduyla kuruşa çevrilecektir.

### 2.2 UI Tasarımı & Akışı
*   [AddExpenseView.swift](file:///Users/fatih/Apps/groopay-swiftui/Groopay/Features/Groups/AddExpenseView.swift) ekranına bir **"Fişten Ekle"** butonu yerleştirilecektir.
*   Buton tıklandığında `ReceiptScannerView` sheet'i açılacaktır.
*   Kullanıcı galeriden fiş resmi seçecek veya kamerayla çekecektir.
*   Cihaz içi Vision motoru çalışırken `ProgressView` gösterilecektir.
*   OCR sonucu satırlar kalem ismi, tutarı (düzenlenebilir) ve yanlarında üye seçme butonları (avatar/chip şeklinde) ile listelenecektir.
*   Kalemlerin silinmesi veya yeni kalem eklenmesi desteklenecektir.
*   Onaylandığında kalem bazındaki paylar toplanıp, üyelerin final split matrisini (`[UUID: Int]`) ve faturanın toplam tutarını hesaplayıp `AddExpenseView` üzerindeki değerleri önceden dolduracaktır.

---

## 3. AŞAMA 2: TEKRAR EDEN MASRAFLAR MOTORU

### 3.1 Idempotency & Güvenlik Önlemleri
*   **Yetki:** `execute_due_recurring_expenses` RPC fonksiyonunun `authenticated` veya `public` rolleri tarafından çalıştırılması tamamen engellenmiş (revoke edilmiştir). Yalnızca `service_role` çağırabilir.
*   **Race Condition & Idempotency Koruması:** `insert ... on conflict (rule_id, execution_date) do update ... returning id into v_execution_id` kalıbı kullanılarak paralel yürütmelerde çift expense oluşturulması kesin olarak engellenmiştir.
*   **Failed & Retry Davranışı:** MVP'de başarısız olan periyotlar gelecekteki otomatik cron çalıştırmalarında otomatik olarak tekrar denenmez (çünkü cron motorunun kilitlenmemesi için `next_execution_date` her durumda sonraki periyoda ilerletilir). Başarısızlık durumu `recurring_expense_executions` tablosuna `status = 'failed'` ve hata detayı `error_message` olarak Postgres hata detayı ile loglanır. Ancak veritabanı üzerinden `next_execution_date` değeri manuel olarak geri çekildiğinde ya da aynı periyot el ile tetiklendiğinde `ON CONFLICT DO UPDATE` retry mekanizması çakışmayı önleyip işlemin tekrar çalışmasına olanak tanır.
*   **Sıkı Validasyonlar:** `validate_recurring_rule_splits` fonksiyonu ile tutarın sıfırdan büyüklüğü, para birimi uzunluğu, yinelenen üye ID'leri, custom/subset split doluluğu ve splits toplamının kural tutarıyla kuruşu kuruşuna eşleşmesi veri tabanı seviyesinde doğrulanır.
*   **created_by Çözümleme:** `create_recurring_expense_rule` RPC'sinde `created_by` parametresi client'tan alınmaz, sunucu tarafında `auth.uid()` ve `group_id` üzerinden güvenle çözümlenir.

### 3.2 SQL Migration Planı
SQL migration script'i [202606280001_recurring_expenses.sql](file:///Users/fatih/Apps/groopay-swiftui/supabase/migrations/202606280001_recurring_expenses.sql) dosyası olarak kaydedilmiştir.

---

## 4. BİLDİRİM & PROJE KISITLARI UYUMU
*   Tasarım sisteminde `background #F7F6FF`, `primary #4F46E5`, gradientler ve SF Symbols kullanılacaktır.
*   Para işlemlerinde Double/Float kullanımı kesinlikle engellenmiştir.
*   İstemci tarafında `autoRefreshToken` mantığı ve Supabase client yapısı bozulmadan korunacaktır.
