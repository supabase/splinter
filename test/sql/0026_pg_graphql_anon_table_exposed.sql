begin;
  set local search_path = '';

  -- BASELINE: pg_graphql not installed, no rows
  select * from lint."0026_pg_graphql_anon_table_exposed";

  savepoint a;

  ----------------------------------------
  -- NEGATIVE EXAMPLE: anon has SELECT on a table but pg_graphql is NOT installed.
  -- Without the extension there is no /graphql/v1 endpoint, so introspection is not active.
  ----------------------------------------
  create table public.products(id int primary key, name text);
  -- Default privileges from fixtures grant SELECT on new public tables to PUBLIC,
  -- so `anon` already has SELECT here. The lint must still report 0 rows.
  select * from lint."0026_pg_graphql_anon_table_exposed";

  rollback to savepoint a;

  ----------------------------------------
  -- POSITIVE EXAMPLE: pg_graphql IS installed and `anon` has SELECT on a table AND a view.
  -- Both objects are visible via /graphql/v1 introspection.
  ----------------------------------------
  create extension pg_graphql;

  create table public.internal_api_keys(
    id int primary key,
    service text,
    key_hash text
  );

  create view public.api_key_summary as
    select id, service from public.internal_api_keys;

  -- Both the table and the view should appear, ordered by object name.
  select
    name,
    metadata->>'type' as object_type,
    cache_key
  from lint."0026_pg_graphql_anon_table_exposed";

  ----------------------------------------
  -- RESOLUTION: revoke from anon and from public on both objects.
  -- After revoking, has_table_privilege('anon', ...) is false and the lint clears.
  ----------------------------------------
  revoke all on public.internal_api_keys from anon, public;
  revoke all on public.api_key_summary from anon, public;
  select * from lint."0026_pg_graphql_anon_table_exposed";

rollback;
