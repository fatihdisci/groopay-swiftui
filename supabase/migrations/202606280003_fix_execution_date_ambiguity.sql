-- ============================================================================
-- Hotfix: execute_due_recurring_expenses() execution_date ambiguity
-- ============================================================================
-- Sorun: RETURNS TABLE içindeki "execution_date" output kolonu ile
-- recurring_expense_executions.execution_date tablo kolonu çakışıyordu.
-- ON CONFLICT (rule_id, execution_date) ve RETURNING id satırlarında
-- PostgreSQL referansın hangisi olduğunu çözemiyordu.
--
-- Çözüm:
-- 1. Constraint'e açık isim ver (recurring_expense_executions_rule_date_key)
-- 2. ON CONFLICT ON CONSTRAINT ile constraint adıyla referans ver
-- 3. Output kolonu processed_execution_date olarak yeniden adlandır
-- 4. Tablo referanslarını public. önekiyle nitelendir
-- ============================================================================

-- Adım 1: Eski isimsiz unique constraint'i kaldır, yerine isimli constraint ekle
do $$
declare
    v_old_constraint text;
begin
    select con.conname into v_old_constraint
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    where rel.relname = 'recurring_expense_executions'
      and con.contype = 'u';

    if v_old_constraint is not null then
        execute format('alter table public.recurring_expense_executions drop constraint %I', v_old_constraint);
    end if;
end;
$$;

-- Adım 2: İsimli unique constraint ekle (zaten varsa öncekini düşürdük)
alter table public.recurring_expense_executions
  add constraint recurring_expense_executions_rule_date_key
  unique (rule_id, execution_date);

