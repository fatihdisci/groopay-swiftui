# Tekrarlayan Masraflar (Recurring Expenses) — Teknik Denetim Raporu

**Sürüm:** 1.4.0 (build 39)  
**Tarih:** 2026-06-28  
**Kapsam:** `B119` commit serisi — recurring expenses motoru ve istemci entegrasyonu

---

## 1. Mimari Genel Bakış

```
┌─────────────────────────────┐      ┌──────────────────────────────┐
│   SwiftUI Client (iOS 17+)  │      │   Supabase (PostgreSQL 15)    │
│                             │      │                              │
│  RecurringExpensesView      │ RLS  │  recurring_expenses_rules    │
│  RuleFormView               │◄────►│  recurring_expense_executions│
│  GroupsStore                │ SELECT│                              │
│                             │      │  RPC (SECURITY DEFINER):      │
│  RecurringExpenseRule       │ RPC  │  create / update / pause      │
│  RecurringExpenseExecution  │◄────►│  delete / execute_due         │
│                             │      │                              │
│  RPCClient (Supabase)       │      │  pg_cron (service_role)      │
└─────────────────────────────┘      └──────────────────────────────┘
```

**Temel prensip:** Yazma işlemleri DOĞRUDAN tabloya değil, `SECURITY DEFINER` RPC fonksiyonları üzerinden yapılır. RLS politikaları yalnızca `SELECT` için tanımlıdır. Bu sayede istemci hiçbir zaman tabloya doğrudan `INSERT/UPDATE/DELETE` yapamaz.

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
| `next_execution_date` | `date NOT NULL` | motorun gözü burada |
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

**Güvenlik:** `created_by` parametresi client'tan alınsaydı, bir kullanıcı başkasının adına kural oluşturabilirdi. Sunucu tarafında `auth.uid()` çözümlemesi bunu engeller.

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
6. ⚠️ **NOT:** `next_execution_date` client tarafından güncellenmez (MVP kısıtı)
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

SADECE `service_role` çağırabilir. Normal kullanıcılar veya anonim erişim tamamen engellenmiştir. Bu, motorun yalnızca pg_cron tarafından tetiklenebileceği anlamına gelir.

### 4.2 Çalışma Mantığı (Detaylı)

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

### 4.3 Frekans Periyodu İlerletme

| Frekans | SQL Interval | Açıklama |
|---------|-------------|----------|
| `weekly` | `+ interval '1 week'` | 7 gün |
| `monthly` | `+ interval '1 month'` | PostgreSQL ay sonlarını doğru yönetir (31 Ocak → 28 Şubat) |
| `yearly` | `+ interval '1 year'` | Artık yıl uyumlu |

### 4.4 Kaçırılan Periyotlar (Catch-up)

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

### 4.5 Idempotency — Mükerrer Kayıt Engelleme

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
| Daha önce başarılı (`success`) | `WHERE status='failed'` eşleşmez → UPDATE atlanır | `v_execution_id` NULL → ATLANIR ✅ |
| Daha önce işleniyor (`processing`) | Aynı şekilde UPDATE atlanır | `v_execution_id` NULL → ATLANIR ✅ |
| Daha önce başarısız (`failed`) | UPDATE çalışır, `RETURNING id` dolu | `v_execution_id` dolu → TEKRAR DENE ✅ |

### 4.6 Hata Durumunda Davranış

```
BEGIN
    INSERT INTO expenses ...         ─┐
    INSERT INTO expense_splits ...    ├── hata olursa otomatik ROLLBACK
    UPDATE executions SET status...  ─┘
EXCEPTION WHEN OTHERS:
    UPDATE executions SET status='failed', error_message=SQLERRM
    -- next_execution_date yine de ilerletilir (motor kilitlenmesin diye)
```

**Önemli:** Başarısız periyotlar gelecekteki otomatik cron çalıştırmalarında tekrar denenmez. `next_execution_date` ilerletildiği için o periyot geçilir. Ancak:
- `next_execution_date` veritabanından manuel olarak geri çekilirse
- Veya aynı periyot için `ON CONFLICT DO UPDATE ... WHERE status='failed'` mekanizmasıyla retry mümkündür

---

## 5. İstemci (SwiftUI) Katmanı

### 5.1 Modeller

**`RecurringExpenseRule`** — ana model. Tüm tutarlar `Int` (minor unit/kuruş). `startDate` ve `nextExecutionDate` opsiyonel çünkü veritabanı `date` tipini string olarak dönebilir (esnek decode). Currency her zaman `uppercased()`.

**`RecurringSplitEntry`** — split başına `memberId` + `shareAmount`. Kodlama/çözümleme `decimalAmount(fromMinor:)` / `decodeMinorAmount` ile yapılır.

**`RecurringExpenseExecution`** — motor çalışma kaydı. `expenseId` başarılı çalıştırmalarda oluşturulan masrafa link verir.

**`RecurringFrequency`** — `enum: weekly, monthly, yearly`

### 5.2 GroupsStore Metotları

| Metot | RPC | Auth |
|-------|-----|------|
| `loadRecurringRules(for:)` | `SELECT recurring_expenses_rules` | RLS |
| `createRecurringRule(...)` | `create_recurring_expense_rule` | SECURITY DEFINER → `auth.uid()` |
| `updateRecurringRule(...)` | `update_recurring_expense_rule` | SECURITY DEFINER + `p_actor_member_id` |
| `pauseRecurringRule(...)` | `pause_recurring_expense_rule` | SECURITY DEFINER + `p_actor_member_id` |
| `deleteRecurringRule(...)` | `delete_recurring_expense_rule` | SECURITY DEFINER + `p_actor_member_id` |

