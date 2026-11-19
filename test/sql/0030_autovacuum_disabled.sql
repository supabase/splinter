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

  savepoint c;

  -- NEGATIVE: autovacuum_enabled=on (another spelling of true) — must not fire
  create table public.active_on (id int) with (autovacuum_enabled = on);
  select * from lint."0030_autovacuum_disabled";

  -- POSITIVE: other spellings of false that Postgres stores verbatim — must fire
  create table public.events (id int) with (autovacuum_enabled = off);
  create table public.logs (id int) with (autovacuum_enabled = 0);
  create table public.metrics (id int) with (autovacuum_enabled = 'no');
  select name, detail, cache_key from lint."0030_autovacuum_disabled";

  rollback to savepoint c;

rollback;
