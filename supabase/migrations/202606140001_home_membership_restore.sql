alter table "sporkast-mobile".home_members
add column if not exists restore_token_hash text;

create index if not exists home_members_restore_token_hash_idx
on "sporkast-mobile".home_members(home_id, restore_token_hash)
where restore_token_hash is not null;

create or replace function "sporkast-mobile".home_restore_token_hash(p_restore_token text)
returns text
language sql
security definer
set search_path = "sporkast-mobile", public, extensions
as $$
  select encode(digest(p_restore_token, 'sha256'), 'hex');
$$;

create or replace function "sporkast-mobile".register_home_restore_credential(
  p_home_id uuid,
  p_restore_token text
)
returns void
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

  update home_members
  set restore_token_hash = "sporkast-mobile".home_restore_token_hash(p_restore_token)
  where home_id = p_home_id
    and user_id = current_user_id;

  if not found then
    raise exception 'Current user is not a member of this home';
  end if;
end;
$$;

create or replace function "sporkast-mobile".restore_home_membership(
  p_home_id uuid,
  p_restore_token text
)
returns boolean
language plpgsql
security definer
set search_path = "sporkast-mobile", public
as $$
declare
  current_user_id uuid := auth.uid();
  matched_user_id uuid;
  matched_role text;
  token_hash text := "sporkast-mobile".home_restore_token_hash(p_restore_token);
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select user_id, role
  into matched_user_id, matched_role
  from home_members
  where home_id = p_home_id
    and restore_token_hash = token_hash
  limit 1;

  if matched_user_id is null then
    return false;
  end if;

  insert into home_members(home_id, user_id, role, restore_token_hash)
  values (p_home_id, current_user_id, matched_role, token_hash)
  on conflict (home_id, user_id) do update
  set
    role = case
      when home_members.role = 'owner' then home_members.role
      else excluded.role
    end,
    restore_token_hash = excluded.restore_token_hash;

  delete from home_members
  where home_id = p_home_id
    and user_id <> current_user_id
    and restore_token_hash = token_hash;

  return true;
end;
$$;

grant execute on function "sporkast-mobile".home_restore_token_hash(text) to authenticated;
grant execute on function "sporkast-mobile".register_home_restore_credential(uuid, text) to authenticated;
grant execute on function "sporkast-mobile".restore_home_membership(uuid, text) to authenticated;

notify pgrst, 'reload schema';
