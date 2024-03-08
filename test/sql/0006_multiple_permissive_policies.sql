begin;

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

rollback;
