create view lint."0026_pg_graphql_anon_table_exposed" as

-- Detects tables, views, and materialized views whose schema is visible
-- through pg_graphql introspection. pg_graphql introspection reflects the
-- calling role's Postgres privileges: if `anon` can SELECT an object, its
-- name, columns, and relationships are visible to anyone with the public
-- anon key via /graphql/v1, even when RLS is enabled.
with graphql_installed as (
    select 1 as installed
    from pg_catalog.pg_extension
    where extname = 'pg_graphql'
),
exposed_objects as (
    select
        n.nspname as schema_name,
        c.relname as object_name,
        c.relkind as object_relkind,
        case c.relkind
            when 'r' then 'table'
            when 'p' then 'table'
            when 'v' then 'view'
            when 'm' then 'materialized view'
        end as object_type
    from
        pg_catalog.pg_class c
        join pg_catalog.pg_namespace n
            on c.relnamespace = n.oid
    where
        c.relkind in ('r', 'p', 'v', 'm') -- tables, partitioned tables, views, materialized views
        and pg_catalog.has_table_privilege('anon', c.oid, 'SELECT')
        and exists (select 1 from graphql_installed)
        and n.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'pgtle', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
)
select
    'pg_graphql_anon_table_exposed' as name,
    'pg_graphql Anon Role Exposes Objects in Introspection' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects tables and views whose schema is visible via the public `/graphql/v1` introspection endpoint. When `pg_graphql` is installed, any table, view, or materialized view the `anon` role has `SELECT` on is visible in introspection — names, columns, types, and relationships — even when RLS is enabled. Both forms of introspection are intentional behavior; this lint surfaces the objects that are currently public so you can confirm each one is meant to be discoverable without authentication.' as description,
    format(
        'Extension `pg_graphql` is installed and the `anon` role has `SELECT` on %s `%s.%s`. Its name, columns, and relationships are visible via the public `/graphql/v1` introspection endpoint.',
        object_type,
        schema_name,
        object_name
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0026_pg_graphql_anon_table_exposed' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', object_name,
        'type', object_type
    ) as metadata,
    format(
        'pg_graphql_anon_table_exposed_%s_%s',
        schema_name,
        object_name
    ) as cache_key
from
    exposed_objects
order by
    schema_name,
    object_name;
