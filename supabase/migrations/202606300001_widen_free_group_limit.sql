create or replace function public.create_group_with_limit(
  p_name text,
  p_base_currency text default 'TRY',
  p_display_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_user_pro boolean := false;
  v_created_group_count integer := 0;
  v_group_id uuid;
  v_display_name text;
begin
  if v_user_id is null then
    raise exception 'Oturum bulunamadı.';
  end if;

  select coalesce(user_pro, false)
    into v_user_pro
  from profiles
  where id = v_user_id;

  if not coalesce(v_user_pro, false) then
    select count(*)
      into v_created_group_count
    from groups
    where created_by = v_user_id
      and coalesce(is_demo, false) = false
      and coalesce(archived, false) = false;

    if v_created_group_count >= 10 then
      raise exception 'Ücretsiz plan 10 grup ile sınırlı. Pro ile sınırsız grup oluştur.';
    end if;
  end if;

  v_display_name := nullif(trim(coalesce(p_display_name, '')), '');

  if v_display_name is null then
    select nullif(trim(display_name), '')
      into v_display_name
    from profiles
    where id = v_user_id;
  end if;

  insert into groups (
    name,
    base_currency,
    created_by,
    is_pro,
    is_demo,
    archived,
    avatar_color
  )
  values (
    nullif(trim(p_name), ''),
    upper(coalesce(nullif(trim(p_base_currency), ''), 'TRY')),
    v_user_id,
    false,
    false,
    false,
    '#6366F1'
  )
  returning id into v_group_id;

  insert into group_members (
    group_id,
    user_id,
    display_name,
    role,
    is_active,
    avatar_color
  )
  values (
    v_group_id,
    v_user_id,
    coalesce(v_display_name, 'Ben'),
    'founder',
    true,
    '#6366F1'
  );

  return v_group_id;
end;
$$;

grant execute on function public.create_group_with_limit(text, text, text) to authenticated;
