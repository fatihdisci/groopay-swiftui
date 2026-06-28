# Tekrarlayan Masraflar (Recurring Expenses) — Teknik Denetim Raporu

**Sürüm:** 1.4.0 (build 39)  
**Tarih:** 2026-06-28  
**Son commit:** `2c1cce6`  
**Durum:** ✅ Canlı test başarılı — motor çalıştı, expense oluştu, idempotency doğrulandı, pg_cron aktif ve doğrulandı

---

## 1. Mimari Genel Bakış

```
┌─────────────────────────────┐      ┌──────────────────────────────────┐
│   SwiftUI Client (iOS 17+)  │      │   Supabase (PostgreSQL 15)        │
│                             │      │                                  │
│  RecurringExpensesView      │ RLS  │  recurring_expenses_rules        │
│  RuleFormView (+ sil butonu)│◄────►│  recurring_expense_executions    │
│  GroupsStore                │ SELECT│                                  │
│                             │      │  RPC (SECURITY DEFINER):          │
│  RecurringExpenseRule       │ RPC  │  create / update / pause          │
│  RecurringExpenseExecution  │◄────►│  delete / execute_due             │
│                             │      │                                  │
│  RPCClient (Supabase)       │      │  pg_cron (service_role)           │
│                             │      │  └─ saat başı tetiklenir          │
│  LocalizationStore          │      │     execute_due_recurring_        │
│  └─ FX rate bar gating      │      │     expenses()                   │
│                             │      │                                  │
│  DashboardView              │      │  REST API (service_role)          │
│  └─ balanceMetric font 24pt │      │  └─ manuel test için curl         │
└─────────────────────────────┘      └──────────────────────────────────┘
```

**Temel prensip:** Yazma işlemleri DOĞRUDAN tabloya değil, `SECURITY DEFINER` RPC fonksiyonları üzerinden yapılır. RLS politikaları yalnızca `SELECT` için tanımlıdır.

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

### 2.2 `recurring_expense_executions` (Idempotency)

| Kolon | Tip | Kısıt |
|-------|-----|-------|
| `id` | `uuid PK` | |
| `rule_id` | `uuid FK → recurring_expenses_rules(id)` | `ON DELETE CASCADE` |
| `execution_date` | `date NOT NULL` | |
| `expense_id` | `uuid FK → expenses(id)` | `ON DELETE SET NULL` |
| `error_message` | `text` | başarısızlık detayı |
| `executed_at` | `timestamptz NOT NULL` | |
| `status` | `text NOT NULL` | `CHECK IN ('processing','success','failed')` |
| **CONSTRAINT** | `recurring_expense_executions_rule_date_key` | `UNIQUE (rule_id, execution_date)` |

### 2.3 Migration Dosyaları

| Dosya | İçerik |
|-------|--------|
| `202606280001_recurring_expenses.sql` | Tablolar, RLS, trigger, tüm RPC'ler, yetkilendirmeler, constraint isimlendirme, `DROP FUNCTION` + `CREATE FUNCTION` (RETURNS TABLE imza değişikliğine izin vermek için) |
| `202606280002_pg_cron_schedule.sql` | pg_cron schedule (hourly, idempotent, pg_cron yoksa NOTICE) |
| `202606280003_fix_execution_date_ambiguity.sql` | `execution_date` → `processed_execution_date` output kolonu, `ON CONFLICT ON CONSTRAINT`, `public.` qualified refs, constraint rename hotfix |
| `202606280004_fix_split_type_cast.sql` | `v_rule.split_type::split_type` cast — expenses enum vs recurring_expenses_rules text uyuşmazlığı |

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
3. ⛔ `p_start_date < current_date` → geçmişe dönük backfill ENGELLENİR
4. `created_by` CLIENT'TAN ALINMAZ — `auth.uid()` ile sunucuda çözümlenir 🔐
5. `p_paid_by` aktif üye doğrulaması
6. `validate_recurring_rule_splits()` 6 aşamalı validasyon
7. `next_execution_date = p_start_date` olarak INSERT

### 3.2 `update_recurring_expense_rule`

```sql
update_recurring_expense_rule(
  p_rule_id, p_description, p_note, p_amount, p_currency,
  p_category, p_split_type, p_paid_by, p_actor_member_id,
  p_frequency, p_is_active, p_splits
) RETURNS void
```

⚠️ `next_execution_date` client tarafından güncellenmez (MVP kısıtı).

### 3.3 `pause_recurring_expense_rule`

```sql
pause_recurring_expense_rule(p_rule_id, p_actor_member_id, p_is_active)
```

