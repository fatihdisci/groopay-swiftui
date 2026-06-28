# Tekrarlayan Masraflar (Recurring Expenses) — Teknik Denetim Raporu

**Sürüm:** 1.4.0 (build 39)  
**Tarih:** 2026-06-28  
**Son commit:** `1594215`

---

## 1. Mimari Genel Bakış

```
┌─────────────────────────────┐      ┌──────────────────────────────────┐
│   SwiftUI Client (iOS 17+)  │      │   Supabase (PostgreSQL 15)        │
│                             │      │                                  │
│  RecurringExpensesView      │ RLS  │  recurring_expenses_rules        │
│  RuleFormView               │◄────►│  recurring_expense_executions    │
│  GroupsStore                │ SELECT│                                  │
│                             │      │  RPC (SECURITY DEFINER):          │
│  RecurringExpenseRule       │ RPC  │  create / update / pause          │
│  RecurringExpenseExecution  │◄────►│  delete / execute_due             │
│                             │      │                                  │
│  RPCClient (Supabase)       │      │  pg_cron (service_role)           │
│                             │      │  └─ saat başı tetiklenir          │
│  LocalizationStore          │      │     execute_due_recurring_        │
│  └─ FX rate bar gating      │      │     expenses()                   │
└─────────────────────────────┘      └──────────────────────────────────┘
```

**Temel prensip:** Yazma işlemleri DOĞRUDAN tabloya değil, `SECURITY DEFINER` RPC fonksiyonları üzerinden yapılır. RLS politikaları yalnızca `SELECT` için tanımlıdır. İstemci hiçbir zaman tabloya doğrudan `INSERT/UPDATE/DELETE` yapamaz.

---

## 2. Veritabanı Şeması

### 2.1 `recurring_expenses_rules`

| Kolon | Tip | Kısıt |
|-------|-----|-------|
| `id` | `uuid PK` | `gen_random_uuid()` |
| `group_id` | `uuid FK → groups(id)` | `ON DELETE CASCADE` |
| `description` | `text NOT NULL` | |
| `note` | `text` | nullable |
| `amount` | `numeric(14,2) NOT NULL` | kayan nokta YOK |
| `currency` | `varchar(3) NOT NULL` | |
| `category` | `text NOT NULL` | |
| `split_type` | `text NOT NULL` | `CHECK IN ('equal','custom','subset')` |
| `paid_by` | `uuid FK → group_members(id)` | `ON DELETE CASCADE` |
| `created_by` | `uuid FK → group_members(id)` | `ON DELETE CASCADE` |
| `frequency` | `text NOT NULL` | `CHECK IN ('weekly','monthly','yearly')` |
| `start_date` | `date NOT NULL` | |
| `next_execution_date` | `date NOT NULL` | ⭐ motorun gözü burada |
| `is_active` | `boolean NOT NULL DEFAULT true` | pause/resume |
| `splits` | `jsonb NOT NULL` | `[{member_id, share_amount}]` |
| `created_at` | `timestamptz NOT NULL` | `DEFAULT now()` |
| `updated_at` | `timestamptz NOT NULL` | trigger ile otomatik |

### 2.2 `recurring_expense_executions` (Idempotency tablosu)

| Kolon | Tip | Kısıt |
|-------|-----|-------|
| `id` | `uuid PK` | |
| `rule_id` | `uuid FK → recurring_expenses_rules(id)` | `ON DELETE CASCADE` |
| `execution_date` | `date NOT NULL` | |
| `expense_id` | `uuid FK → expenses(id)` | `ON DELETE SET NULL` |
| `error_message` | `text` | başarısızlık detayı |
| `executed_at` | `timestamptz NOT NULL` | |
| `status` | `text NOT NULL` | `CHECK IN ('processing','success','failed')` |
| **UNIQUE** | `(rule_id, execution_date)` | ⭐ idempotency garantisi |

### 2.3 Migration Dosyaları

| Dosya | İçerik |
|-------|--------|
| `202606280001_recurring_expenses.sql` | Tablolar, RLS, trigger, tüm RPC fonksiyonları, yetkilendirmeler |
| `202606280002_pg_cron_schedule.sql` | pg_cron schedule tanımı (hourly trigger) |

---

## 3. RPC Katmanı

### 3.1 `create_recurring_expense_rule`

