create extension if not exists pg_net with schema extensions;

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  environment text not null check (environment in ('sandbox', 'production')),
  device_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.push_tokens enable row level security;

drop policy if exists "Users manage their push tokens" on public.push_tokens;
create policy "Users manage their push tokens"
on public.push_tokens
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace function public.touch_push_token_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_push_token_updated_at on public.push_tokens;
create trigger touch_push_token_updated_at
before update on public.push_tokens
for each row execute function public.touch_push_token_updated_at();

create table if not exists public.push_deliveries (
  activity_id uuid not null,
  token_id uuid not null references public.push_tokens(id) on delete cascade,
  delivered_at timestamptz not null default now(),
  primary key (activity_id, token_id)
);

alter table public.push_deliveries enable row level security;

-- SECURITY DEFINER RPC'ler de auth.uid() değerini korur. Bu trigger, mevcut
-- istemcinin yalnızca masraf sahibine izin veren kontrolünü DB seviyesinde uygular.
create or replace function public.enforce_expense_creator_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.id = old.created_by
      and gm.user_id = auth.uid()
      and gm.group_id = old.group_id
      and gm.is_active = true
  ) then
    raise exception 'Only the expense creator can update or delete this expense'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_expense_creator_mutation on public.expenses;
create trigger enforce_expense_creator_mutation
before update of description, note, amount, currency, category, split_type,
  paid_by, expense_date, deleted_at
on public.expenses
for each row execute function public.enforce_expense_creator_mutation();

create or replace function public.enqueue_expense_push()
returns trigger
language plpgsql
security definer
set search_path = public, vault, extensions
as $$
declare
  webhook_secret text;
begin
  if lower(new.action_type) not like '%expense%'
     or (lower(new.action_type) not like '%add%'
         and lower(new.action_type) not like '%insert%') then
    return new;
  end if;

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'push_webhook_secret'
  limit 1;

  if webhook_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := 'https://dtlnujqtwlncwrxunihj.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    ),
    body := jsonb_build_object('activity_id', new.id)
  );
  return new;
end;
$$;

drop trigger if exists enqueue_expense_push on public.activity;
create trigger enqueue_expense_push
after insert on public.activity
for each row execute function public.enqueue_expense_push();

revoke all on public.push_deliveries from anon, authenticated;
grant select, insert, update, delete on public.push_tokens to authenticated;
