drop trigger if exists recipes_soft_delete_recipe_images on "sporkast-mobile".recipes;
drop trigger if exists recipe_images_delete_storage_object on "sporkast-mobile".recipe_images;

drop function if exists "sporkast-mobile".delete_soft_deleted_recipe_images();
drop function if exists "sporkast-mobile".delete_recipe_image_storage_object_on_row_change();
drop function if exists "sporkast-mobile".delete_recipe_image_storage_object(text);

notify pgrst, 'reload schema';
