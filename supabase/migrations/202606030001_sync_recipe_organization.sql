alter table "sporkast-mobile".recipe_folders
  add column if not exists updated_by uuid default auth.uid();

alter table "sporkast-mobile".recipe_tags
  add column if not exists updated_by uuid default auth.uid();

create table if not exists "sporkast-mobile".recipe_folder_hierarchy (
  id uuid primary key,
  parent_folder_id uuid not null references "sporkast-mobile".recipe_folders(id) on delete cascade,
  child_folder_id uuid not null references "sporkast-mobile".recipe_folders(id) on delete cascade,
  updated_at timestamptz not null default now()
);

create index if not exists recipe_folder_hierarchy_parent_idx
  on "sporkast-mobile".recipe_folder_hierarchy(parent_folder_id);

create index if not exists recipe_folder_hierarchy_child_idx
  on "sporkast-mobile".recipe_folder_hierarchy(child_folder_id);

alter table "sporkast-mobile".recipe_folder_hierarchy enable row level security;

drop policy if exists folders_home_access on "sporkast-mobile".recipe_folders;
create policy folders_home_access on "sporkast-mobile".recipe_folders
for all using (
  (home_id is null and updated_by = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
)
with check (
  (home_id is null and coalesce(updated_by, auth.uid()) = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
);

drop policy if exists tags_home_access on "sporkast-mobile".recipe_tags;
create policy tags_home_access on "sporkast-mobile".recipe_tags
for all using (
  (home_id is null and updated_by = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
)
with check (
  (home_id is null and coalesce(updated_by, auth.uid()) = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
);

drop policy if exists folder_hierarchy_home_access on "sporkast-mobile".recipe_folder_hierarchy;
create policy folder_hierarchy_home_access on "sporkast-mobile".recipe_folder_hierarchy
for all using (
  exists (
    select 1
    from "sporkast-mobile".recipe_folders
    where recipe_folders.id = recipe_folder_hierarchy.parent_folder_id
      and (
        (recipe_folders.home_id is null and recipe_folders.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipe_folders.home_id)
      )
  )
)
with check (
  exists (
    select 1
    from "sporkast-mobile".recipe_folders
    where recipe_folders.id = recipe_folder_hierarchy.parent_folder_id
      and (
        (recipe_folders.home_id is null and recipe_folders.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipe_folders.home_id)
      )
  )
);

drop policy if exists folder_assignments_home_access on "sporkast-mobile".recipe_folder_assignments;
create policy folder_assignments_home_access on "sporkast-mobile".recipe_folder_assignments
for all using (
  exists (
    select 1
    from "sporkast-mobile".recipe_folders
    where recipe_folders.id = recipe_folder_assignments.folder_id
      and (
        (recipe_folders.home_id is null and recipe_folders.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipe_folders.home_id)
      )
  )
)
with check (
  exists (
    select 1
    from "sporkast-mobile".recipe_folders
    where recipe_folders.id = recipe_folder_assignments.folder_id
      and (
        (recipe_folders.home_id is null and recipe_folders.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipe_folders.home_id)
      )
  )
);

drop policy if exists tag_assignments_home_access on "sporkast-mobile".recipe_tag_assignments;
create policy tag_assignments_home_access on "sporkast-mobile".recipe_tag_assignments
for all using (
  exists (
    select 1
    from "sporkast-mobile".recipe_tags
    where recipe_tags.id = recipe_tag_assignments.tag_id
      and (
        (recipe_tags.home_id is null and recipe_tags.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipe_tags.home_id)
      )
  )
)
with check (
  exists (
    select 1
    from "sporkast-mobile".recipe_tags
    where recipe_tags.id = recipe_tag_assignments.tag_id
      and (
        (recipe_tags.home_id is null and recipe_tags.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipe_tags.home_id)
      )
  )
);

do $$
begin
  begin
    alter publication supabase_realtime add table "sporkast-mobile".recipe_folder_hierarchy;
  exception
    when duplicate_object then null;
  end;
end $$;

alter table "sporkast-mobile".recipe_folder_hierarchy replica identity full;

grant select, insert, update, delete on "sporkast-mobile".recipe_folders to anon, authenticated;
grant select, insert, update, delete on "sporkast-mobile".recipe_folder_hierarchy to anon, authenticated;
grant select, insert, update, delete on "sporkast-mobile".recipe_folder_assignments to anon, authenticated;
grant select, insert, update, delete on "sporkast-mobile".recipe_tags to anon, authenticated;
grant select, insert, update, delete on "sporkast-mobile".recipe_tag_assignments to anon, authenticated;
