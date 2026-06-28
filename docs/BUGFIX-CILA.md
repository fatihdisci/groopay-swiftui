# BUGFIX & CİLA KAYITLARI (B119)

Bu dökümanda, Groopay iOS SwiftUI uygulamasında gerçekleştirilen tekrarlayan masraflar özelliğinin detayları ve düzeltme kayıtları yer almaktadır.

---

## [B119] Tekrarlayan Masraflar İstemci Entegrasyonu

### 1. Tekrarlayan Masraflar İstemci Motoru
- **Modeller**: `RecurringExpenseRule` ve `RecurringExpenseExecution` modelleri tanımlandı. Tarih ve minor amount kodlama kurallarına (Double/Float yerine kuruş/minor unit kullanımı) tam sadık kalındı.
- **RPC Entegrasyonu**: Supabase veritabanındaki RPC fonksiyonlarını çağırmak için `CreateRecurringRuleRPCInput`, `UpdateRecurringRuleRPCInput`, `PauseRecurringRuleRPCInput` ve `DeleteRecurringRuleRPCInput` yapıları eklendi.
- **Store & State**: `GroupsStore` sınıfı genişletilerek kural ekleme, düzenleme, duraklatma ve silme metotları eklendi. GroupDetailView açıldığında kuralların yüklenmesi tetiklendi.
- **Arayüz**: `RecurringExpensesView` ekranında kurallar listelendi, aktiflik durumları toggle ile değiştirilebilir kılındı. Sürükleyerek silme desteği eklendi. Kural formunda eşit, alt küme ve özel bölüşüm şekilleri desteklendi.

### 2. Cron Motoru
- **execute_due_recurring_expenses()**: PostgreSQL `SECURITY DEFINER` fonksiyonu, sadece `service_role` tarafından çağrılabilir.
- **Idempotency**: `recurring_expense_executions` tablosunda `UNIQUE (rule_id, execution_date)` + `ON CONFLICT ON CONSTRAINT` ile çift expense oluşturulması engellenmiştir.
- **Catch-up**: WHILE döngüsü ile kaçırılan tüm periyotlar sırayla işlenir.
- **pg_cron schedule**: `202606280002_pg_cron_schedule.sql` — saat başı tetikleme, pg_cron yoksa sessizce atlar.

---

### BUGFIX Kayıtları

| Tarih | Commit | Sorun | Çözüm |
|-------|--------|-------|-------|
| 28.06 | `98fbbe1` | Tablo adı uyuşmazlığı: Swift `recurring_expense_rules` ↔ SQL `recurring_expenses_rules` | Swift tarafındaki isim düzeltildi |
| 28.06 | `98fbbe1` | `paidBy!` force-unwrap | `guard let payerId = paidBy` ile değiştirildi |
| 28.06 | `8e428e3` | Fişten ekleme (receipt scanner) özelliği kaldırıldı | Tüm ilgili dosyalar silindi, AddExpenseView ve Info.plist temizlendi |
| 28.06 | `e573c44` | Masraf tutar fontu `display(16)` çok büyük, alt satıra taşıyor | `body(14)` + `lineLimit(1)` |
| 28.06 | `e573c44` | Kur bilgisi bar'ı herkese çıkıyor (yabancı kullanıcıya TRY anlamsız) | `LocalizationStore.currentLocale().hasPrefix("tr")` kontrolü eklendi |
| 28.06 | `e573c44` | Kur tarihi saat içeriyordu (`d MMM yyyy HH:mm`) | Sadece tarih (`d MMM yyyy`) + metin "tarihindeki kur baz alınmaktadır" |
| 28.06 | `c74db6d` | pg_cron SQL: `cron.schedule()` DO bloğu dışında → `schema "cron" does not exist` | Tüm mantık DO bloğuna alındı, `pg_extension` kontrolü eklendi |
| 28.06 | `1594215` | pg_cron SQL: iç içe `$$` çakışması → syntax error | `$_$` delimiter kullanıldı |
| 28.06 | *(bu commit)* | `execute_due_recurring_expenses` içinde `execution_date` output parametresi ile tablo kolonu çakışması (`ERROR: 42702: column reference "execution_date" is ambiguous`) | **1)** Constraint'e isim verildi (`recurring_expense_executions_rule_date_key`). **2)** `ON CONFLICT (rule_id, execution_date)` → `ON CONFLICT ON CONSTRAINT recurring_expense_executions_rule_date_key`. **3)** `RETURNS TABLE` output kolonu `processed_execution_date` olarak değiştirildi. **4)** Tablo referansları `public.` ile nitelendirildi. **5)** Hotfix migration `202606280003` oluşturuldu |

---

### Mimarî ve Güvenlik Kontrolleri
- ❌ **Float/Double Kullanımı**: Hiçbir finansal hesaplamada veya veri modelinde kayan noktalı sayı kullanılmadı. Kuruş birimi (minor unit) kullanıldı.
- 🔐 **Veri Yazma Güvenliği**: Tüm hassas yazma işlemleri doğrudan tabloya değil, migration ile hazırlanan `SECURITY DEFINER` veritabanı RPC'leri üzerinden yapıldı.
- 🛡️ **created_by Çözümleme**: `create_recurring_expense_rule` RPC'sinde `created_by` parametresi client'tan alınmaz, sunucu tarafında `auth.uid()` ile güvenle çözümlenir.
- 🔒 **Cron Yetkilendirme**: `execute_due_recurring_expenses()` sadece `service_role` tarafından çağrılabilir; `authenticated` ve `public` rolleri için execute izni revoke edilmiştir.
