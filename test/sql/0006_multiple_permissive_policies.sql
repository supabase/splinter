begin;
    set local search_path = '';

  -- No issues
  select * from lint."0006_multiple_permissive_policies";

  create table public.blog(
    id int primary key
  );

  alter table public.blog enable row level security;

  create policy select_own_posts on public.blog
  for select
  using (true);

  create policy all_own_posts on public.blog
  for all
  using (true);

  select * from lint."0006_multiple_permissive_policies";

  -- Now we drop the permissive policies and make sure that the same
  -- policies marked as "restrictive" to not flag
  drop policy select_own_posts on public.blog;
  drop policy all_own_posts on public.blog;

  create policy select_own_posts on public.blog
  as restrictive
  for select
  using (true);

  create policy all_own_posts on public.blog
  as restrictive
  for all
  using (true);

  -- No issues, the policies are restrictive, which is fine
  select * from lint."0006_multiple_permissive_policies";
  savepoint a;

  -- Confirm that storage.objects will be scanned (#35)
  create schema storage;
  create table storage.objects(
    id int primary key,
    bucket_id text
  );

  alter table storage.objects enable row level security;

  create policy avatars_read on storage.objects
  for select
  to authenticated
  using (bucket_id = 'avatars');

  create policy documents_read on storage.objects
  for select
  to authenticated
  using (bucket_id = 'documents');

  -- 1 entry for storage.objects, authenticated, SELECT
  select * from lint."0006_multiple_permissive_policies";

  rollback to savepoint a;

  -- auth remains excluded: users do not author policies there
  create table auth.sessions(
    id int primary key
  );

  alter table auth.sessions enable row level security;

  create policy sessions_read_1 on auth.sessions
  for select
  to authenticated
  using (true);

  create policy sessions_read_2 on auth.sessions
  for select
  to authenticated
  using (true);

  -- No issues
  select * from lint."0006_multiple_permissive_policies";

rollback;