```sql
create_recurring_expense_rule(
  p_group_id, p_description, p_note, p_amount, p_currency,
  p_category, p_split_type, p_paid_by, p_frequency,
  p_start_date, p_splits
) RETURNS uuid
```

**Akış:**
1. `auth.uid()` kontrolü → yetkisiz çağrı ret
2. Input normalizasyonu: `trim()`, `upper()`
3. Açıklama/kategori/para birimi boşluk kontrolleri
4. ⛔ `p_start_date < current_date` → geçmişe dönük backfill ENGELLENİR
5. `created_by` değeri CLIENT'TAN ALINMAZ — `auth.uid()` ile `group_members` tablosundan sunucu tarafında çözümlenir 🔐
6. `p_paid_by` üyesinin grupta aktif olduğu doğrulanır
7. `validate_recurring_rule_splits()` çağrılır
8. `next_execution_date = p_start_date` olarak INSERT
9. Yeni kural UUID'si döndürülür

### 3.2 `update_recurring_expense_rule`

```sql
update_recurring_expense_rule(
  p_rule_id, p_description, p_note, p_amount, p_currency,
  p_category, p_split_type, p_paid_by, p_actor_member_id,
  p_frequency, p_is_active, p_splits
) RETURNS void
```

**Akış:**
1. `auth.uid()` kontrolü
2. Input normalizasyonu
3. Kuralın varlığı kontrol edilir, `group_id` alınır
4. `p_actor_member_id` doğrulaması: bu üye `auth.uid()`'e ait mi + grupta aktif mi?
5. `p_paid_by` doğrulaması
6. ⚠️ `next_execution_date` client tarafından güncellenmez (MVP kısıtı)
7. `validate_recurring_rule_splits()` çağrılır
8. UPDATE çalıştırılır

### 3.3 `pause_recurring_expense_rule`

```sql
pause_recurring_expense_rule(p_rule_id, p_actor_member_id, p_is_active)
```

Toggle mantığı: `is_active = true|false`. Yetki kontrolü JOIN ile yapılır.

### 3.4 `delete_recurring_expense_rule`

```sql
delete_recurring_expense_rule(p_rule_id, p_actor_member_id)
```

Hard delete + cascade. Yetki kontrolü var. Silinen kurala bağlı `expense_id`'ler `ON DELETE SET NULL` ile korunur — geçmiş masraflar silinmez.

### 3.5 `validate_recurring_rule_splits` (Helper — PUBLIC/ANONYMOUS erişimi REVOKE)

6 aşamalı validasyon:

| # | Kontrol | Hata Kodu |
|---|---------|-----------|
| 1 | `p_amount > 0` | `22003` |
| 2 | `p_split_type IN ('equal','custom','subset')` | `22023` |
| 3 | Splits JSON array mi? | `22023` |
| 4 | Custom/subset için splits boş olamaz | `22023` |
| 5 | Yinelenen `member_id` kontrolü + aktif üyelik validasyonu | `23505` / `42501` |
| 6 | Custom için `SUM(share_amount) == p_amount` | `22000` |

---

## 4. Cron / İşletici Motor (`execute_due_recurring_expenses`)

### 4.1 Yetkilendirme

```sql
revoke all on function execute_due_recurring_expenses() from public, authenticated;
grant  execute on function execute_due_recurring_expenses() to service_role;
```

SADECE `service_role` çağırabilir. Normal kullanıcılar veya anonim erişim tamamen engellenmiştir.

### 4.2 pg_cron Schedule (✅ Çözüldü)

**Migration:** `202606280002_pg_cron_schedule.sql`

```sql
do $$
begin
    -- pg_cron kurulu değilse sessizce atla
    if not exists (
        select 1 from pg_extension where extname = 'pg_cron'
    ) then
        raise notice 'pg_cron extension bulunamadı — cron schedule atlandı.';
        return;
    end if;

    -- Eski schedule varsa temizle (idempotent)
    perform cron.unschedule('recurring-expenses-hourly');

    -- Her saat başı (HH:00 UTC) çalışacak schedule
    -- $_$ içteki $$ çakışmasını önler (DO bloğu içinde farklı delimiter)
    perform cron.schedule(
        'recurring-expenses-hourly',
        '0 * * * *',
        $_$ select execute_due_recurring_expenses(); $_$
    );

    raise notice 'pg_cron schedule "recurring-expenses-hourly" başarıyla kuruldu.';
end;
$$;
```

