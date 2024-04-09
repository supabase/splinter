begin;

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

  drop index ix_3;
  drop index ix_2;
  select * from lint."0009_duplicate_index";


rollback;
