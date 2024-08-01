begin;
    set local search_path = '';

  -- No issues
  select * from lint."0005_unused_index";

  create table public.foo (
    id int primary key,
    foo text unique,
    bar text
  );

  create index some_unused_index on public.foo (bar);

  -- Only the "bar" table is listed
  select * from lint."0005_unused_index";

rollback;
