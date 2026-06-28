-- 1. Tekrarlayan masraf kurallarını saklayan tablo
create table if not exists public.recurring_expenses_rules (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  description text not null,
  note text,
  amount numeric(14,2) not null,
  currency varchar(3) not null,
  category text not null,
  split_type text not null check (split_type in ('equal', 'custom', 'subset')),
  paid_by uuid not null references public.group_members(id) on delete cascade,
  created_by uuid not null references public.group_members(id) on delete cascade,
  frequency text not null check (frequency in ('weekly', 'monthly', 'yearly')),
  start_date date not null,
  next_execution_date date not null,
  is_active boolean not null default true,
  splits jsonb not null, -- Paylaşım detayları/üyeleri
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- RLS Aktifleştirme
alter table public.recurring_expenses_rules enable row level security;

-- Yazma işlemleri doğrudan tablodan değil, RLS bypass eden SECURITY DEFINER RPC’ler üzerinden yapılır.
-- Bu nedenle RLS politikaları olarak sadece okuma (SELECT) yetkisi tanımlanmıştır.
drop policy if exists "Users can view recurring rules of their groups" on public.recurring_expenses_rules;
create policy "Users can view recurring rules of their groups"
  on public.recurring_expenses_rules
  for select
  to authenticated
  using (
    exists (
      select 1 from public.group_members gm
      where gm.group_id = recurring_expenses_rules.group_id
        and gm.user_id = auth.uid()
        and gm.is_active = true
    )
  );

-- 2. Idempotency ve mükerrer kayıt koruma tablosu
create table if not exists public.recurring_expense_executions (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid not null references public.recurring_expenses_rules(id) on delete cascade,
  execution_date date not null,
  expense_id uuid references public.expenses(id) on delete set null,
  error_message text, -- Hata durumlarında Postgres hata detayını loglamak için
  executed_at timestamptz not null default now(),
  status text not null default 'success' check (status in ('processing', 'success', 'failed')),
  constraint recurring_expense_executions_rule_date_key unique (rule_id, execution_date)
);

-- RLS Aktifleştirme
alter table public.recurring_expense_executions enable row level security;

-- Yazma işlemleri yalnızca dahili motor (execute_due_recurring_expenses) tarafından yapılır.
-- Bu nedenle RLS politikaları olarak sadece okuma (SELECT) yetkisi tanımlanmıştır.
drop policy if exists "Users can view executions of their groups" on public.recurring_expense_executions;
create policy "Users can view executions of their groups"
  on public.recurring_expense_executions
  for select
  to authenticated
  using (
    exists (
      select 1 from public.recurring_expenses_rules r
      join public.group_members gm on gm.group_id = r.group_id
      where r.id = recurring_expense_executions.rule_id
        and gm.user_id = auth.uid()
        and gm.is_active = true
    )
  );

-- 3. update_at tetikleyicisi
create or replace function public.touch_recurring_rule_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_recurring_rule_updated_at on public.recurring_expenses_rules;
create trigger touch_recurring_rule_updated_at
  before update on public.recurring_expenses_rules
  for each row execute function public.touch_recurring_rule_updated_at();

-- Helper validation fonksiyonu (Splits validation için)
create or replace function public.validate_recurring_rule_splits(
  p_group_id uuid,
  p_amount numeric,
  p_split_type text,
  p_splits jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sum numeric(14,2);
  v_invalid_count int;
  v_has_duplicates boolean;
begin
  -- 1. Tutar doğrulaması
  if p_amount <= 0 then
    raise exception 'Harcama tutarı sıfırdan büyük olmalıdır' using errcode = '22003';
  end if;

  -- 2. Bölüşüm tipi doğrulaması
  if p_split_type not in ('equal', 'custom', 'subset') then
    raise exception 'Geçersiz bölüşüm tipi: %', p_split_type using errcode = '22023';
  end if;

  -- 3. Splits JSON array kontrolü
  if p_splits is not null and jsonb_typeof(p_splits) != 'array' then
    raise exception 'Splits geçersiz formatta: Bir JSON array olmalıdır' using errcode = '22023';
  end if;

  -- 4. Boş veri ve tip kontrolleri (subset ve custom için)
  if p_split_type in ('custom', 'subset') then
    if p_splits is null or jsonb_typeof(p_splits) != 'array' or jsonb_array_length(p_splits) = 0 then
      raise exception '% bölüşüm tipinde üye listesi boş olamaz', p_split_type using errcode = '22023';
    end if;
  end if;

  -- 5. Yinelenen üye ID ve grup aktiflik kontrolleri
  if p_splits is not null and jsonb_typeof(p_splits) = 'array' and jsonb_array_length(p_splits) > 0 then
    select count(distinct (val->>'member_id')) != count(*) into v_has_duplicates
    from jsonb_array_elements(p_splits) as val;

    if v_has_duplicates then
      raise exception 'Bölüşüm listesinde aynı üye birden fazla kez bulunamaz' using errcode = '23505';
    end if;

    -- Üyelerin grupta aktif olup olmadığını doğrula
    select count(*) into v_invalid_count
    from jsonb_array_elements(p_splits) as val
    where not exists (
      select 1 from public.group_members gm
      where gm.id = (val->>'member_id')::uuid
        and gm.group_id = p_group_id
        and gm.is_active = true
    );

    if v_invalid_count > 0 then
      raise exception 'Bölüşümdeki üyelerden biri veya birkaçı bu grupta aktif üye değil' using errcode = '42501';
    end if;
  end if;

  -- 6. Custom bölüşümde toplam tutarı doğrula
  if p_split_type = 'custom' then
    -- Negatif/sıfır pay kontrolü
    if exists (
      select 1 from jsonb_array_elements(p_splits) as val
      where (val->>'share_amount')::numeric <= 0
    ) then
      raise exception 'Bölüşüm tutarları sıfırdan büyük olmalıdır' using errcode = '22003';
    end if;

    select sum((val->>'share_amount')::numeric) into v_sum
    from jsonb_array_elements(p_splits) as val;

    if v_sum is null or v_sum != p_amount then
      raise exception 'Özel bölüşüm payları toplamı (%) kural tutarı (%) ile eşleşmiyor', v_sum, p_amount
        using errcode = '22000';
    end if;
  end if;
end;
$$;

-- 4. RPC: Kural Oluşturma
create or replace function public.create_recurring_expense_rule(
  p_group_id uuid,
  p_description text,
  p_note text,
  p_amount numeric,
  p_currency text,
  p_category text,
  p_split_type text,
  p_paid_by uuid,
  p_frequency text,
  p_start_date date,
  p_splits jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rule_id uuid;
  v_created_by_member_id uuid;
  v_clean_desc text;
  v_clean_cat text;
  v_clean_curr text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  -- Girdi normalizasyonu ve doğrulamaları
  v_clean_desc := trim(p_description);
  v_clean_cat := trim(p_category);
  v_clean_curr := upper(trim(p_currency));

  if v_clean_desc is null or v_clean_desc = '' then
    raise exception 'Açıklama boş olamaz' using errcode = '22023';
  end if;

  if v_clean_cat is null or v_clean_cat = '' then
    raise exception 'Kategori boş olamaz' using errcode = '22023';
  end if;

  if v_clean_curr is null or v_clean_curr !~ '^[A-Z]{3}$' then
    raise exception 'Para birimi 3 harfli standart formatta olmalıdır (Örn: TRY)' using errcode = '22023';
  end if;

  -- Geçmişe dönük backfill engellemesi
  if p_start_date < current_date then
    raise exception 'Başlangıç tarihi bugünden eski olamaz' using errcode = '22008';
  end if;

  -- created_by değerini client'tan almak yerine aktif kullanıcının üyelik ID'sinden çözüyoruz
  select gm.id into v_created_by_member_id
  from public.group_members gm
  where gm.group_id = p_group_id
    and gm.user_id = auth.uid()
    and gm.is_active = true;

  if v_created_by_member_id is null then
    raise exception 'Yetkisiz işlem: Kullanıcı bu grubun aktif bir üyesi değil' using errcode = '42501';
  end if;

  -- p_paid_by üyesinin grupta aktif üye olup olmadığını doğrula
  if not exists (
    select 1 from public.group_members gm
    where gm.id = p_paid_by
      and gm.group_id = p_group_id
      and gm.is_active = true
  ) then
    raise exception 'Ödeyen üye bu grupta aktif bir üye değil' using errcode = '42501';
  end if;

  -- Splits validation
  perform public.validate_recurring_rule_splits(p_group_id, p_amount, p_split_type, p_splits);

  insert into public.recurring_expenses_rules (
    group_id, description, note, amount, currency, category, split_type, paid_by, created_by, frequency, start_date, next_execution_date, splits
  ) values (
    p_group_id,
    v_clean_desc,
    p_note,
    p_amount,
    v_clean_curr,
    v_clean_cat,
    p_split_type,
    p_paid_by,
    v_created_by_member_id,
    p_frequency,
    p_start_date,
    p_start_date,
    case when p_split_type = 'equal' then coalesce(p_splits, '[]'::jsonb) else p_splits end
  ) returning id into v_rule_id;

  return v_rule_id;
end;
$$;

-- 5. RPC: Kural Güncelleme
create or replace function public.update_recurring_expense_rule(
  p_rule_id uuid,
  p_description text,
  p_note text,
  p_amount numeric,
  p_currency text,
  p_category text,
  p_split_type text,
  p_paid_by uuid,
  p_actor_member_id uuid,
  p_frequency text,
  p_is_active boolean,
  p_splits jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_clean_desc text;
  v_clean_cat text;
  v_clean_curr text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  -- Girdi normalizasyonu ve doğrulamaları
  v_clean_desc := trim(p_description);
  v_clean_cat := trim(p_category);
  v_clean_curr := upper(trim(p_currency));

  if v_clean_desc is null or v_clean_desc = '' then
    raise exception 'Açıklama boş olamaz' using errcode = '22023';
  end if;

  if v_clean_cat is null or v_clean_cat = '' then
    raise exception 'Kategori boş olamaz' using errcode = '22023';
  end if;

  if v_clean_curr is null or v_clean_curr !~ '^[A-Z]{3}$' then
    raise exception 'Para birimi 3 harfli standart formatta olmalıdır (Örn: TRY)' using errcode = '22023';
  end if;

  select group_id into v_group_id
  from public.recurring_expenses_rules
  where id = p_rule_id;

  if v_group_id is null then
    raise exception 'Tekrarlayan kural bulunamadı' using errcode = 'P0002';
  end if;

  -- İşlem yapan actor_member_id'nin aktif kullanıcıya ait ve grupta aktif üye olduğunu doğrula
  if not exists (
    select 1 from public.group_members gm
    where gm.id = p_actor_member_id
      and gm.group_id = v_group_id
      and gm.user_id = auth.uid()
      and gm.is_active = true
  ) then
    raise exception 'Yetkisiz işlem: Aktör üye bilgisi geçersiz' using errcode = '42501';
  end if;

  -- p_paid_by üyesinin grupta aktif üye olup olmadığını doğrula
  if not exists (
    select 1 from public.group_members gm
    where gm.id = p_paid_by
      and gm.group_id = v_group_id
      and gm.is_active = true
  ) then
    raise exception 'Ödeyen üye bu grupta aktif bir üye değil' using errcode = '42501';
  end if;

  -- NOT: next_execution_date güncellenmesi MVP'de client tarafından doğrudan manipüle edilmez.
  -- İleride eklenirse, geçmiş tarihe çekme abuse kontrolü (start_date kontrolü gibi) burada yapılmalıdır.

  -- Splits validation
  perform public.validate_recurring_rule_splits(v_group_id, p_amount, p_split_type, p_splits);

  update public.recurring_expenses_rules
  set description = v_clean_desc,
      note = p_note,
      amount = p_amount,
      currency = v_clean_curr,
      category = v_clean_cat,
      split_type = p_split_type,
      paid_by = p_paid_by,
      frequency = p_frequency,
      is_active = p_is_active,
      splits = case when p_split_type = 'equal' then coalesce(p_splits, '[]'::jsonb) else p_splits end
  where id = p_rule_id;
end;
$$;

-- 6. RPC: Duraklat / Devam Et
create or replace function public.pause_recurring_expense_rule(
  p_rule_id uuid,
  p_actor_member_id uuid,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.recurring_expenses_rules r
    join public.group_members gm on gm.group_id = r.group_id
    where r.id = p_rule_id
      and gm.id = p_actor_member_id
      and gm.user_id = auth.uid()
      and gm.is_active = true
  ) then
    raise exception 'Unauthorized to modify recurring rule state' using errcode = '42501';
  end if;

  update public.recurring_expenses_rules
  set is_active = p_is_active
  where id = p_rule_id;
end;
$$;

-- 7. RPC: Kural Silme
create or replace function public.delete_recurring_expense_rule(
  p_rule_id uuid,
  p_actor_member_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.recurring_expenses_rules r
    join public.group_members gm on gm.group_id = r.group_id
    where r.id = p_rule_id
      and gm.id = p_actor_member_id
      and gm.user_id = auth.uid()
      and gm.is_active = true
  ) then
    raise exception 'Unauthorized to delete recurring rule' using errcode = '42501';
  end if;

  delete from public.recurring_expenses_rules
  where id = p_rule_id;
end;
$$;

-- 8. RPC: Cron / İşletici Motor (SECURITY DEFINER)
-- Sadece service_role tarafından tetiklenebilir. Authenticated veya public rol yetkisi kapatılmıştır.
-- DROP + CREATE kullanılır (RETURNS TABLE imzası hotfix ile değişebilir).
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
      -- status = 'failed' olan eski başarısız denemeler 'processing' durumuna çekilerek manuel/ad-hoc yeniden tetiklemeye izin verilir.
      -- status = 'success' veya 'processing' olan durumlar çakışma (ON CONFLICT) durumunda güncellenmez ve returning id boş kalır.
      -- NOT: Motor çalışırken next_execution_date otomatik ileri alındığı için başarısız olan periyotlar gelecekteki cron çalıştırmalarında otomatik olarak tekrar denenmez.
      -- Ancak, next_execution_date'in veritabanından manuel olarak geri çekildiği veya aynı periyodun yeniden tetiklendiği durumlarda çakışma (ON CONFLICT) bu retry mekanizmasını korur.
      insert into public.recurring_expense_executions (rule_id, execution_date, status)
      values (v_rule.id, v_next_date, 'processing')
      on conflict on constraint recurring_expense_executions_rule_date_key
      do update
        set status = 'processing',
            error_message = null,
            executed_at = now()
        where public.recurring_expense_executions.status = 'failed'
      returning public.recurring_expense_executions.id into v_execution_id;

      -- Eğer v_execution_id dolu ise bu period ilk kez işleniyor veya retry ediliyordur.
      if v_execution_id is not null then
        begin
          -- 1. Ödeyen üyenin (paid_by) grupta hâlâ aktif olup olmadığını doğrula.
          -- Eğer pasife düştüyse harcama oluşturulmayacak ve hata loglanacaktır.
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
            v_rule.group_id, v_rule.description, v_rule.note, v_rule.amount, v_rule.currency, v_rule.category, v_rule.split_type::split_type, v_rule.paid_by, v_rule.created_by, v_next_date
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
            -- Kural listesindeki üyelerden herhangi biri pasife düştüyse sessizce kaydırma yapmıyoruz, hata fırlatıyoruz.
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
            -- Kural listesindeki özel bölüşüm üyelerinden herhangi biri pasife düştüyse hata fırlatıp işlemi kesiyoruz.
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
          -- Hata oluştuğunda bu dönem için (BEGIN/EXCEPTION bloğu içi) yapılan insert işlemleri (expenses ve splits) 
          -- otomatik olarak geri alınır (rollback). Ancak, dıştaki execution kaydını 'failed' durumuna çekmek ve 
          -- hata mesajını yazmak için yürüttüğümüz update işlemi geçerli kalır.
          update public.recurring_expense_executions
          set status = 'failed',
              error_message = SQLERRM
          where id = v_execution_id;
        end;
      end if;

      -- Hata oluşsa dahi, motorun takılmaması ve kullanıcının hatayı görebilmesi için sonraki tarihe ilerlenir.
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

    -- Bir sonraki çalışma tarihini güncelle
    update public.recurring_expenses_rules
    set next_execution_date = v_next_date
    where id = v_rule.id;

  end loop;
end;
$$;

-- Yetkilendirmeler
revoke all on function public.validate_recurring_rule_splits(uuid, numeric, text, jsonb) from public, authenticated;

revoke all on function public.create_recurring_expense_rule(uuid, text, text, numeric, text, text, text, uuid, text, date, jsonb) from public, authenticated;
grant execute on function public.create_recurring_expense_rule(uuid, text, text, numeric, text, text, text, uuid, text, date, jsonb) to authenticated;

revoke all on function public.update_recurring_expense_rule(uuid, text, text, numeric, text, text, text, uuid, uuid, text, boolean, jsonb) from public, authenticated;
grant execute on function public.update_recurring_expense_rule(uuid, text, text, numeric, text, text, text, uuid, uuid, text, boolean, jsonb) to authenticated;

revoke all on function public.pause_recurring_expense_rule(uuid, uuid, boolean) from public, authenticated;
grant execute on function public.pause_recurring_expense_rule(uuid, uuid, boolean) to authenticated;

revoke all on function public.delete_recurring_expense_rule(uuid, uuid) from public, authenticated;
grant execute on function public.delete_recurring_expense_rule(uuid, uuid) to authenticated;

-- Sadece service_role çağırabilir. Authenticated veya public için execute izni tamamen kaldırılmıştır.
revoke all on function public.execute_due_recurring_expenses() from public, authenticated;
grant execute on function public.execute_due_recurring_expenses() to service_role;
