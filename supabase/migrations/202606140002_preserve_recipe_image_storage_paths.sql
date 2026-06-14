update "sporkast-mobile".recipe_images
set
  storage_path = 'recipes/' || recipe_id::text || '/cover.jpg',
  updated_at = now()
where storage_path is null;

notify pgrst, 'reload schema';