Toggle: `is_active = true|false`. JOIN ile yetki kontrolü.

### 3.4 `delete_recurring_expense_rule`

```sql
delete_recurring_expense_rule(p_rule_id, p_actor_member_id)
```

Hard delete + cascade. `expense_id`'ler `ON DELETE SET NULL` ile korunur.

### 3.5 `validate_recurring_rule_splits` (PUBLIC/ANONYMOUS erişimi REVOKE)

| # | Kontrol | Hata Kodu |
|---|---------|-----------|
| 1 | `p_amount > 0` | `22003` |
| 2 | `p_split_type IN ('equal','custom','subset')` | `22023` |
| 3 | Splits JSON array mi? | `22023` |
| 4 | Custom/subset için splits boş olamaz | `22023` |
| 5 | Yinelenen `member_id` + aktif üyelik validasyonu | `23505` / `42501` |
| 6 | Custom için `SUM(share_amount) == p_amount` | `22000` |

---

## 4. Cron / İşletici Motor (`execute_due_recurring_expenses`)

### 4.1 Yetkilendirme

```sql
revoke all on function execute_due_recurring_expenses() from public, authenticated;
grant  execute on function execute_due_recurring_expenses() to service_role;
```

### 4.2 pg_cron Schedule

**Migration:** `202606280002_pg_cron_schedule.sql`

```sql
do $$
begin
    if not exists (select 1 from pg_extension where extname = 'pg_cron') then
        raise notice 'pg_cron bulunamadı — atlandı.';
        return;
    end if;
    perform cron.unschedule('recurring-expenses-hourly');
    perform cron.schedule(
        'recurring-expenses-hourly',
        '0 * * * *',
        $_$ select execute_due_recurring_expenses(); $_$
    );
end;
$$;
```

**Önemli:** `$_$` delimiter'ı, içteki `$$` ile dıştaki `DO $$` çakışmasını önler.

**⏱️ 2026-06-28: pg_cron schedule aktif olarak doğrulandı.** Superuser SQL konsolundan `SELECT * FROM cron.job` sorgulandığında `jobname='recurring-expenses-hourly'`, `schedule='0 * * * *'`, `active=true` olarak görülmektedir. Cron motoru saat başı tetiklenmeye hazırdır.

### 4.3 Çalışma Mantığı

```
v_current_date = current_date

FOR EACH rule WHERE is_active = true AND next_execution_date <= v_current_date:
    v_next_date = rule.next_execution_date

    WHILE v_next_date <= v_current_date:          ← kaçırılan periyotları yakala
        INSERT INTO executions ... ON CONFLICT ON CONSTRAINT ... ← idempotency
        IF v_execution_id IS NOT NULL:
            BEGIN
                paid_by aktiflik kontrolü
                INSERT INTO expenses (..., split_type::split_type, ...)
                INSERT INTO expense_splits (equal/subset/custom)
                UPDATE executions SET status='success'
                RETURN NEXT
            EXCEPTION WHEN OTHERS:
                UPDATE executions SET status='failed', error_message=SQLERRM
                (expense + splits otomatik ROLLBACK)
            END
        v_next_date += frequency_interval
    UPDATE rule SET next_execution_date = v_next_date
```

### 4.4 Frekans İlerletme

| Frekans | SQL Interval | Ay Sonu Davranışı |
|---------|-------------|-------------------|
| `weekly` | `+ interval '1 week'` | 7 gün |
| `monthly` | `+ interval '1 month'` | 31 Ocak → 28 Şubat ✅ |
| `yearly` | `+ interval '1 year'` | Artık yıl uyumlu |

### 4.5 Idempotency

| Senaryo | Sonuç |
|---------|-------|
| İlk kez çalışıyor | expense oluşturulur |
| Daha önce `success` | ATLANIR ✅ |
| Daha önce `processing` | ATLANIR ✅ |
| Daha önce `failed` | TEKRAR DENER ✅ |

---

## 5. Canlı Test Sonuçları (2026-06-28)

### 5.1 Test Ortamı

- **Proje:** `dtlnujqtwlncwrxunihj` (Supabase)
- **Test kuralları:** "Abone" (500 ₺/ay), "Youtube premium" (150 ₺/ay)
- **Metod:** `curl` + `service_role` JWT ile REST API üzerinden manuel tetikleme

### 5.2 Motor Çalıştırma

