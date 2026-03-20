begin;
  set local search_path = '';

  create table public.blog(
    id int primary key
  );

  alter table public.blog enable row level security;

  -- 1 issue
  select * from lint."0008_rls_enabled_no_policy";

  -- resolve the issue
  create policy none_shall_pass on public.blog
  for select
  using (false);

  -- 0 issue
  select * from lint."0008_rls_enabled_no_policy";

rollback;
