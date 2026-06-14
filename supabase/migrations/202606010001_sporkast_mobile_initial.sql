create schema if not exists "sporkast-mobile";

grant usage on schema "sporkast-mobile" to anon, authenticated;

alter role authenticator set pgrst.db_schemas = 'public, graphql_public, sporkast-mobile';
notify pgrst, 'reload config';

create extension if not exists pgcrypto;

create table if not exists "sporkast-mobile".homes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".home_members (
  home_id uuid not null references "sporkast-mobile".homes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  created_at timestamptz not null default now(),
  primary key (home_id, user_id)
);

create table if not exists "sporkast-mobile".home_invites (
  id uuid primary key default gen_random_uuid(),
  home_id uuid not null references "sporkast-mobile".homes(id) on delete cascade,
  token text not null unique default encode(extensions.gen_random_bytes(24), 'hex'),
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  accepted_at timestamptz
);

create table if not exists "sporkast-mobile".recipes (
  id uuid primary key,
  home_id uuid references "sporkast-mobile".homes(id) on delete cascade,
  title text not null,
  description text,
  author text,
  source_url text not null,
  dominant_color_hex text,
  minutes_to_prepare double precision,
  minutes_to_cook double precision,
  total_mins double precision,
  serves text,
  overall_rating double precision,
  total_ratings integer not null default 0,
  summarised_rating text,
  summarised_suggestion text,
  date_added timestamptz not null,
  date_modified timestamptz not null,
  ingredient_scale double precision not null default 1,
  ingredient_unit_system text not null default 'original',
  updated_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists "sporkast-mobile".recipe_images (
  recipe_id uuid primary key references "sporkast-mobile".recipes(id) on delete cascade,
  image_source_url text,
  storage_path text,
  width integer,
  height integer,
  blur_hash text,
  dominant_color_hex text,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_ingredient_sections (
  id uuid primary key,
  recipe_id uuid not null references "sporkast-mobile".recipes(id) on delete cascade,
  sort_index integer not null,
  title text not null default '',
  ingredients jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_step_sections (
  id uuid primary key,
  recipe_id uuid not null references "sporkast-mobile".recipes(id) on delete cascade,
  sort_index integer not null,
  title text not null default '',
  steps jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_ratings (
  id uuid primary key,
  recipe_id uuid not null references "sporkast-mobile".recipes(id) on delete cascade,
  rating integer,
  comment text,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_folders (
  id uuid primary key,
  home_id uuid references "sporkast-mobile".homes(id) on delete cascade,
  name text not null,
  symbol_name text not null default 'folder',
  color_hex text not null default '#F59E0B',
  sort_index integer not null default 0,
  created_at timestamptz not null,
  modified_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_folder_assignments (
  id uuid primary key,
  recipe_id uuid not null references "sporkast-mobile".recipes(id) on delete cascade,
  folder_id uuid not null references "sporkast-mobile".recipe_folders(id) on delete cascade,
  assigned_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_tags (
  id uuid primary key,
  home_id uuid references "sporkast-mobile".homes(id) on delete cascade,
  name text not null,
  color_hex text not null,
  created_at timestamptz not null,
  modified_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_tag_assignments (
  id uuid primary key,
  recipe_id uuid not null references "sporkast-mobile".recipes(id) on delete cascade,
  tag_id uuid not null references "sporkast-mobile".recipe_tags(id) on delete cascade,
  assigned_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".mealplan_entries (
  id uuid primary key,
  home_id uuid references "sporkast-mobile".homes(id) on delete cascade,
  date timestamptz not null,
  sort_index integer not null,
  note_text text,
  recipe_id uuid references "sporkast-mobile".recipes(id) on delete set null,
  updated_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists "sporkast-mobile".shopping_lists (
  id uuid primary key,
  home_id uuid references "sporkast-mobile".homes(id) on delete cascade,
  title text not null,
  created_at timestamptz not null,
  modified_at timestamptz not null,
  is_archived boolean not null default false,
  updated_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists "sporkast-mobile".shopping_list_items (
  id uuid primary key,
  home_id uuid references "sporkast-mobile".homes(id) on delete cascade,
  list_id uuid not null references "sporkast-mobile".shopping_lists(id) on delete cascade,
  title text not null,
  is_complete boolean not null default false,
  modified_at timestamptz not null,
  category_identifier text,
  category_display_name text not null default 'Other',
  category_source text not null default 'manual',
  updated_by uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists "sporkast-mobile".shopping_list_item_ingredient_links (
  id uuid primary key,
  home_id uuid references "sporkast-mobile".homes(id) on delete cascade,
  shopping_list_item_id uuid not null references "sporkast-mobile".shopping_list_items(id) on delete cascade,
  ingredient_id uuid not null,
  source_scale double precision,
  added_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".shopping_list_item_mealplan_links (
  id uuid primary key,
  home_id uuid references "sporkast-mobile".homes(id) on delete cascade,
  shopping_list_item_id uuid not null references "sporkast-mobile".shopping_list_items(id) on delete cascade,
  mealplan_entry_id uuid not null references "sporkast-mobile".mealplan_entries(id) on delete cascade,
  added_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create index if not exists recipes_home_updated_idx on "sporkast-mobile".recipes(home_id, updated_at) where deleted_at is null;
create index if not exists ingredient_sections_recipe_idx on "sporkast-mobile".recipe_ingredient_sections(recipe_id, sort_index);
create index if not exists step_sections_recipe_idx on "sporkast-mobile".recipe_step_sections(recipe_id, sort_index);
create index if not exists mealplan_entries_home_date_idx on "sporkast-mobile".mealplan_entries(home_id, date) where deleted_at is null;
create index if not exists shopping_lists_home_modified_idx on "sporkast-mobile".shopping_lists(home_id, modified_at) where deleted_at is null;
create index if not exists shopping_list_items_home_list_idx on "sporkast-mobile".shopping_list_items(home_id, list_id) where deleted_at is null;
create index if not exists shopping_item_ingredient_links_home_idx on "sporkast-mobile".shopping_list_item_ingredient_links(home_id);
create index if not exists shopping_item_mealplan_links_home_idx on "sporkast-mobile".shopping_list_item_mealplan_links(home_id);

insert into storage.buckets (id, name, public)
values ('recipe-images', 'recipe-images', false)
on conflict (id) do nothing;

create or replace function "sporkast-mobile".is_home_member(target_home_id uuid)
returns boolean
language sql
security definer
set search_path = "sporkast-mobile", public
as $$
  select exists (
    select 1
    from home_members
    where home_id = target_home_id
      and user_id = auth.uid()
  );
$$;

create or replace function "sporkast-mobile".accept_home_invite(invite_token text)
returns uuid
language plpgsql
security definer
set search_path = "sporkast-mobile", public
as $$
declare
  target_home_id uuid;
begin
  select home_id into target_home_id
  from home_invites
  where token = invite_token
    and accepted_at is null
    and (expires_at is null or expires_at > now())
  limit 1;

  if target_home_id is null then
    raise exception 'Invite is invalid or expired';
  end if;

  insert into home_members(home_id, user_id, role)
  values (target_home_id, auth.uid(), 'member')
  on conflict (home_id, user_id) do nothing;

  update home_invites
  set accepted_at = now()
  where token = invite_token;

  return target_home_id;
end;
$$;

alter table "sporkast-mobile".homes enable row level security;
alter table "sporkast-mobile".home_members enable row level security;
alter table "sporkast-mobile".home_invites enable row level security;
alter table "sporkast-mobile".recipes enable row level security;
alter table "sporkast-mobile".recipe_images enable row level security;
alter table "sporkast-mobile".recipe_ingredient_sections enable row level security;
alter table "sporkast-mobile".recipe_step_sections enable row level security;
alter table "sporkast-mobile".recipe_ratings enable row level security;
alter table "sporkast-mobile".recipe_folders enable row level security;
alter table "sporkast-mobile".recipe_folder_assignments enable row level security;
alter table "sporkast-mobile".recipe_tags enable row level security;
alter table "sporkast-mobile".recipe_tag_assignments enable row level security;
alter table "sporkast-mobile".mealplan_entries enable row level security;
alter table "sporkast-mobile".shopping_lists enable row level security;
alter table "sporkast-mobile".shopping_list_items enable row level security;
alter table "sporkast-mobile".shopping_list_item_ingredient_links enable row level security;
alter table "sporkast-mobile".shopping_list_item_mealplan_links enable row level security;

create policy homes_member_access on "sporkast-mobile".homes
for all using ("sporkast-mobile".is_home_member(id))
with check ("sporkast-mobile".is_home_member(id) or created_by = auth.uid());

create policy home_members_self_or_home_access on "sporkast-mobile".home_members
for all using (user_id = auth.uid() or "sporkast-mobile".is_home_member(home_id))
with check (user_id = auth.uid() or "sporkast-mobile".is_home_member(home_id));

create policy home_invites_home_access on "sporkast-mobile".home_invites
for all using ("sporkast-mobile".is_home_member(home_id))
with check ("sporkast-mobile".is_home_member(home_id));

create policy recipes_home_access on "sporkast-mobile".recipes
for all using (home_id is null or "sporkast-mobile".is_home_member(home_id))
with check (home_id is null or "sporkast-mobile".is_home_member(home_id));

create policy recipe_images_home_access on "sporkast-mobile".recipe_images
for all using (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_images.recipe_id
      and (recipes.home_id is null or "sporkast-mobile".is_home_member(recipes.home_id))
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_images.recipe_id
      and (recipes.home_id is null or "sporkast-mobile".is_home_member(recipes.home_id))
  )
);

create policy ingredient_sections_home_access on "sporkast-mobile".recipe_ingredient_sections
for all using (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_ingredient_sections.recipe_id
      and (recipes.home_id is null or "sporkast-mobile".is_home_member(recipes.home_id))
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_ingredient_sections.recipe_id
      and (recipes.home_id is null or "sporkast-mobile".is_home_member(recipes.home_id))
  )
);

create policy step_sections_home_access on "sporkast-mobile".recipe_step_sections
for all using (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_step_sections.recipe_id
      and (recipes.home_id is null or "sporkast-mobile".is_home_member(recipes.home_id))
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_step_sections.recipe_id
      and (recipes.home_id is null or "sporkast-mobile".is_home_member(recipes.home_id))
  )
);

create policy ratings_home_access on "sporkast-mobile".recipe_ratings
for all using (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_ratings.recipe_id
      and (recipes.home_id is null or "sporkast-mobile".is_home_member(recipes.home_id))
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_ratings.recipe_id
      and (recipes.home_id is null or "sporkast-mobile".is_home_member(recipes.home_id))
  )
);

create policy folders_home_access on "sporkast-mobile".recipe_folders
for all using (home_id is null or "sporkast-mobile".is_home_member(home_id))
with check (home_id is null or "sporkast-mobile".is_home_member(home_id));

create policy folder_assignments_home_access on "sporkast-mobile".recipe_folder_assignments
for all using (
  exists (
    select 1
    from "sporkast-mobile".recipe_folders
    where recipe_folders.id = recipe_folder_assignments.folder_id
      and (recipe_folders.home_id is null or "sporkast-mobile".is_home_member(recipe_folders.home_id))
  )
)
with check (
  exists (
    select 1
    from "sporkast-mobile".recipe_folders
    where recipe_folders.id = recipe_folder_assignments.folder_id
      and (recipe_folders.home_id is null or "sporkast-mobile".is_home_member(recipe_folders.home_id))
  )
);

create policy tags_home_access on "sporkast-mobile".recipe_tags
for all using (home_id is null or "sporkast-mobile".is_home_member(home_id))
with check (home_id is null or "sporkast-mobile".is_home_member(home_id));

create policy tag_assignments_home_access on "sporkast-mobile".recipe_tag_assignments
for all using (
  exists (
    select 1
    from "sporkast-mobile".recipe_tags
    where recipe_tags.id = recipe_tag_assignments.tag_id
      and (recipe_tags.home_id is null or "sporkast-mobile".is_home_member(recipe_tags.home_id))
  )
)
with check (
  exists (
    select 1
    from "sporkast-mobile".recipe_tags
    where recipe_tags.id = recipe_tag_assignments.tag_id
      and (recipe_tags.home_id is null or "sporkast-mobile".is_home_member(recipe_tags.home_id))
  )
);

create policy mealplan_entries_home_access on "sporkast-mobile".mealplan_entries
for all using (home_id is null or "sporkast-mobile".is_home_member(home_id))
with check (home_id is null or "sporkast-mobile".is_home_member(home_id));

create policy shopping_lists_home_access on "sporkast-mobile".shopping_lists
for all using (home_id is null or "sporkast-mobile".is_home_member(home_id))
with check (home_id is null or "sporkast-mobile".is_home_member(home_id));

create policy shopping_list_items_home_access on "sporkast-mobile".shopping_list_items
for all using (home_id is null or "sporkast-mobile".is_home_member(home_id))
with check (
  home_id is null
  or "sporkast-mobile".is_home_member(home_id)
  or exists (
    select 1 from "sporkast-mobile".shopping_lists
    where shopping_lists.id = shopping_list_items.list_id
      and (shopping_lists.home_id is null or "sporkast-mobile".is_home_member(shopping_lists.home_id))
  )
);

create policy shopping_item_ingredient_links_home_access on "sporkast-mobile".shopping_list_item_ingredient_links
for all using (home_id is null or "sporkast-mobile".is_home_member(home_id))
with check (home_id is null or "sporkast-mobile".is_home_member(home_id));

create policy shopping_item_mealplan_links_home_access on "sporkast-mobile".shopping_list_item_mealplan_links
for all using (home_id is null or "sporkast-mobile".is_home_member(home_id))
with check (home_id is null or "sporkast-mobile".is_home_member(home_id));

do $$
begin
  alter publication supabase_realtime add table
    "sporkast-mobile".homes,
    "sporkast-mobile".recipes,
    "sporkast-mobile".recipe_ingredient_sections,
    "sporkast-mobile".recipe_step_sections,
    "sporkast-mobile".mealplan_entries,
    "sporkast-mobile".shopping_lists,
    "sporkast-mobile".shopping_list_items,
    "sporkast-mobile".shopping_list_item_ingredient_links,
    "sporkast-mobile".shopping_list_item_mealplan_links;
exception
  when duplicate_object then null;
end $$;

create policy recipe_image_objects_home_select on storage.objects
for select using (
  bucket_id = 'recipe-images'
  and "sporkast-mobile".is_home_member(((storage.foldername(name))[1])::uuid)
);

create policy recipe_image_objects_home_insert on storage.objects
for insert with check (
  bucket_id = 'recipe-images'
  and "sporkast-mobile".is_home_member(((storage.foldername(name))[1])::uuid)
);

create policy recipe_image_objects_home_update on storage.objects
for update using (
  bucket_id = 'recipe-images'
  and "sporkast-mobile".is_home_member(((storage.foldername(name))[1])::uuid)
) with check (
  bucket_id = 'recipe-images'
  and "sporkast-mobile".is_home_member(((storage.foldername(name))[1])::uuid)
);

create policy recipe_image_objects_home_delete on storage.objects
for delete using (
  bucket_id = 'recipe-images'
  and "sporkast-mobile".is_home_member(((storage.foldername(name))[1])::uuid)
);

grant select, insert, update, delete on all tables in schema "sporkast-mobile" to authenticated;
grant execute on function "sporkast-mobile".accept_home_invite(text) to authenticated;
grant execute on function "sporkast-mobile".is_home_member(uuid) to authenticated;
