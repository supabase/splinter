begin;
  set local search_path = '';

  -- BASELINE: pg_graphql not installed, no rows
  select * from lint."0027_pg_graphql_authenticated_table_exposed";

  savepoint a;

  ----------------------------------------
  -- NEGATIVE EXAMPLE: authenticated has SELECT on a table but
  -- pg_graphql is NOT installed. Without the extension there is no
  -- /graphql/v1 endpoint, so the lint must not fire.
  ----------------------------------------
  create table public.products(id int primary key, name text);
  -- Default privileges from fixtures grant SELECT on new public tables to PUBLIC,
  -- so `authenticated` already has SELECT here. The lint must still report 0 rows.
  select * from lint."0027_pg_graphql_authenticated_table_exposed";

  rollback to savepoint a;

  -- All positive cases below require pg_graphql to be installed.
  create extension pg_graphql;

  savepoint case_table_view_matview;

  ----------------------------------------
  -- POSITIVE: `authenticated` has SELECT (via the fixture's PUBLIC
  -- default grant) on a table, a view, and a materialized view. All
  -- three relkinds covered by the lint should appear, ordered by
  -- object name.
  ----------------------------------------
  create table public.internal_api_keys(
    id int primary key,
    service text,
    key_hash text
  );

  create view public.api_key_summary as
    select id, service from public.internal_api_keys;

  create materialized view public.api_key_archive as
    select id, service from public.internal_api_keys;

  select
    name,
    metadata->>'type' as object_type,
    cache_key
  from lint."0027_pg_graphql_authenticated_table_exposed";

  ----------------------------------------
  -- RESOLUTION: revoke from authenticated (and PUBLIC, which
  -- authenticated rides on by default). After revoking,
  -- has_table_privilege('authenticated', ...) is false and the lint
  -- clears.
  ----------------------------------------
  revoke all on public.internal_api_keys from authenticated, public;
  revoke all on public.api_key_summary   from authenticated, public;
  revoke all on public.api_key_archive   from authenticated, public;
  select * from lint."0027_pg_graphql_authenticated_table_exposed";

  rollback to savepoint case_table_view_matview;

  savepoint case_foreign;

  ----------------------------------------
  -- POSITIVE (foreign table): pg_graphql exposes relkind='f' relations,
  -- so the lint must too. The fixture's default grant to PUBLIC also
  -- applies to foreign tables.
  ----------------------------------------
  create extension postgres_fdw schema extensions;
  create server fdw_test foreign data wrapper postgres_fdw
    options (host 'localhost', dbname 'postgres');
  create foreign table public.foreign_secrets(
    id int,
    secret text
  ) server fdw_test;

  select
    name,
    metadata->>'type' as object_type,
    cache_key
  from lint."0027_pg_graphql_authenticated_table_exposed";

  rollback to savepoint case_foreign;

  savepoint case_partitioned;

  ----------------------------------------
  -- MIXED: a partitioned table root (relkind='p') and a leaf partition
  -- (relkind='r'). pg_graphql exposes only the leaves, so only the leaf
  -- should appear; the root must NOT fire under the new filter.
  ----------------------------------------
  create table public.parted(id int, region text) partition by list(region);
  create table public.parted_us partition of public.parted for values in ('us');

  select
    name,
    metadata->>'type' as object_type,
    cache_key
  from lint."0027_pg_graphql_authenticated_table_exposed";

  rollback to savepoint case_partitioned;

  savepoint case_authenticated_revoked;

  ----------------------------------------
  -- NEGATIVE: pg_graphql installed and `anon` has SELECT, but
  -- `authenticated` does NOT. Lint 0027 must not fire — this is the
  -- mirror image of 0026's "revoke from anon, keep on authenticated"
  -- state. It is unusual in practice but verifies the role check is
  -- independent.
  ----------------------------------------
  create table public.anon_only_tbl(id int primary key);
  revoke select on public.anon_only_tbl from public;
  grant select on public.anon_only_tbl to anon;
  select * from lint."0027_pg_graphql_authenticated_table_exposed";

  rollback to savepoint case_authenticated_revoked;

  savepoint case_column_only_grant;

  ----------------------------------------
  -- POSITIVE (column-level grant only): `authenticated` has SELECT on
  -- a single column, no table-level SELECT, and no PUBLIC grant.
  -- pg_graphql exposes any relation with at least one selectable
  -- column, so the lint must too. has_table_privilege would have
  -- missed this case.
  ----------------------------------------
  create table public.col_grant_only(id int primary key, secret text);
  revoke select on public.col_grant_only from public, anon, authenticated;
  grant select (id) on public.col_grant_only to authenticated;

  select
    name,
    metadata->>'type' as object_type,
    cache_key
  from lint."0027_pg_graphql_authenticated_table_exposed";

  rollback to savepoint case_column_only_grant;

rollback;
