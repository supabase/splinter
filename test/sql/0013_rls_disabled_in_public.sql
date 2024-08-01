begin;
  set local search_path = '';
  set local pgrst.db_schemas = 'public';

  -- 0 issues
  select * from lint."0013_rls_disabled_in_public";

  create table public.foo( it int primary key );

  -- 1 issue
  select * from lint."0013_rls_disabled_in_public";

  -- Resolve the issue by enabling RLS
  alter table public.foo enable row level security;

  -- 0 issue
  select * from lint."0013_rls_disabled_in_public";

  -- Confirm that the lint only applies to `public` tables
  -- by creating a table in a different schema and confirming
  -- that the lint does not fire
  create schema xyz;
  create table xyz.bar( it int primary key );

  -- 0 issue
  select * from lint."0013_rls_disabled_in_public";

rollback;
