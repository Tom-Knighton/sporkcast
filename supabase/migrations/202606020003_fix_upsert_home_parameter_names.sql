drop function if exists "sporkast-mobile".upsert_home(uuid, text);

create or replace function "sporkast-mobile".upsert_home(
  p_home_id uuid,
  p_home_name text
)
returns uuid
language plpgsql
security definer
set search_path = "sporkast-mobile", public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  insert into homes(id, name, created_by)
  values (p_home_id, p_home_name, current_user_id)
  on conflict (id) do update
  set
    name = excluded.name,
    updated_at = now()
  where homes.created_by = current_user_id
     or exists (
       select 1
       from home_members
       where home_members.home_id = homes.id
         and home_members.user_id = current_user_id
         and home_members.role = 'owner'
     );

  if not found then
    raise exception 'Home is not writable by current user';
  end if;

  insert into home_members(home_id, user_id, role)
  values (p_home_id, current_user_id, 'owner')
  on conflict (home_id, user_id) do update
  set role = case
    when home_members.role = 'owner' then home_members.role
    else excluded.role
  end;

  return p_home_id;
end;
$$;

grant execute on function "sporkast-mobile".upsert_home(uuid, text) to authenticated;
notify pgrst, 'reload schema';