Tüm yazma işlemleri `actor` (currentMemberID) kontrolü yapar. Kullanıcının gruptaki aktif üyeliği doğrulanır.

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

**RuleFormView:**
- Açıklama + Tutar + Para Birimi
- Frekans seçici (Haftalık/Aylık/Yıllık)
- Başlangıç tarihi (DatePicker, geçmiş tarih seçilemez → sunucuda da validasyon var)
- Kategori seçici
- Ödeyen seçici (Menu)
- Bölüşüm tipi: Eşit / Alt-Küme / Özel
- Kaydet butonu → `isValid()` kontrolü:
  - `amountMinor > 0`
  - Açıklama boş değil
  - `paidBy != nil`
  - Splits toplamı == amountMinor

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
| Kural güncellerken `next_execution_date` manipülasyonu | 🟡 Yüksek | ✅ MVP'de güncellenmez |
| SQL injection | 🔴 Kritik | ✅ Tüm değerler parametrize (`p_` prefix) |
| Inactive üyeye split atama | 🟡 Orta | ✅ `validate_recurring_rule_splits` kontrol eder |

---

## 7. Hata ve Uç Durum Analizi

### 7.1 Kural oluşturulduktan sonra üye gruptan ayrılırsa?

**Cron motoru çalıştığında:**
- `paid_by` pasif ise → `raise exception` → expense **oluşturulmaz**, execution `failed` loglanır
- Subset/custom split'teki bir üye pasif ise → `raise exception` → aynı şekilde **başarısız** olur
- Equal split'te: sadece AKTIF üyeler arasında bölüşüm yapılır, pasif olanlar yok sayılır ✅

### 7.2 Kuralın grubu silinirse?

`ON DELETE CASCADE` → kural ve tüm execution kayıtları otomatik silinir. Oluşturulmuş expense'ler `ON DELETE SET NULL` sayesinde korunur.

### 7.3 Cron hiç çalışmazsa?

pg_cron schedule'ı Supabase Dashboard'dan yapılandırılmalıdır. Migration sadece fonksiyonu oluşturur, schedule içermez.

### 7.4 Aynı cron iki kez paralel çalışırsa?

`UNIQUE (rule_id, execution_date)` + `ON CONFLICT` sayesinde ilk gelen işlemi yapar, ikincisi `v_execution_id = NULL` alır ve atlar.

### 7.5 5 yıl sonra cron tekrar başlarsa?

WHILE döngüsü tüm kaçırılan periyotları teker teker işler. 5 yıl × 12 ay = 60 expense oluşturulur. Bu uzun sürebilir ancak transaction başına çalıştığı için kilitlenme yapmaz.

---

## 8. Eksikler ve Öneriler

### 8.1 ⚠️ Cron Schedule Eksik

**Durum:** Migration `execute_due_recurring_expenses()` fonksiyonunu oluşturur ancak pg_cron schedule'ı tanımlanmaz.

**Aksiyon:** Supabase Dashboard → SQL Editor'da:
```sql
select cron.schedule(
  'recurring-expenses-hourly',
  '0 * * * *',           -- her saatin başında
  $$ select execute_due_recurring_expenses(); $$
);
```

**Öneri:** Bu schedule'ı migration'a ekleyin veya ayrı bir migration olarak yönetin.

### 8.2 🟡 Timezone Farkındalığı

`current_date` PostgreSQL'in saat dilimini kullanır. Supabase genelde UTC'dir. Türkiye (UTC+3) kullanıcıları için gün sınırı 3 saat kayabilir. MVP için kabul edilebilir, ancak ileride `current_date` yerine parametre olarak saat dilimi alınabilir.

### 8.3 🟢 Gelecek İyileştirmeleri

| Özellik | Öncelik | Açıklama |
|---------|---------|----------|
| Execution log UI | Orta | `recurring_expense_executions` tablosu client'ta hiç gösterilmiyor |
| Bildirim | Düşük | Kural başarısız olduğunda push notification |
| `next_execution_date` override | Düşük | Kullanıcı manuel olarak sonraki tarihi değiştirebilsin |
| Bitiş tarihi | Düşük | `end_date` ile sınırlı süreli kurallar |
| Retry mekanizması UI | Düşük | Başarısız periyotları manuel tetikleme |

---

## 9. Sonuç

### ✅ Çalıştığı Doğrulananlar

| Kontrol | Durum |
|---------|-------|
| Tablo adı eşleşmesi (`recurring_expenses_rules`) | ✅ Düzeltildi |
| Kural CRUD (create/update/pause/delete) | ✅ RPC + yetki kontrolleri tam |
| Frekans motoru (weekly/monthly/yearly) | ✅ PostgreSQL interval, ay sonu uyumlu |
| Kaçırılan periyot catch-up | ✅ WHILE döngüsü ile |
| Idempotency (çift masraf engelleme) | ✅ UNIQUE + ON CONFLICT |
| Split validasyonu | ✅ 6 aşamalı sunucu tarafı kontrol |
| `created_by` güvenliği | ✅ Sunucuda `auth.uid()` çözümlemesi |
| Client Float/Double kullanımı | ✅ Yok, tüm tutarlar Int minor unit |
| RLS SELECT politikası | ✅ Sadece kendi grubunun kuralları |
| Hata durumunda motor kilidi | ✅ next_execution_date ilerletilir |
| paid_by inactive olduğunda koruma | ✅ Exception + failed log |

### ⚠️ Aksiyon Gerektiren

| Konu | Aksiyon |
|------|---------|
| pg_cron schedule tanımı | Migration'a eklenmeli veya manuel kurulmalı |

---

**Raporu Hazırlayan:** Claude (Anthropic) — otomatik kod denetimi  
**Denetlenen Commit'ler:** `e588dcb`, `98fbbe1`, `ded018a`, `8e428e3`
