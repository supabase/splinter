begin;
  set local search_path = '';
  set local pgrst.db_schemas = 'public';

  -- test/fixtures.sql mirrors the pre-October-30 platform default
  -- (select on new tables in public to PUBLIC), which other lints'
  -- tests rely on. Start this file from the post-change state.
  alter default privileges in schema public revoke select on tables from public;

  -- BASELINE: no default privileges for the API roles, no rows
  select * from lint."0034_default_privileges_expose_new_tables";

  savepoint a;

  ----------------------------------------
  -- NEGATIVE EXAMPLE: default privileges for service_role only. The
  -- service key already bypasses RLS and never reaches the browser,
  -- so this does not expose new tables to the public API.
  ----------------------------------------
  create role service_role;
  alter default privileges for role postgres in schema public
    grant select, insert, update, delete on tables to service_role;
  select * from lint."0034_default_privileges_expose_new_tables";

  rollback to savepoint a;

  savepoint b;

  ----------------------------------------
  -- NEGATIVE EXAMPLE: default privileges to anon, but in a schema that
  -- is not exposed through the Data API (not in pgrst.db_schemas).
  ----------------------------------------
  create schema private_stuff;
  alter default privileges for role postgres in schema private_stuff
    grant select on tables to anon;
  select * from lint."0034_default_privileges_expose_new_tables";

  rollback to savepoint b;

  savepoint c;

  ----------------------------------------
  -- NEGATIVE EXAMPLE: default privileges on sequences and functions are
  -- out of scope; this lint is about tables appearing in the API.
  ----------------------------------------
  alter default privileges for role postgres in schema public
    grant usage, select on sequences to anon;
  select * from lint."0034_default_privileges_expose_new_tables";

  rollback to savepoint c;

  savepoint case_lazy_fix;

  ----------------------------------------
  -- POSITIVE: the "lazy fix" for the first 42501 after October 30,
  -- 2026. Every table postgres creates in public from now on is
  -- readable and writable by anon and authenticated on creation.
  ----------------------------------------
  alter default privileges for role postgres in schema public
    grant select, insert, update, delete on tables to anon, authenticated;

  select
    name,
    detail,
    metadata->>'owner' as owner,
    metadata->>'schema' as schema,
    cache_key
  from lint."0034_default_privileges_expose_new_tables";

  ----------------------------------------
  -- RESOLUTION: revoke the default privileges. New tables need an
  -- explicit grant again and the lint clears.
  ----------------------------------------
  alter default privileges for role postgres in schema public
    revoke all on tables from anon, authenticated;
  select * from lint."0034_default_privileges_expose_new_tables";

  rollback to savepoint case_lazy_fix;

  savepoint case_global_public;

  ----------------------------------------
  -- POSITIVE: a default without IN SCHEMA applies to every schema,
  -- including the exposed ones. Granting to PUBLIC covers anon and
  -- authenticated too.
  ----------------------------------------
  alter default privileges for role postgres
    grant select on tables to public;

  select
    name,
    detail,
    metadata->>'schema' as schema,
    cache_key
  from lint."0034_default_privileges_expose_new_tables";

  alter default privileges for role postgres
    revoke select on tables from public;
  select * from lint."0034_default_privileges_expose_new_tables";

  rollback to savepoint case_global_public;

rollback;