**Önemli noktalar:**

| Detay | Açıklama |
|-------|----------|
| **Dollar-quote çakışması** | Dıştaki `DO $$` ile içteki `cron.schedule(..., $$ ... $$)` çakışır. `$_$` delimiter'ı ile çözüldü |
| **Extension check** | `pg_extension` tablosundan `pg_cron` varlığı kontrol edilir. Yoksa `NOTICE` verip çıkar, migration başarısız olmaz |
| **Idempotent** | Önce `unschedule` yapıp sonra `schedule` — tekrar tekrar çalıştırılabilir |
| **Ücretsiz plan** | Supabase free tier'da pg_cron desteklenmez. Pro plana geçmek veya harici cron (GitHub Actions, Vercel Cron) ile `service_role` key kullanarak RPC'yi tetiklemek gerekir |

### 4.3 Çalışma Mantığı (Detaylı)

```
v_current_date = current_date (server timezone)

FOR EACH rule WHERE is_active = true AND next_execution_date <= v_current_date:

    v_next_date = rule.next_execution_date

    WHILE v_next_date <= v_current_date:          ← kaçırılan periyotları yakala
        --- IDEMPOTENCY KONTROLÜ ---
        INSERT INTO executions (rule_id, execution_date, status='processing')
        ON CONFLICT (rule_id, execution_date)
        DO UPDATE SET status='processing' WHERE status='failed'
        RETURNING id

        IF v_execution_id IS NOT NULL:            ← ilk kez veya retry
            BEGIN
                --- 1. paid_by aktiflik kontrolü ---
                --- 2. expenses tablosuna INSERT ---
                --- 3. expense_splits tablosuna INSERT ---
                ---    (equal / subset / custom hesaplama) ---
                --- 4. executions tablosu status='success' ---
                RETURN NEXT
            EXCEPTION WHEN OTHERS:
                --- executions tablosu status='failed' ---
                --- expense + splits otomatik ROLLBACK ---
            END

        --- Tarihi ilerlet (başarısız olsa bile) ---
        v_next_date += frequency_interval

    --- rule.next_execution_date = v_next_date ---
```

### 4.4 Frekans Periyodu İlerletme

| Frekans | SQL Interval | Açıklama |
|---------|-------------|----------|
| `weekly` | `+ interval '1 week'` | 7 gün |
| `monthly` | `+ interval '1 month'` | PostgreSQL ay sonlarını doğru yönetir (31 Ocak → 28 Şubat) |
| `yearly` | `+ interval '1 year'` | Artık yıl uyumlu |

### 4.5 Kaçırılan Periyotlar (Catch-up)

```
Örnek: Aylık kural, next_execution_date = 2026-03-01
       Cron 3 aydır çalışmadı, current_date = 2026-06-15

v_next_date = 2026-03-01
├── Iteration 1: 2026-03-01 → expense oluştur, v_next_date → 2026-04-01
├── Iteration 2: 2026-04-01 → expense oluştur, v_next_date → 2026-05-01
├── Iteration 3: 2026-05-01 → expense oluştur, v_next_date → 2026-06-01
└── Iteration 4: 2026-06-01 → expense oluştur, v_next_date → 2026-07-01
    2026-07-01 > current_date → WHILE döngüsü sona erer

rule.next_execution_date = 2026-07-01  ← bir sonraki cron bunu bekler
```

✅ **3 aylık catch-up başarıyla yapılır, 4 expense oluşturulur.**

### 4.6 Idempotency — Mükerrer Kayıt Engelleme

```sql
INSERT INTO executions (rule_id, execution_date, status)
VALUES (v_rule.id, v_next_date, 'processing')
ON CONFLICT (rule_id, execution_date)          ← UNIQUE constraint
DO UPDATE SET status = 'processing', ...
WHERE recurring_expense_executions.status = 'failed'
RETURNING id INTO v_execution_id
```

| Senaryo | ON CONFLICT Davranışı | Sonuç |
|---------|----------------------|-------|
| İlk kez çalışıyor | Normal INSERT | `v_execution_id` dolu → expense oluşturulur |
| Daha önce başarılı (`success`) | `WHERE status='failed'` eşleşmez | `v_execution_id` NULL → ATLANIR ✅ |
| Daha önce işleniyor (`processing`) | Aynı şekilde UPDATE atlanır | `v_execution_id` NULL → ATLANIR ✅ |
| Daha önce başarısız (`failed`) | UPDATE çalışır, `RETURNING id` dolu | `v_execution_id` dolu → TEKRAR DENE ✅ |

