-- ============================================================================
-- pg_cron schedule: Tekrarlayan masraflar motorunu saat başı çalıştır
-- ============================================================================
-- Bu migration, recurring_expenses feature'ının kalbi olan cron tetikleyicisini
-- kurar. Motor HER SAAT başında çalışır ve o ana kadar execute edilmesi gereken
-- tüm periyotları sırayla işler.
--
-- ÖN KOŞUL: Supabase Dashboard → Database → Extensions → pg_cron ENABLED
-- Eğer pg_cron kurulu değilse bu migration başarısız olur.
-- Supabase'in ücretsiz planında pg_cron desteklenmez; bu durumda Pro plana
-- geçmek veya harici bir cron servisi (örn. GitHub Actions, Vercel Cron)
-- kullanarak execute_due_recurring_expenses() RPC'sini service_role key ile
-- periyodik olarak tetiklemek gerekir.
-- ============================================================================

-- Daha önce aynı isimde schedule varsa temizle (idempotent)
do $$
begin
    perform cron.unschedule('recurring-expenses-hourly');
exception
    when others then
        -- pg_cron mevcut değilse veya schedule zaten yoksa sessizce devam et
        null;
end;
$$;

-- Yeni schedule: her saatin başında (HH:00) çalışır
-- Dakika seviyesinde rastgele dağıtım için 0 yerine offset kullanılabilir
select cron.schedule(
    'recurring-expenses-hourly',
    '0 * * * *',                    -- her saat başı (UTC)
    $$ select execute_due_recurring_expenses(); $$
);

-- ============================================================================
-- ÖZET: Sıklık Seçimi Gerekçesi
-- ============================================================================
-- "0 * * * *" (her saat başı):
--   - Aylık kurallar için ~730 deneme/yıl (saatte 1)
--   - En kötü durum gecikme: 59 dakika
--   - Günlük kullanıcı beklentisi için yeterli
--
-- Alternatifler:
--   - "0 3 * * *" (her gece 03:00): yalnızca 365 deneme/yıl,
--     kullanıcı gün içinde oluşturduğu kuralın ertesi güne kadar
--     çalışmamasına sebep olur
--   - "*/30 * * * *" (30 dakikada bir): gereksiz sıklık,
--     veritabanına ek yük bindirir
-- ============================================================================
