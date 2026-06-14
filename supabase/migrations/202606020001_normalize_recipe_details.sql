create table if not exists "sporkast-mobile".recipe_ingredients (
  id uuid primary key,
  ingredient_group_id uuid not null references "sporkast-mobile".recipe_ingredient_sections(id) on delete cascade,
  sort_index integer not null,
  raw_ingredient text not null,
  quantity double precision,
  quantity_text text,
  unit text,
  unit_text text,
  ingredient text,
  extra text,
  emoji_descriptor text,
  owned boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_steps (
  id uuid primary key,
  group_id uuid not null references "sporkast-mobile".recipe_step_sections(id) on delete cascade,
  sort_index integer not null,
  instruction text not null,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_step_timings (
  id uuid primary key,
  recipe_step_id uuid not null references "sporkast-mobile".recipe_steps(id) on delete cascade,
  time_in_seconds double precision not null,
  time_text text not null,
  time_unit_text text not null,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_step_temperatures (
  id uuid primary key,
  recipe_step_id uuid not null references "sporkast-mobile".recipe_steps(id) on delete cascade,
  temperature double precision not null,
  temperature_text text not null,
  temperature_unit_text text not null,
  updated_at timestamptz not null default now()
);

create table if not exists "sporkast-mobile".recipe_step_linked_ingredients (
  id uuid primary key,
  recipe_step_id uuid not null references "sporkast-mobile".recipe_steps(id) on delete cascade,
  ingredient_id uuid not null references "sporkast-mobile".recipe_ingredients(id) on delete cascade,
  sort_index integer not null,
  updated_at timestamptz not null default now()
);

alter table "sporkast-mobile".recipe_ingredient_sections drop column if exists ingredients;
alter table "sporkast-mobile".recipe_step_sections drop column if exists steps;

create index if not exists recipe_ingredients_group_idx on "sporkast-mobile".recipe_ingredients(ingredient_group_id, sort_index);
create index if not exists recipe_steps_group_idx on "sporkast-mobile".recipe_steps(group_id, sort_index);
create index if not exists recipe_step_timings_step_idx on "sporkast-mobile".recipe_step_timings(recipe_step_id);
create index if not exists recipe_step_temperatures_step_idx on "sporkast-mobile".recipe_step_temperatures(recipe_step_id);
create index if not exists recipe_step_linked_ingredients_step_idx on "sporkast-mobile".recipe_step_linked_ingredients(recipe_step_id, sort_index);

alter table "sporkast-mobile".recipe_ingredients enable row level security;
alter table "sporkast-mobile".recipe_steps enable row level security;
alter table "sporkast-mobile".recipe_step_timings enable row level security;
alter table "sporkast-mobile".recipe_step_temperatures enable row level security;
alter table "sporkast-mobile".recipe_step_linked_ingredients enable row level security;

alter table "sporkast-mobile".recipe_ingredient_sections replica identity full;
alter table "sporkast-mobile".recipe_ingredients replica identity full;
alter table "sporkast-mobile".recipe_step_sections replica identity full;
alter table "sporkast-mobile".recipe_steps replica identity full;
alter table "sporkast-mobile".recipe_step_timings replica identity full;
alter table "sporkast-mobile".recipe_step_temperatures replica identity full;
alter table "sporkast-mobile".recipe_step_linked_ingredients replica identity full;

drop policy if exists recipe_ingredients_home_access on "sporkast-mobile".recipe_ingredients;
create policy recipe_ingredients_home_access on "sporkast-mobile".recipe_ingredients
for all using (
  exists (
    select 1 from "sporkast-mobile".recipe_ingredient_sections
    join "sporkast-mobile".recipes on recipes.id = recipe_ingredient_sections.recipe_id
    where recipe_ingredient_sections.id = recipe_ingredients.ingredient_group_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipe_ingredient_sections
    join "sporkast-mobile".recipes on recipes.id = recipe_ingredient_sections.recipe_id
    where recipe_ingredient_sections.id = recipe_ingredients.ingredient_group_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
);

drop policy if exists recipe_steps_home_access on "sporkast-mobile".recipe_steps;
create policy recipe_steps_home_access on "sporkast-mobile".recipe_steps
for all using (
  exists (
    select 1 from "sporkast-mobile".recipe_step_sections
    join "sporkast-mobile".recipes on recipes.id = recipe_step_sections.recipe_id
    where recipe_step_sections.id = recipe_steps.group_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipe_step_sections
    join "sporkast-mobile".recipes on recipes.id = recipe_step_sections.recipe_id
    where recipe_step_sections.id = recipe_steps.group_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
);

drop policy if exists recipe_step_timings_home_access on "sporkast-mobile".recipe_step_timings;
create policy recipe_step_timings_home_access on "sporkast-mobile".recipe_step_timings
for all using (
  exists (
    select 1 from "sporkast-mobile".recipe_steps
    join "sporkast-mobile".recipe_step_sections on recipe_step_sections.id = recipe_steps.group_id
    join "sporkast-mobile".recipes on recipes.id = recipe_step_sections.recipe_id
    where recipe_steps.id = recipe_step_timings.recipe_step_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipe_steps
    join "sporkast-mobile".recipe_step_sections on recipe_step_sections.id = recipe_steps.group_id
    join "sporkast-mobile".recipes on recipes.id = recipe_step_sections.recipe_id
    where recipe_steps.id = recipe_step_timings.recipe_step_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
);

drop policy if exists recipe_step_temperatures_home_access on "sporkast-mobile".recipe_step_temperatures;
create policy recipe_step_temperatures_home_access on "sporkast-mobile".recipe_step_temperatures
for all using (
  exists (
    select 1 from "sporkast-mobile".recipe_steps
    join "sporkast-mobile".recipe_step_sections on recipe_step_sections.id = recipe_steps.group_id
    join "sporkast-mobile".recipes on recipes.id = recipe_step_sections.recipe_id
    where recipe_steps.id = recipe_step_temperatures.recipe_step_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipe_steps
    join "sporkast-mobile".recipe_step_sections on recipe_step_sections.id = recipe_steps.group_id
    join "sporkast-mobile".recipes on recipes.id = recipe_step_sections.recipe_id
    where recipe_steps.id = recipe_step_temperatures.recipe_step_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
);

drop policy if exists recipe_step_linked_ingredients_home_access on "sporkast-mobile".recipe_step_linked_ingredients;
create policy recipe_step_linked_ingredients_home_access on "sporkast-mobile".recipe_step_linked_ingredients
for all using (
  exists (
    select 1 from "sporkast-mobile".recipe_steps
    join "sporkast-mobile".recipe_step_sections on recipe_step_sections.id = recipe_steps.group_id
    join "sporkast-mobile".recipes on recipes.id = recipe_step_sections.recipe_id
    where recipe_steps.id = recipe_step_linked_ingredients.recipe_step_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipe_steps
    join "sporkast-mobile".recipe_step_sections on recipe_step_sections.id = recipe_steps.group_id
    join "sporkast-mobile".recipes on recipes.id = recipe_step_sections.recipe_id
    where recipe_steps.id = recipe_step_linked_ingredients.recipe_step_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
);

grant select, insert, update, delete on
  "sporkast-mobile".recipe_ingredients,
  "sporkast-mobile".recipe_steps,
  "sporkast-mobile".recipe_step_timings,
  "sporkast-mobile".recipe_step_temperatures,
  "sporkast-mobile".recipe_step_linked_ingredients
to authenticated;

do $$
begin
  alter publication supabase_realtime add table
    "sporkast-mobile".recipe_ingredients,
    "sporkast-mobile".recipe_steps,
    "sporkast-mobile".recipe_step_timings,
    "sporkast-mobile".recipe_step_temperatures,
    "sporkast-mobile".recipe_step_linked_ingredients;
exception
  when duplicate_object then null;
end $$;
