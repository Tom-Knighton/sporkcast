create or replace function "sporkast-mobile".delete_recipe_image_storage_object(p_storage_path text)
returns void
language plpgsql
security definer
set search_path = "sporkast-mobile", public, storage
as $$
begin
  if p_storage_path is null or p_storage_path = '' then
    return;
  end if;

  delete from storage.objects
  where bucket_id = 'recipe-images'
    and name = p_storage_path;
end;
$$;

create or replace function "sporkast-mobile".delete_recipe_image_storage_object_on_row_change()
returns trigger
language plpgsql
security definer
set search_path = "sporkast-mobile", public
as $$
begin
  if tg_op = 'DELETE' then
    perform "sporkast-mobile".delete_recipe_image_storage_object(old.storage_path);
    return old;
  end if;

  if tg_op = 'UPDATE' and old.storage_path is distinct from new.storage_path then
    perform "sporkast-mobile".delete_recipe_image_storage_object(old.storage_path);
  end if;

  return new;
end;
$$;

drop trigger if exists recipe_images_delete_storage_object on "sporkast-mobile".recipe_images;
create trigger recipe_images_delete_storage_object
after delete or update of storage_path on "sporkast-mobile".recipe_images
for each row
execute function "sporkast-mobile".delete_recipe_image_storage_object_on_row_change();

create or replace function "sporkast-mobile".delete_soft_deleted_recipe_images()
returns trigger
language plpgsql
security definer
set search_path = "sporkast-mobile", public
as $$
begin
  if old.deleted_at is null and new.deleted_at is not null then
    delete from recipe_images
    where recipe_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists recipes_soft_delete_recipe_images on "sporkast-mobile".recipes;
create trigger recipes_soft_delete_recipe_images
after update of deleted_at on "sporkast-mobile".recipes
for each row
execute function "sporkast-mobile".delete_soft_deleted_recipe_images();

grant execute on function "sporkast-mobile".delete_recipe_image_storage_object(text) to authenticated;
grant execute on function "sporkast-mobile".delete_recipe_image_storage_object_on_row_change() to authenticated;
grant execute on function "sporkast-mobile".delete_soft_deleted_recipe_images() to authenticated;

notify pgrst, 'reload schema';