```json
// POST /rest/v1/rpc/execute_due_recurring_expenses
[
    {
        "executed_rule_id": "5ac0a3a5-...",
        "created_expense_id": "7b5cb560-...",
        "processed_execution_date": "2026-06-28"
    },
    {
        "executed_rule_id": "6f0d458d-...",
        "created_expense_id": "8d3b9893-...",
        "processed_execution_date": "2026-06-28"
    }
]
```

✅ **2 kural → 2 expense oluşturuldu**

### 5.3 Execution Log

```
rule_id                              | execution_date | status  | error_message | expense_id
5ac0a3a5-c830-492a-bed3-97c33805892f | 2026-06-28     | success | null          | 7b5cb560-...
6f0d458d-265b-418f-8341-3e0e188231c7 | 2026-06-28     | success | null          | 8d3b9893-...
```

✅ **İkisi de `success`, hata yok**

### 5.4 Idempotency Testi

```json
// İkinci çağrı
[]
```

✅ **Boş döndü — çift expense oluşturulmadı**

### 5.5 Oluşturulan Masraflar

```
description       | amount | currency | expense_date
Youtube premium   | 150.00 | TRY      | 2026-06-28
Abone             | 500.00 | TRY      | 2026-06-28
```

✅ **App'te grupta görünüyor**

### 5.6 pg_cron Schedule Doğrulama

```sql
-- Supabase SQL Editor'da çalıştırıldı
SELECT jobname, schedule, active, jobid
  FROM cron.job
 WHERE jobname = 'recurring-expenses-hourly';
```

```
jobname                | schedule   | active | jobid
recurring-expenses-hourly | 0 * * * * | t      | 1
```

✅ **pg_cron schedule aktif, `0 * * * *` (saat başı), `active=true`**

---

## 6. İstemci (SwiftUI) Katmanı

### 6.1 Modeller

| Model | Dosya |
|-------|-------|
| `RecurringExpenseRule` | `Core/Models/RecurringExpenseRule.swift` |
| `RecurringSplitEntry` | Aynı dosya |
| `RecurringExpenseExecution` | `Core/Models/RecurringExpenseExecution.swift` |
| `RecurringFrequency` | Aynı dosya (`enum: weekly, monthly, yearly`) |

### 6.2 GroupsStore Metotları

| Metot | RPC | Auth |
|-------|-----|------|
| `loadRecurringRules(for:)` | `SELECT recurring_expenses_rules` | RLS |
| `createRecurringRule(...)` | `create_recurring_expense_rule` | SECURITY DEFINER |
| `updateRecurringRule(...)` | `update_recurring_expense_rule` | SECURITY DEFINER + actor |
| `pauseRecurringRule(...)` | `pause_recurring_expense_rule` | SECURITY DEFINER + actor |
| `deleteRecurringRule(...)` | `delete_recurring_expense_rule` | SECURITY DEFINER + actor |

### 6.3 UI Akışı

```
GroupDetailView
  └── "Tekrarlayan Masraflar" butonu → RecurringExpensesView sheet
        ├── Liste
        │   ├── Toggle → pause/resume
        │   ├── Tap → RuleFormView (edit)
        │   ├── Swipe → delete
        │   └── RuleFormView → "Kuralı Sil" butonu (kırmızı, confirmation dialog)
        └── "Yeni Kural Ekle" → RuleFormView (create)
```

### 6.4 UI Düzeltmeleri

| Yer | Önce | Sonra |
|-----|------|-------|
| Expenses listesi tutar fontu | `.display(16)` | `.body(14)` + `.lineLimit(1)` |
| Dashboard "Genel Durum" tutar | `.system(size: 31)` | `.system(size: 24)` + `.minimumScaleFactor(0.72)` |
| Kur bilgisi bar görünürlüğü | Herkese | Sadece app dili `tr` olanlara |
| Kur tarihi formatı | `d MMM yyyy HH:mm` | `d MMM yyyy` (saat yok) |

---

## 7. Güvenlik Denetimi

| Risk | Seviye | Durum |
|------|--------|-------|
| Başkası adına kural oluşturma | 🔴 Kritik | ✅ `created_by` sunucuda `auth.uid()` ile çözülür |
| Başkasının kuralını silme | 🔴 Kritik | ✅ `actor_member_id` doğrulaması |
| Cron'u client'tan tetikleme | 🔴 Kritik | ✅ Sadece `service_role` |
| Çift masraf oluşturma | 🟡 Yüksek | ✅ UNIQUE constraint + ON CONFLICT |
| Geçmişe dönük kural | 🟡 Yüksek | ✅ `start_date < current_date` red |
| SQL injection | 🔴 Kritik | ✅ Parametrize (`p_` prefix) |
| `split_type` enum vs text | 🟡 Yüksek | ✅ `::split_type` cast |
| `execution_date` column ambiguity | 🟡 Yüksek | ✅ Output kolonu `processed_execution_date` |