### 4.7 Hata Durumunda Davranış

```
BEGIN
    INSERT INTO expenses ...         ─┐
    INSERT INTO expense_splits ...    ├── hata olursa otomatik ROLLBACK
    UPDATE executions SET status...  ─┘
EXCEPTION WHEN OTHERS:
    UPDATE executions SET status='failed', error_message=SQLERRM
    -- next_execution_date yine de ilerletilir (motor kilitlenmesin diye)
```

---

## 5. İstemci (SwiftUI) Katmanı

### 5.1 Modeller

| Model | Dosya | Açıklama |
|-------|-------|----------|
| `RecurringExpenseRule` | `Core/Models/RecurringExpenseRule.swift` | Ana kural modeli. Tüm tutarlar `Int` (minor unit). Currency `uppercased()`. |
| `RecurringSplitEntry` | Aynı dosya | Split başına `memberId` + `shareAmount`. `decimalAmount` ↔ `minorAmount` dönüşümü |
| `RecurringExpenseExecution` | `Core/Models/RecurringExpenseExecution.swift` | Motor çalışma kaydı. `expenseId` başarılı çalıştırmada oluşturulan masrafa link |
| `RecurringFrequency` | Aynı dosya | `enum: weekly, monthly, yearly` |

### 5.2 GroupsStore Metotları

| Metot | Hedef | Auth |
|-------|-------|------|
| `loadRecurringRules(for:)` | `SELECT recurring_expenses_rules` | RLS |
| `createRecurringRule(...)` | `create_recurring_expense_rule` RPC | SECURITY DEFINER → `auth.uid()` |
| `updateRecurringRule(...)` | `update_recurring_expense_rule` RPC | SECURITY DEFINER + `p_actor_member_id` |
| `pauseRecurringRule(...)` | `pause_recurring_expense_rule` RPC | SECURITY DEFINER + `p_actor_member_id` |
| `deleteRecurringRule(...)` | `delete_recurring_expense_rule` RPC | SECURITY DEFINER + `p_actor_member_id` |

Tüm yazma işlemleri `actor` (currentMemberID) kontrolü yapar.

### 5.3 UI Akışı

```
GroupDetailView
  └── "Tekrarlayan Masraflar" butonu → RecurringExpensesView sheet
        ├── Liste (aktif/pasif tüm kurallar)
        │   ├── Toggle → pause/resume
        │   ├── Tap → RuleFormView (edit)
        │   └── Swipe → delete
        └── "Yeni Kural Ekle" butonu → RuleFormView (create)
```

**RuleFormView** validasyonları:
- `amountMinor > 0`
- Açıklama boş değil
- `paidBy != nil` (guard let ile güvenli)
- Splits toplamı == amountMinor

### 5.4 Masraf Listesi Font Düzeltmesi

Masraf tutarları `GroupDetailView` expenses listesinde `display(16)` ile çok büyük render ediliyor, uzun tutarlar alt satıra taşıyordu.

| Önce | Sonra |
|------|-------|
| `.font(.display(16, weight: .semibold))` | `.font(.body(14, weight: .semibold))` + `.lineLimit(1)` |

### 5.5 Kur Bilgisi (FX Rate) — Locale Gating

AddExpenseView'de TRY dışı para birimi seçildiğinde çıkan kur bilgisi bar'ı **sadece uygulama dili Türkçe olan kullanıcılara** gösterilir:

```swift
private func showFXInfo(snapshot: GroupSnapshot) -> Bool {
    LocalizationStore.currentLocale().identifier.hasPrefix("tr")
        && selectedCurrency.uppercased() != snapshot.group.baseCurrency.uppercased()
}
```

| Kullanıcı | TRY seçili | USD seçili |
|-----------|-----------|-----------|
| App dili Türkçe | Bar GÖSTERİLMEZ | Bar GÖSTERİLİR ✅ |
| App dili English | Bar GÖSTERİLMEZ | Bar GÖSTERİLMEZ ✅ |

