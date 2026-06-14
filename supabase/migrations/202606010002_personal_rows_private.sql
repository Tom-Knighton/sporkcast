drop policy if exists recipes_home_access on "sporkast-mobile".recipes;
create policy recipes_home_access on "sporkast-mobile".recipes
for all using (
  (home_id is null and updated_by = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
)
with check (
  (home_id is null and coalesce(updated_by, auth.uid()) = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
);

drop policy if exists recipe_images_home_access on "sporkast-mobile".recipe_images;
create policy recipe_images_home_access on "sporkast-mobile".recipe_images
for all using (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_images.recipe_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_images.recipe_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
);

drop policy if exists ingredient_sections_home_access on "sporkast-mobile".recipe_ingredient_sections;
create policy ingredient_sections_home_access on "sporkast-mobile".recipe_ingredient_sections
for all using (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_ingredient_sections.recipe_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_ingredient_sections.recipe_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
);

drop policy if exists step_sections_home_access on "sporkast-mobile".recipe_step_sections;
create policy step_sections_home_access on "sporkast-mobile".recipe_step_sections
for all using (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_step_sections.recipe_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_step_sections.recipe_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
);

drop policy if exists ratings_home_access on "sporkast-mobile".recipe_ratings;
create policy ratings_home_access on "sporkast-mobile".recipe_ratings
for all using (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_ratings.recipe_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
)
with check (
  exists (
    select 1 from "sporkast-mobile".recipes
    where recipes.id = recipe_ratings.recipe_id
      and (
        (recipes.home_id is null and recipes.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(recipes.home_id)
      )
  )
);

drop policy if exists mealplan_entries_home_access on "sporkast-mobile".mealplan_entries;
create policy mealplan_entries_home_access on "sporkast-mobile".mealplan_entries
for all using (
  (home_id is null and updated_by = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
)
with check (
  (home_id is null and coalesce(updated_by, auth.uid()) = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
);

drop policy if exists shopping_lists_home_access on "sporkast-mobile".shopping_lists;
create policy shopping_lists_home_access on "sporkast-mobile".shopping_lists
for all using (
  (home_id is null and updated_by = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
)
with check (
  (home_id is null and coalesce(updated_by, auth.uid()) = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
);

drop policy if exists shopping_list_items_home_access on "sporkast-mobile".shopping_list_items;
create policy shopping_list_items_home_access on "sporkast-mobile".shopping_list_items
for all using (
  (home_id is null and updated_by = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
  or exists (
    select 1 from "sporkast-mobile".shopping_lists
    where shopping_lists.id = shopping_list_items.list_id
      and (
        (shopping_lists.home_id is null and shopping_lists.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(shopping_lists.home_id)
      )
  )
)
with check (
  (home_id is null and coalesce(updated_by, auth.uid()) = auth.uid())
  or "sporkast-mobile".is_home_member(home_id)
  or exists (
    select 1 from "sporkast-mobile".shopping_lists
    where shopping_lists.id = shopping_list_items.list_id
      and (
        (shopping_lists.home_id is null and shopping_lists.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(shopping_lists.home_id)
      )
  )
);

drop policy if exists shopping_item_ingredient_links_home_access on "sporkast-mobile".shopping_list_item_ingredient_links;
create policy shopping_item_ingredient_links_home_access on "sporkast-mobile".shopping_list_item_ingredient_links
for all using (
  "sporkast-mobile".is_home_member(home_id)
  or exists (
    select 1 from "sporkast-mobile".shopping_list_items
    where shopping_list_items.id = shopping_list_item_ingredient_links.shopping_list_item_id
      and (
        (shopping_list_items.home_id is null and shopping_list_items.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(shopping_list_items.home_id)
      )
  )
)
with check (
  "sporkast-mobile".is_home_member(home_id)
  or exists (
    select 1 from "sporkast-mobile".shopping_list_items
    where shopping_list_items.id = shopping_list_item_ingredient_links.shopping_list_item_id
      and (
        (shopping_list_items.home_id is null and shopping_list_items.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(shopping_list_items.home_id)
      )
  )
);

drop policy if exists shopping_item_mealplan_links_home_access on "sporkast-mobile".shopping_list_item_mealplan_links;
create policy shopping_item_mealplan_links_home_access on "sporkast-mobile".shopping_list_item_mealplan_links
for all using (
  "sporkast-mobile".is_home_member(home_id)
  or exists (
    select 1 from "sporkast-mobile".shopping_list_items
    where shopping_list_items.id = shopping_list_item_mealplan_links.shopping_list_item_id
      and (
        (shopping_list_items.home_id is null and shopping_list_items.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(shopping_list_items.home_id)
      )
  )
)
with check (
  "sporkast-mobile".is_home_member(home_id)
  or exists (
    select 1 from "sporkast-mobile".shopping_list_items
    where shopping_list_items.id = shopping_list_item_mealplan_links.shopping_list_item_id
      and (
        (shopping_list_items.home_id is null and shopping_list_items.updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(shopping_list_items.home_id)
      )
  )
);
