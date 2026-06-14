do $$
declare
  table_name text;
  table_names text[] := array[
    'homes',
    'home_members',
    'home_invites',
    'recipes',
    'recipe_images',
    'recipe_ingredient_sections',
    'recipe_ingredients',
    'recipe_step_sections',
    'recipe_steps',
    'recipe_step_timings',
    'recipe_step_temperatures',
    'recipe_step_linked_ingredients',
    'recipe_ratings',
    'recipe_folders',
    'recipe_folder_assignments',
    'recipe_tags',
    'recipe_tag_assignments',
    'mealplan_entries',
    'shopping_lists',
    'shopping_list_items',
    'shopping_list_item_ingredient_links',
    'shopping_list_item_mealplan_links'
  ];
begin
  foreach table_name in array table_names loop
    begin
      execute format('alter publication supabase_realtime add table "sporkast-mobile".%I', table_name);
    exception
      when duplicate_object then null;
    end;
  end loop;
end $$;

alter table "sporkast-mobile".homes replica identity full;
alter table "sporkast-mobile".home_members replica identity full;
alter table "sporkast-mobile".home_invites replica identity full;
alter table "sporkast-mobile".recipes replica identity full;
alter table "sporkast-mobile".recipe_images replica identity full;
alter table "sporkast-mobile".recipe_ingredient_sections replica identity full;
alter table "sporkast-mobile".recipe_ingredients replica identity full;
alter table "sporkast-mobile".recipe_step_sections replica identity full;
alter table "sporkast-mobile".recipe_steps replica identity full;
alter table "sporkast-mobile".recipe_step_timings replica identity full;
alter table "sporkast-mobile".recipe_step_temperatures replica identity full;
alter table "sporkast-mobile".recipe_step_linked_ingredients replica identity full;
alter table "sporkast-mobile".recipe_ratings replica identity full;
alter table "sporkast-mobile".recipe_folders replica identity full;
alter table "sporkast-mobile".recipe_folder_assignments replica identity full;
alter table "sporkast-mobile".recipe_tags replica identity full;
alter table "sporkast-mobile".recipe_tag_assignments replica identity full;
alter table "sporkast-mobile".mealplan_entries replica identity full;
alter table "sporkast-mobile".shopping_lists replica identity full;
alter table "sporkast-mobile".shopping_list_items replica identity full;
alter table "sporkast-mobile".shopping_list_item_ingredient_links replica identity full;
alter table "sporkast-mobile".shopping_list_item_mealplan_links replica identity full;