---

## 8. Bug Fix Geçmişi (Kronolojik)

| # | Commit | Sorun | Çözüm |
|---|--------|-------|-------|
| 1 | `98fbbe1` | Tablo adı: `recurring_expense_rules` → `recurring_expenses_rules` | Swift'te isim düzeltildi |
| 2 | `98fbbe1` | `paidBy!` force-unwrap | `guard let payerId = paidBy` |
| 3 | `8e428e3` | Fişten ekleme kaldırıldı | 7 dosya silindi |
| 4 | `e573c44` | Masraf tutar fontu çok büyük | `display(16)` → `body(14)` |
| 5 | `e573c44` | Kur bar'ı herkese çıkıyor | `LocalizationStore` locale check |
| 6 | `e573c44` | Kur tarihi saatli | Sadece `d MMM yyyy` |
| 7 | `c74db6d` | pg_cron `schema "cron" does not exist` | DO bloğu + extension check |
| 8 | `1594215` | pg_cron `$$` iç içe syntax error | `$_$` delimiter |
| 9 | `73362c4` | `execution_date` column ambiguous (42702) | Named constraint + output rename + qualified refs |
| 10 | `12d5160` | `CREATE OR REPLACE` imza değişikliği red (42P13) | `DROP FUNCTION` + `CREATE FUNCTION` |
| 11 | `9218a71` | RuleFormView'da silme butonu yok | "Kuralı Sil" + confirmation dialog |
| 12 | `1fb2898` | Dashboard tutar fontu 31pt → taşma | `system(size: 24)` |
| 13 | `83b48c6` | `split_type` enum vs text cast hatası | `::split_type` cast eklendi |
| 14 | `2c1cce6` | Canlı test: 2 expense oluştu, idempotency doğrulandı | Migration 004 + test |

---

## 9. Sonuç

### ✅ Canlı Testte Doğrulananlar

| Test | Sonuç |
|------|-------|
| Motor manuel tetikleme (`curl` + `service_role`) | ✅ 2 expense oluştu |
| Execution log (`status = 'success'`) | ✅ Hata yok |
| Idempotency (ikinci çağrı boş döndü) | ✅ Çift masraf yok |
| Masraflar `expenses` tablosunda | ✅ App'te görünür |
| Delete UI (swipe + buton) | ✅ Çift yöntem |
| Dashboard fontu | ✅ `2.000,00` sığıyor |
| pg_cron schedule (`cron.job` sorgusu) | ✅ `active=true`, `0 * * * *` saat başı |

### 📁 Tüm Dosyalar

| Dosya | Rol |
|-------|-----|
| `supabase/migrations/202606280001_recurring_expenses.sql` | Tablolar, RLS, 8 RPC, yetkilendirme |
| `supabase/migrations/202606280002_pg_cron_schedule.sql` | pg_cron schedule |
| `supabase/migrations/202606280003_fix_execution_date_ambiguity.sql` | Output rename + constraint hotfix |
| `supabase/migrations/202606280004_fix_split_type_cast.sql` | `::split_type` cast fix |
| `Groopay/Core/Models/RecurringExpenseRule.swift` | Kural + split modelleri |
| `Groopay/Core/Models/RecurringExpenseExecution.swift` | Execution log modeli |
| `Groopay/Core/Supabase/GroupsStore.swift` | CRUD metotları |
| `Groopay/Core/Supabase/RPC.swift` | RPC input/output yapıları |
| `Groopay/Features/Groups/RecurringExpensesView.swift` | Liste + RuleFormView (+ sil butonu) |
| `Groopay/Features/Groups/GroupDetailView.swift` | "Tekrarlayan Masraflar" butonu |
| `Groopay/Features/Groups/AddExpenseView.swift` | Kur bilgisi bar'ı (locale gated) |
| `Groopay/Features/Dashboard/DashboardView.swift` | Genel Durum kartı (font fix) |
| `docs/recurring-expenses-technical-audit.md` | Bu rapor |
| `docs/BUGFIX-CILA.md` | Bugfix kayıtları |

---

**Raporu Hazırlayan:** Claude (Anthropic)  
**Denetlenen Commit'ler:** `e588dcb` → `2c1cce6` (15 commit, main branch)  
**Canlı Test:** 2026-06-28 — `dtlnujqtwlncwrxunihj.supabase.co` — ✅ Başarılı
