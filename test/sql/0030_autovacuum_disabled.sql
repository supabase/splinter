begin;
  set local search_path = '';

  -- BASELINE: no user tables, expect 0 rows
  select * from lint."0030_autovacuum_disabled";

  savepoint a;

  -- NEGATIVE: autovacuum_enabled=true explicitly set — must not fire
  create table public.active_table (id int);
  alter table public.active_table set (autovacuum_enabled = true);
  select * from lint."0030_autovacuum_disabled";

  rollback to savepoint a;

  savepoint b;

  -- POSITIVE: autovacuum_enabled=false explicitly set — must fire
  create table public.orders (id int);
  alter table public.orders set (autovacuum_enabled = false);
  select name, detail, cache_key from lint."0030_autovacuum_disabled";

  -- RESOLUTION: reset the storage parameter to re-enable autovacuum
  alter table public.orders reset (autovacuum_enabled);
  select * from lint."0030_autovacuum_disabled";

  rollback to savepoint b;

rollback;
