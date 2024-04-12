create view lint."0004_no_primary_key" as

select
    'no_primary_key' as name,
    'INFO' as level,
    'EXTERNAL' as facing,
    'Detects if a table does not have a primary key. Tables without a primary key can be inefficient to interact with at scale.' as description,
    format(
        'Table \`%s.%s\` does not have a primary key',
        pgns.nspname,
        pgc.relname
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0004_no_primary_key' as remediation,
     jsonb_build_object(
        'schema', pgns.nspname,
        'name', pgc.relname,
        'type', 'table'
    ) as metadata,
    format(
        'no_primary_key_%s_%s',
        pgns.nspname,
        pgc.relname
    ) as cache_key
from
    pg_catalog.pg_class pgc
    join pg_catalog.pg_namespace pgns
        on pgns.oid = pgc.relnamespace
    left join pg_catalog.pg_index pgi
        on pgi.indrelid = pgc.oid
    left join pg_catalog.pg_depend dep
        on pgc.oid = dep.objid
        and dep.deptype = 'e'
where
    pgc.relkind = 'r' -- regular tables
    and pgns.nspname not in (
        'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgsodium', 'pgsodium_masks', 'pgbouncer', 'pg_catalog', 'pgtle', 'realtime', 'storage', 'supabase_functions', 'supabase_migrations', 'vault'
    )
    and dep.objid is null -- exclude tables owned by extensions
group by
    pgc.oid,
    pgns.nspname,
    pgc.relname
having
    max(coalesce(pgi.indisprimary, false)::int) = 0;
