create or replace function "sporkast-mobile".can_access_recipe(target_recipe_id uuid)
returns boolean
language sql
security definer
set search_path = "sporkast-mobile", public
as $$
  select exists (
    select 1
    from recipes
    where id = target_recipe_id
      and (
        (home_id is null and updated_by = auth.uid())
        or "sporkast-mobile".is_home_member(home_id)
      )
  );
$$;

create or replace function "sporkast-mobile".can_access_recipe_image_object(object_name text)
returns boolean
language plpgsql
security definer
set search_path = "sporkast-mobile", public
as $$
declare
  path_parts text[];
  target_recipe_id uuid;
begin
  path_parts := storage.foldername(object_name);

  if array_length(path_parts, 1) < 2 or path_parts[1] <> 'recipes' then
    return false;
  end if;

  begin
    target_recipe_id := path_parts[2]::uuid;
  exception
    when invalid_text_representation then
      return false;
  end;

  return "sporkast-mobile".can_access_recipe(target_recipe_id);
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'sporkast-mobile'
      and table_name = 'recipes'
      and column_name = 'image_url'
  ) then
    execute '
      insert into "sporkast-mobile".recipe_images (recipe_id, image_source_url)
      select id, image_url
      from "sporkast-mobile".recipes
      where image_url is not null and image_url <> ''''
      on conflict (recipe_id) do update
      set image_source_url = coalesce("sporkast-mobile".recipe_images.image_source_url, excluded.image_source_url),
          updated_at = now()
    ';

    execute 'alter table "sporkast-mobile".recipes drop column image_url';
  end if;
end $$;

alter table "sporkast-mobile".recipe_images
  drop column if exists dominant_color_hex;

drop policy if exists recipe_images_home_access on "sporkast-mobile".recipe_images;
create policy recipe_images_recipe_access on "sporkast-mobile".recipe_images
for all using ("sporkast-mobile".can_access_recipe(recipe_id))
with check ("sporkast-mobile".can_access_recipe(recipe_id));

drop policy if exists recipe_image_objects_home_select on storage.objects;
drop policy if exists recipe_image_objects_home_insert on storage.objects;
drop policy if exists recipe_image_objects_home_update on storage.objects;
drop policy if exists recipe_image_objects_home_delete on storage.objects;
drop policy if exists recipe_image_objects_recipe_select on storage.objects;
drop policy if exists recipe_image_objects_recipe_insert on storage.objects;
drop policy if exists recipe_image_objects_recipe_update on storage.objects;
drop policy if exists recipe_image_objects_recipe_delete on storage.objects;

create policy recipe_image_objects_recipe_select on storage.objects
for select using (
  bucket_id = 'recipe-images'
  and "sporkast-mobile".can_access_recipe_image_object(name)
);

create policy recipe_image_objects_recipe_insert on storage.objects
for insert with check (
  bucket_id = 'recipe-images'
  and "sporkast-mobile".can_access_recipe_image_object(name)
);

create policy recipe_image_objects_recipe_update on storage.objects
for update using (
  bucket_id = 'recipe-images'
  and "sporkast-mobile".can_access_recipe_image_object(name)
) with check (
  bucket_id = 'recipe-images'
  and "sporkast-mobile".can_access_recipe_image_object(name)
);

create policy recipe_image_objects_recipe_delete on storage.objects
for delete using (
  bucket_id = 'recipe-images'
  and "sporkast-mobile".can_access_recipe_image_object(name)
);

grant execute on function "sporkast-mobile".can_access_recipe(uuid) to authenticated;
grant execute on function "sporkast-mobile".can_access_recipe_image_object(text) to authenticated;
grant select, insert, update, delete on "sporkast-mobile".recipe_images to authenticated;
