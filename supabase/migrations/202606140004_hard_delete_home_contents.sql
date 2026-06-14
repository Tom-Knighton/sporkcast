create or replace function "sporkast-mobile".delete_home_contents()
returns trigger
language plpgsql
security definer
set search_path = "sporkast-mobile", public
as $$
begin
  delete from shopping_lists
  where home_id = old.id;

  delete from shopping_list_items
  where home_id = old.id;

  delete from shopping_list_item_ingredient_links
  where home_id = old.id;

  delete from shopping_list_item_mealplan_links
  where home_id = old.id;

  delete from mealplan_entries
  where home_id = old.id;

  delete from recipes
  where home_id = old.id;

  delete from recipe_folders
  where home_id = old.id;

  delete from recipe_tags
  where home_id = old.id;

  delete from home_invites
  where home_id = old.id;

  delete from home_members
  where home_id = old.id;

  return old;
end;
$$;

drop trigger if exists homes_delete_contents on "sporkast-mobile".homes;
create trigger homes_delete_contents
before delete on "sporkast-mobile".homes
for each row
execute function "sporkast-mobile".delete_home_contents();

grant execute on function "sporkast-mobile".delete_home_contents() to authenticated;

notify pgrst, 'reload schema';