**Metin:** `"1 USD ≈ 38.50 TRY · 28 Haz 2026 tarihindeki kur baz alınmaktadır · Bu kur yaklaşıktır, kesinleşmiş borç değildir"`

**Tarih formatı:** `"d MMM yyyy"` (saat GÖSTERİLMEZ)

---

## 6. Güvenlik Denetimi

### 6.1 Yetkilendirme Katmanları

| Katman | Ne? | Nasıl? |
|--------|-----|--------|
| **Ağ** | Supabase anon key kullanımı | RLS + RPC SECURITY DEFINER |
| **Satır** | RLS SELECT politikası | Kullanıcının aktif üye olduğu gruplara ait kurallar |
| **Yazma** | Tüm mutasyonlar RPC | SECURITY DEFINER fonksiyonlar, doğrudan tablo INSERT yok |
| **created_by** | Sunucu tarafı çözümleme | `auth.uid()` → `group_members.id`, client'tan parametre alınmaz |
| **actor_member_id** | Client bildirir, sunucu doğrular | `gm.id = p_actor_member_id AND gm.user_id = auth.uid()` |
| **Cron motoru** | Sadece service_role | Authenticated ve public rollere execute izni REVOKE |

### 6.2 Risk Değerlendirmesi

| Risk | Seviye | Durum |
|------|--------|-------|
| Başkası adına kural oluşturma | 🔴 Kritik | ✅ Engellendi (`created_by` sunucuda çözülür) |
| Başkasının kuralını silme | 🔴 Kritik | ✅ Engellendi (`actor_member_id` doğrulaması) |
| Cron'u client'tan tetikleme | 🔴 Kritik | ✅ Engellendi (sadece `service_role`) |
| Çift masraf oluşturma | 🟡 Yüksek | ✅ Engellendi (UNIQUE + ON CONFLICT) |
| Geçmişe dönük kural | 🟡 Yüksek | ✅ Engellendi (`start_date < current_date` red) |
| `next_execution_date` manipülasyonu | 🟡 Yüksek | ✅ MVP'de güncellenmez |
| SQL injection | 🔴 Kritik | ✅ Tüm değerler parametrize (`p_` prefix) |
| Inactive üyeye split atama | 🟡 Orta | ✅ `validate_recurring_rule_splits` kontrol eder |

---

## 7. Hata ve Uç Durum Analizi

### 7.1 Kural oluşturulduktan sonra üye gruptan ayrılırsa?

- `paid_by` pasif ise → expense **oluşturulmaz**, execution `failed` loglanır
- Subset/custom split'teki bir üye pasif ise → aynı şekilde **başarısız**
- Equal split'te: sadece AKTIF üyeler arasında bölüşüm yapılır ✅

### 7.2 Kuralın grubu silinirse?

`ON DELETE CASCADE` → kural ve tüm execution kayıtları otomatik silinir. Oluşturulmuş expense'ler `ON DELETE SET NULL` sayesinde korunur.

### 7.3 Cron hiç çalışmazsa?

İki senaryo:
- **pg_cron kurulu değilse:** Migration `NOTICE` verip atlar. Harici cron servisi gerekir.
- **pg_cron kurulu ama tetiklenmediyse:** WHILE döngüsü sayesinde cron tekrar çalıştığında tüm kaçırılan periyotlar catch-up yapılır.

### 7.4 Aynı cron iki kez paralel çalışırsa?

`UNIQUE (rule_id, execution_date)` + `ON CONFLICT` sayesinde ilk gelen işlemi yapar, ikincisi atlar.

### 7.5 5 yıl sonra cron tekrar başlarsa?

WHILE döngüsü tüm kaçırılan periyotları teker teker işler. 5 yıl × 12 ay = 60 expense. Transaction başına çalıştığı için kilitlenme yapmaz.

---

## 8. Bug Fix Geçmişi

Commit sırasıyla tespit edilen ve düzeltilen hatalar:

| Commit | Hata | Sonuç |
|--------|------|-------|
| `98fbbe1` | Tablo adı uyuşmazlığı: Swift `recurring_expense_rules` → SQL `recurring_expenses_rules` | ✅ Düzeltildi |
| `98fbbe1` | `paidBy!` force-unwrap → `guard let payerId = paidBy` | ✅ Düzeltildi |
| `46bd5ec` | `NSCameraUsageDescription` eksik (fiş tarama için) | ⚠️ Özellik kaldırıldı |
| `8e428e3` | Fişten ekleme özelliği tamamen kaldırıldı | ✅ Temizlendi |
| `e573c44` | Masraf tutar fontu `display(16)` → `body(14)` + `lineLimit(1)` | ✅ Düzeltildi |
| `e573c44` | Kur bilgisi bar'ı herkese çıkıyordu → sadece `tr` locale | ✅ Düzeltildi |
| `e573c44` | Kur tarihi `HH:mm` içeriyordu → sadece tarih | ✅ Düzeltildi |
| `c74db6d` | pg_cron SQL: `cron.schedule()` DO bloğu dışında → hata | ✅ Düzeltildi |
| `1594215` | pg_cron SQL: iç içe `$$` çakışması → `$_$` delimiter | ✅ Düzeltildi |

---

## 9. Gelecek İyileştirmeleri

| Özellik | Öncelik | Açıklama |
|---------|---------|----------|
| Execution log UI | Orta | `recurring_expense_executions` tablosu client'ta hiç gösterilmiyor |
| Bildirim | Düşük | Kural başarısız olduğunda push notification |
| `next_execution_date` override | Düşük | Kullanıcı manuel olarak sonraki tarihi değiştirebilsin |
| Bitiş tarihi (`end_date`) | Düşük | Sınırlı süreli kurallar |
| Retry mekanizması UI | Düşük | Başarısız periyotları manuel tetikleme |
| Timezone awareness | Düşük | `current_date` yerine parametre olarak saat dilimi |

---

## 10. Sonuç

### ✅ Doğrulananlar

| Kontrol | Durum |
|---------|-------|
| Tablo adı (`recurring_expenses_rules`) | ✅ Düzeltildi |
| Kural CRUD (create/update/pause/delete) | ✅ RPC + yetki kontrolleri tam |
| Frekans motoru (weekly/monthly/yearly) | ✅ PostgreSQL interval, ay sonu uyumlu |
| Kaçırılan periyot catch-up | ✅ WHILE döngüsü ile |
| Idempotency (çift masraf engelleme) | ✅ UNIQUE + ON CONFLICT |
| Split validasyonu | ✅ 6 aşamalı sunucu tarafı kontrol |
| `created_by` güvenliği | ✅ Sunucuda `auth.uid()` çözümlemesi |
| Client Float/Double kullanımı | ✅ Yok, tüm tutarlar Int minor unit |
| RLS SELECT politikası | ✅ Sadece kendi grubunun kuralları |
| Hata durumunda motor kilidi | ✅ next_execution_date ilerletilir |
| pg_cron schedule migration | ✅ pg_cron yoksa NOTICE verir, varsa kurar |
| Dollar-quote iç içe çakışma | ✅ `$_$` delimiter ile çözüldü |
| Kur bilgisi locale gating | ✅ Sadece app dili Türkçe olanlara |
| Masraf tutar fontu | ✅ `body(14)` + `lineLimit(1)` |

### 📁 İlgili Dosyalar

| Dosya | Rol |
|-------|-----|
| `supabase/migrations/202606280001_recurring_expenses.sql` | Tablolar, RLS, RPC'ler, yetkilendirme |
| `supabase/migrations/202606280002_pg_cron_schedule.sql` | pg_cron schedule (hourly trigger) |
| `Groopay/Core/Models/RecurringExpenseRule.swift` | Kural ve split modelleri |
| `Groopay/Core/Models/RecurringExpenseExecution.swift` | Execution log modeli |
| `Groopay/Core/Supabase/GroupsStore.swift` | Store metotları (load/create/update/pause/delete) |
| `Groopay/Core/Supabase/RPC.swift` | RPC input yapıları ve RPCClient |
| `Groopay/Features/Groups/RecurringExpensesView.swift` | Kural listesi + RuleFormView |
| `Groopay/Features/Groups/GroupDetailView.swift` | "Tekrarlayan Masraflar" butonu + font fix |
| `Groopay/Features/Groups/AddExpenseView.swift` | Kur bilgisi bar'ı + locale gating |
| `docs/recurring-expenses-technical-audit.md` | Bu rapor |

---

**Raporu Hazırlayan:** Claude (Anthropic) — otomatik kod denetimi  
**Denetlenen Commit'ler:** `e588dcb` → `1594215` (9 commit, main branch)
