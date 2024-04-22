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

  

rollback;
