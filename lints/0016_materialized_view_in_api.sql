create view lint."0016_materialized_view_in_api" as

select
    'materialized_view_in_api' as name,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects materialized views that are potentially accessible over APIs.' as description,
    format(
        'Materialized view \`%s.%s\` is selectable by anon or authenticated roles',
        n.nspname,
        c.relname
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0016_materialized_view_in_api' as remediation,
    jsonb_build_object(
        'schema', n.nspname,
        'name', c.relname,
        'type', 'materialized view'
    ) as metadata,
    format(
        'materialized_view_in_api_%s_%s',
        n.nspname,
        c.relname
    ) as cache_key
from
    pg_catalog.pg_class c
    join pg_catalog.pg_namespace n
        on n.oid = c.relnamespace
    left join pg_catalog.pg_depend dep
        on c.oid = dep.objid
        and dep.deptype = 'e'
where
    c.relkind = 'm'
    and (
        pg_catalog.has_table_privilege('anon', c.oid, 'SELECT')
        or pg_catalog.has_table_privilege('authenticated', c.oid, 'SELECT')
    )
    and n.nspname not in (
        'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgsodium', 'pgsodium_masks', 'pgbouncer', 'pg_catalog', 'pgtle', 'realtime', 'storage', 'supabase_functions', 'supabase_migrations', 'vault'
    )
    and dep.objid is null;
