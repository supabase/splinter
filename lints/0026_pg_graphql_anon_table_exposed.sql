create view lint."0026_pg_graphql_anon_table_exposed" as

-- Detects tables whose schema is leaked through pg_graphql introspection.
-- pg_graphql introspection reflects the calling role's Postgres privileges:
-- if `anon` can SELECT a table, the table name, columns, and relationships
-- are visible to anyone with the public anon key via /graphql/v1, even when
-- RLS is enabled.
with graphql_installed as (
    select 1 as installed
    from pg_catalog.pg_extension
    where extname = 'pg_graphql'
),
exposed_tables as (
    select
        n.nspname as schema_name,
        c.relname as table_name
    from
        pg_catalog.pg_class c
        join pg_catalog.pg_namespace n
            on c.relnamespace = n.oid
    where
        c.relkind in ('r', 'p') -- regular or partitioned tables
        and pg_catalog.has_table_privilege('anon', c.oid, 'SELECT')
        and exists (select 1 from graphql_installed)
        and n.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'pgtle', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
)
select
    'pg_graphql_anon_table_exposed' as name,
    'pg_graphql Anon Role Exposes Tables in Introspection' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects tables whose schema is leaked via the public `/graphql/v1` introspection endpoint. When `pg_graphql` is installed, any table the `anon` role has `SELECT` on is visible in introspection — names, columns, types, and relationships — even when RLS is enabled.' as description,
    format(
        'Extension `pg_graphql` is installed and the `anon` role has `SELECT` on `%s.%s`. The table''s name, columns, and relationships are visible via the public `/graphql/v1` introspection endpoint.',
        schema_name,
        table_name
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0026_pg_graphql_anon_table_exposed' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', table_name,
        'type', 'table'
    ) as metadata,
    format(
        'pg_graphql_anon_table_exposed_%s_%s',
        schema_name,
        table_name
    ) as cache_key
from
    exposed_tables
order by
    schema_name,
    table_name;
