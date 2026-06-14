do $$
declare
  policy_name text;
begin
  for policy_name in
    select policyname
    from pg_policies
    where schemaname = 'sporkast-mobile'
      and tablename = 'home_invites'
  loop
    execute format(
      'drop policy if exists %I on "sporkast-mobile".home_invites',
      policy_name
    );
  end loop;
end;
$$;

create policy home_invites_home_access on "sporkast-mobile".home_invites
for all
using ("sporkast-mobile".is_home_member(home_id))
with check ("sporkast-mobile".is_home_member(home_id));

notify pgrst, 'reload schema';
