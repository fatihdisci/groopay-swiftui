create or replace function public.restore_expense(
  p_expense_id uuid,
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
    select 1
    from public.expenses e
    join public.group_members gm
      on gm.id = p_actor_member_id
     and gm.group_id = e.group_id
    where e.id = p_expense_id
      and e.created_by = p_actor_member_id
      and e.deleted_at is not null
      and gm.user_id = auth.uid()
      and gm.is_active = true
  ) then
    raise exception 'Expense cannot be restored by this member'
      using errcode = '42501';
  end if;

  update public.expenses
  set deleted_at = null,
      updated_at = now()
  where id = p_expense_id
    and deleted_at is not null;

  if not found then
    raise exception 'Expense not found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.restore_expense(uuid, uuid) from public;
grant execute on function public.restore_expense(uuid, uuid) to authenticated;
