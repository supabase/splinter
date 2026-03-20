begin;
  set local search_path = '';

  create table public.blog(
    id int primary key
  );

  create index ix_1 on public.blog (id);

  -- 0 issue
  select * from lint."0009_duplicate_index";

  create index ix_2 on public.blog (id);

  -- 1 issue
  select * from lint."0009_duplicate_index";

  create index ix_3 on public.blog (id);

  -- 1 issue
  select * from lint."0009_duplicate_index";

  drop index public.ix_3;
  drop index public.ix_2;
  select * from lint."0009_duplicate_index";


rollback;
