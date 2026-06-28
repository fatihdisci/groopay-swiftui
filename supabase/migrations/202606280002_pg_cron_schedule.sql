-- ============================================================================
-- pg_cron schedule: Tekrarlayan masraflar motorunu saat başı çalıştır
-- ============================================================================
-- Bu migration, recurring_expenses feature'ının kalbi olan cron tetikleyicisini
-- kurar. Motor HER SAAT başında çalışır ve o ana kadar execute edilmesi gereken
-- tüm periyotları sırayla işler.
--
-- ÖN KOŞUL: Supabase Dashboard → Database → Extensions → pg_cron ENABLED
--
-- Supabase ücretsiz planında pg_cron desteklenmez. Bu migration, pg_cron
-- mevcut değilse hiçbir şey yapmaz (sessizce atlanır).
--
-- ALTERNATİF: Harici bir cron servisi (GitHub Actions, Vercel Cron, vb.)
-- kullanarak execute_due_recurring_expenses() RPC'sini service_role key ile
-- periyodik olarak tetikleyebilirsiniz.
-- ============================================================================

do $$
begin
    -- pg_cron kurulu değilse hiçbir şey yapma
    if not exists (
        select 1 from pg_extension where extname = 'pg_cron'
    ) then
        raise notice 'pg_cron extension bulunamadı — cron schedule atlandı. Supabase Dashboard → Extensions altından pg_cron''u etkinleştirin veya harici bir cron servisi kullanın.';
        return;
    end if;

    -- Daha önce aynı isimde schedule varsa temizle
    perform cron.unschedule('recurring-expenses-hourly');

    -- Her saat başı (HH:00 UTC) çalışacak schedule
    perform cron.schedule(
        'recurring-expenses-hourly',
        '0 * * * *',
        $_$ select execute_due_recurring_expenses(); $_$
    );

    raise notice 'pg_cron schedule "recurring-expenses-hourly" başarıyla kuruldu.';
end;
$$;
