create or replace function "sporkast-mobile".leave_home(
  p_home_id uuid,
  p_disband_if_owner boolean default false
)
returns void
language plpgsql
security definer
set search_path = "sporkast-mobile", public
as $$
declare
  current_user_id uuid := auth.uid();
  current_role text;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select role into current_role
  from home_members
  where home_id = p_home_id
    and user_id = current_user_id;

  if current_role is null then
    return;
  end if;

  if current_role = 'owner' and p_disband_if_owner then
    delete from homes
    where id = p_home_id
      and (
        created_by = current_user_id
        or exists (
          select 1
          from home_members
          where home_members.home_id = p_home_id
            and home_members.user_id = current_user_id
            and home_members.role = 'owner'
        )
      );
    return;
  end if;

  if current_role = 'owner' and exists (
    select 1
    from home_members
    where home_id = p_home_id
      and user_id <> current_user_id
  ) then
    raise exception 'Owner cannot leave a home while other members exist';
  end if;

  delete from home_members
  where home_id = p_home_id
    and user_id = current_user_id;

  delete from homes
  where id = p_home_id
    and not exists (
      select 1
      from home_members
      where home_id = p_home_id
    );
end;
$$;

grant execute on function "sporkast-mobile".leave_home(uuid, boolean) to authenticated;

notify pgrst, 'reload schema';