-- Adım 3: Fonksiyonu yeniden oluştur (DROP + CREATE — RETURNS TABLE imzası değiştiği için OR REPLACE yetmez)
drop function if exists public.execute_due_recurring_expenses();
create function public.execute_due_recurring_expenses()
returns table(
  executed_rule_id uuid,
  created_expense_id uuid,
  processed_execution_date date
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rule record;
  v_current_date date;
  v_next_date date;
  v_execution_id uuid;
  v_expense_id uuid;
  v_member_id uuid;
  v_share numeric(14,2);
  v_split record;
  v_members_count int;
  v_equal_share numeric(14,2);
  v_total_equal_shares numeric(14,2);
  v_remainder numeric(14,2);
  v_count int;
  v_active_member_ids uuid[];
begin
  v_current_date := current_date;

  for v_rule in
    select * from public.recurring_expenses_rules
    where is_active = true
      and next_execution_date <= v_current_date
  loop
    v_next_date := v_rule.next_execution_date;

    while v_next_date <= v_current_date loop
      v_execution_id := null;

      -- Idempotency ve Race Condition Koruması:
      -- ON CONFLICT ON CONSTRAINT ile constraint adıyla referans —
      -- output parametresi execution_date ile çakışma engellendi.
      insert into public.recurring_expense_executions (rule_id, execution_date, status)
      values (v_rule.id, v_next_date, 'processing')
      on conflict on constraint recurring_expense_executions_rule_date_key
      do update
        set status = 'processing',
            error_message = null,
            executed_at = now()
        where public.recurring_expense_executions.status = 'failed'
      returning public.recurring_expense_executions.id into v_execution_id;

      if v_execution_id is not null then
        begin
          -- 1. Ödeyen üyenin grupta hâlâ aktif olup olmadığını doğrula
          if not exists (
            select 1 from public.group_members gm
            where gm.id = v_rule.paid_by
              and gm.group_id = v_rule.group_id
              and gm.is_active = true
          ) then
            raise exception 'Ödeyen üye (paid_by) artık bu grupta aktif bir üye değil' using errcode = '42501';
          end if;

          -- 2. Harcamayı oluştur
          insert into public.expenses (
            group_id, description, note, amount, currency, category, split_type, paid_by, created_by, expense_date
          ) values (
            v_rule.group_id, v_rule.description, v_rule.note, v_rule.amount, v_rule.currency, v_rule.category, v_rule.split_type, v_rule.paid_by, v_rule.created_by, v_next_date
          ) returning id into v_expense_id;

          -- 3. Bölüşümleri hesapla ve ekle
          if v_rule.split_type = 'equal' then
            select array_agg(id) into v_active_member_ids
            from public.group_members
            where group_id = v_rule.group_id
              and is_active = true;

            v_members_count := array_length(v_active_member_ids, 1);
            if v_members_count is null or v_members_count = 0 then
              raise exception 'Harcamayı bölecek aktif grup üyesi bulunamadı' using errcode = '22023';
            end if;

            v_equal_share := round(v_rule.amount / v_members_count, 2);
            v_remainder := v_rule.amount - (v_equal_share * v_members_count);

            for v_count in 1..v_members_count loop
              v_share := v_equal_share;
              if v_count = 1 then
                v_share := v_share + v_remainder;
              end if;

              insert into public.expense_splits (expense_id, member_id, share_amount)
              values (v_expense_id, v_active_member_ids[v_count], v_share);
            end loop;

          elsif v_rule.split_type = 'subset' then
            select count(*) into v_members_count
            from jsonb_to_recordset(v_rule.splits) as s(member_id uuid)
            join public.group_members gm on gm.id = s.member_id
            where gm.group_id = v_rule.group_id
              and gm.is_active = true;

            if v_members_count != jsonb_array_length(v_rule.splits) then
              raise exception 'Alt kümedeki üyelerden biri veya birkaçı artık grupta aktif değil' using errcode = '42501';
            end if;

            select array_agg(gm.id) into v_active_member_ids
            from public.group_members gm
            join jsonb_to_recordset(v_rule.splits) as s(member_id uuid) on s.member_id = gm.id
            where gm.group_id = v_rule.group_id
              and gm.is_active = true;

            v_members_count := array_length(v_active_member_ids, 1);
            if v_members_count is null or v_members_count = 0 then
              raise exception 'Bölüşümdeki alt küme üyelerinden hiçbiri grupta aktif değil' using errcode = '22023';
            end if;

            v_equal_share := round(v_rule.amount / v_members_count, 2);
            v_remainder := v_rule.amount - (v_equal_share * v_members_count);

            for v_count in 1..v_members_count loop
              v_share := v_equal_share;
              if v_count = 1 then
                v_share := v_share + v_remainder;
              end if;

              insert into public.expense_splits (expense_id, member_id, share_amount)
              values (v_expense_id, v_active_member_ids[v_count], v_share);
            end loop;

          else -- 'custom'
            select count(*) into v_members_count
            from jsonb_to_recordset(v_rule.splits) as s(member_id uuid)
            join public.group_members gm on gm.id = s.member_id
            where gm.group_id = v_rule.group_id
              and gm.is_active = true;

            if v_members_count != jsonb_array_length(v_rule.splits) then
              raise exception 'Özel bölüşüm listesindeki üyelerden biri veya birkaçı artık grupta aktif değil' using errcode = '42501';
            end if;

            v_total_equal_shares := 0;
            v_count := 0;

            for v_split in
              select s.member_id, s.share_amount
              from jsonb_to_recordset(v_rule.splits) as s(member_id uuid, share_amount numeric(14,2))
              join public.group_members gm on gm.id = s.member_id
              where gm.group_id = v_rule.group_id and gm.is_active = true
            loop
              v_count := v_count + 1;
              v_share := v_split.share_amount;
              v_total_equal_shares := v_total_equal_shares + v_share;

              insert into public.expense_splits (expense_id, member_id, share_amount)
              values (v_expense_id, v_split.member_id, v_share);
            end loop;

            if v_count = 0 then
              raise exception 'Özel bölüşüm üyelerinden hiçbiri grupta aktif değil' using errcode = '22023';
            end if;

            v_remainder := v_rule.amount - v_total_equal_shares;
            if v_remainder != 0 then
              update public.expense_splits
              set share_amount = share_amount + v_remainder
              where expense_id = v_expense_id
                and member_id = (
                  select member_id
                  from public.expense_splits
                  where expense_id = v_expense_id
                  limit 1
                );
            end if;
          end if;

          -- Başarılı durumu güncelle ve expense_id bağla
          update public.recurring_expense_executions
          set status = 'success',
              expense_id = v_expense_id
          where id = v_execution_id;

          executed_rule_id := v_rule.id;
          created_expense_id := v_expense_id;
          processed_execution_date := v_next_date;
          return next;

        exception when others then
          update public.recurring_expense_executions
          set status = 'failed',
              error_message = SQLERRM
          where id = v_execution_id;
        end;
      end if;

      -- Tarihi ilerlet (başarısız olsa bile)
      if v_rule.frequency = 'weekly' then
        v_next_date := v_next_date + interval '1 week';
      elsif v_rule.frequency = 'monthly' then
        v_next_date := v_next_date + interval '1 month';
      elsif v_rule.frequency = 'yearly' then
        v_next_date := v_next_date + interval '1 year';
      else
        exit;
      end if;
    end loop;

    update public.recurring_expenses_rules
    set next_execution_date = v_next_date
    where id = v_rule.id;

  end loop;
end;
$$;

-- Adım 4: Yetkilendirmeleri yeniden uygula (CREATE OR REPLACE ile sıfırlanmış olabilir)
revoke all on function public.execute_due_recurring_expenses() from public, authenticated;
grant execute on function public.execute_due_recurring_expenses() to service_role;
