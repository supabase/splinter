begin;
  set local search_path = '';

  create table public.blog(
    id int primary key
  );

  create policy select_own_posts on public.blog
  for select
  using (true);

  create policy all_own_posts on public.blog
  for all
  using (true);

  -- 1 issue
  select * from lint."0007_policy_exists_rls_disabled";

  -- resolve the issue
  alter table public.blog enable row level security;

  -- 0 issue
  select * from lint."0007_policy_exists_rls_disabled";

rollback;
