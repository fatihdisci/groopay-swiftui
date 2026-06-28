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
          if not exists (
            select 1 from public.group_members gm
            where gm.id = v_rule.paid_by
              and gm.group_id = v_rule.group_id
              and gm.is_active = true
          ) then
            raise exception 'Ödeyen üye artık aktif değil' using errcode = '42501';
          end if;
          insert into public.expenses (
            group_id, description, note, amount, currency, category, split_type, paid_by, created_by, expense_date
          ) values (
            v_rule.group_id, v_rule.description, v_rule.note, v_rule.amount, v_rule.currency, v_rule.category, v_rule.split_type::split_type, v_rule.paid_by, v_rule.created_by, v_next_date
          ) returning id into v_expense_id;
          if v_rule.split_type = 'equal' then
            select array_agg(id) into v_active_member_ids
            from public.group_members
            where group_id = v_rule.group_id and is_active = true;
            v_members_count := array_length(v_active_member_ids, 1);
            if v_members_count is null or v_members_count = 0 then
              raise exception 'Aktif üye yok' using errcode = '22023';
            end if;
            v_equal_share := round(v_rule.amount / v_members_count, 2);
            v_remainder := v_rule.amount - (v_equal_share * v_members_count);
            for v_count in 1..v_members_count loop
              v_share := v_equal_share;
              if v_count = 1 then v_share := v_share + v_remainder; end if;
              insert into public.expense_splits (expense_id, member_id, share_amount)
              values (v_expense_id, v_active_member_ids[v_count], v_share);
            end loop;
          elsif v_rule.split_type = 'subset' then
            select count(*) into v_members_count
            from jsonb_to_recordset(v_rule.splits) as s(member_id uuid)
            join public.group_members gm on gm.id = s.member_id
            where gm.group_id = v_rule.group_id and gm.is_active = true;
            if v_members_count != jsonb_array_length(v_rule.splits) then
              raise exception 'Alt küme üyesi artık aktif değil' using errcode = '42501';
            end if;
            select array_agg(gm.id) into v_active_member_ids
            from public.group_members gm
            join jsonb_to_recordset(v_rule.splits) as s(member_id uuid) on s.member_id = gm.id
            where gm.group_id = v_rule.group_id and gm.is_active = true;
            v_members_count := array_length(v_active_member_ids, 1);
            v_equal_share := round(v_rule.amount / v_members_count, 2);
            v_remainder := v_rule.amount - (v_equal_share * v_members_count);
            for v_count in 1..v_members_count loop
              v_share := v_equal_share;
              if v_count = 1 then v_share := v_share + v_remainder; end if;
              insert into public.expense_splits (expense_id, member_id, share_amount)
              values (v_expense_id, v_active_member_ids[v_count], v_share);
            end loop;
          else
            select count(*) into v_members_count
            from jsonb_to_recordset(v_rule.splits) as s(member_id uuid)
            join public.group_members gm on gm.id = s.member_id
            where gm.group_id = v_rule.group_id and gm.is_active = true;
            if v_members_count != jsonb_array_length(v_rule.splits) then
              raise exception 'Custom üye artık aktif değil' using errcode = '42501';
            end if;
            v_total_equal_shares := 0; v_count := 0;
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
              raise exception 'Custom üye yok' using errcode = '22023';
            end if;
            v_remainder := v_rule.amount - v_total_equal_shares;
            if v_remainder != 0 then
              update public.expense_splits set share_amount = share_amount + v_remainder
              where expense_id = v_expense_id
                and member_id = (select member_id from public.expense_splits where expense_id = v_expense_id limit 1);
            end if;
          end if;
          update public.recurring_expense_executions
          set status = 'success', expense_id = v_expense_id
          where id = v_execution_id;
          executed_rule_id := v_rule.id;
          created_expense_id := v_expense_id;
          processed_execution_date := v_next_date;
          return next;
        exception when others then
          update public.recurring_expense_executions
          set status = 'failed', error_message = SQLERRM
          where id = v_execution_id;
        end;
      end if;
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
revoke all on function public.execute_due_recurring_expenses() from public, authenticated;
grant execute on function public.execute_due_recurring_expenses() to service_role;
