create view lint."0026_pg_graphql_anon_table_exposed" as

-- Detects tables, views, materialized views, and foreign tables whose
-- schema is visible to the `anon` role through pg_graphql introspection.
-- pg_graphql introspection reflects the calling role's Postgres
-- privileges: if `anon` can SELECT an object, its name, columns, and
-- relationships are visible via /graphql/v1 to anyone with the public
-- anon key, even when RLS is enabled.
--
-- See lint 0027 for the equivalent check against the `authenticated`
-- role. In default Supabase projects the two roles share the same
-- default-privilege grants, so revoking from `anon` alone often leaves
-- the introspection response served to any signed-up user unchanged.
--
-- The privilege check uses has_column_privilege rather than
-- has_table_privilege so that column-level grants such as
-- `GRANT SELECT (some_col) ON t TO anon` are also caught: pg_graphql
-- exposes a relation in introspection if any column is selectable to
-- the calling role (`load_sql_context.sql:327`,
-- `is_column_selectable`).
--
-- The relkind set ('r','v','m','f') matches pg_graphql's own filter in
-- load_sql_context.sql. Partitioned table roots ('p') are excluded
-- because pg_graphql does not expose them; their leaf partitions ('r')
-- are still picked up.
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
            when 'v' then 'view'
            when 'm' then 'materialized view'
            when 'f' then 'foreign table'
        end as object_type
    from
        pg_catalog.pg_class c
        join pg_catalog.pg_namespace n
            on c.relnamespace = n.oid
    where
        c.relkind in ('r', 'v', 'm', 'f') -- tables, views, materialized views, foreign tables; matches pg_graphql
        and exists (
            -- Any selectable column (table-level or column-level grant)
            select 1
            from pg_catalog.pg_attribute a
            where a.attrelid = c.oid
                and a.attnum > 0
                and not a.attisdropped
                and pg_catalog.has_column_privilege('anon', c.oid, a.attnum, 'SELECT')
        )
        and exists (select 1 from graphql_installed)
        and n.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
)
select
    'pg_graphql_anon_table_exposed' as name,
    'Public Can See Object in GraphQL Schema' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects tables, views, materialized views, and foreign tables that are visible in the GraphQL schema to anyone using your public anon key. Revoke `SELECT` from `anon` for objects that should not be discoverable before sign-in, and check lint 0027 for the matching signed-in-user exposure.' as description,
    format(
        '%s `%s.%s` is visible in the GraphQL schema because the `anon` role can `SELECT` it. Revoke `SELECT` from `anon` if it should not be discoverable without signing in.',
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
