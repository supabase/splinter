begin;
  set local search_path = '';

  -- BASELINE: pg_graphql not installed, no rows
  select * from lint."0026_pg_graphql_anon_table_exposed";

  savepoint a;

  ----------------------------------------
  -- NEGATIVE EXAMPLE: anon has SELECT on a table but pg_graphql is NOT installed.
  -- Without the extension there is no /graphql/v1 endpoint, so no introspection leak.
  ----------------------------------------
  create table public.products(id int primary key, name text);
  -- Default privileges from fixtures grant SELECT on new public tables to PUBLIC,
  -- so `anon` already has SELECT here. The lint must still report 0 rows.
  select * from lint."0026_pg_graphql_anon_table_exposed";

  rollback to savepoint a;

  ----------------------------------------
  -- POSITIVE EXAMPLE: pg_graphql IS installed and `anon` has SELECT on a public table.
  -- The table's schema (name, columns, relationships) leaks via /graphql/v1 introspection.
  ----------------------------------------
  create extension pg_graphql;
  create table public.internal_api_keys(
    id int primary key,
    service text,
    key_hash text
  );

  select name, detail, cache_key from lint."0026_pg_graphql_anon_table_exposed";

  ----------------------------------------
  -- RESOLUTION: revoke from anon and from public (default privileges granted to public).
  -- After revoking, has_table_privilege('anon', ...) is false and the lint clears.
  ----------------------------------------
  revoke all on public.internal_api_keys from anon, public;
  select * from lint."0026_pg_graphql_anon_table_exposed";

rollback;
