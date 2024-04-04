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
    'https://supabase.github.io/splinter/0004_no_primary_key' as remediation,
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
where
    pgc.relkind = 'r' -- regular tables
    and pgns.nspname not in (
        'pg_catalog', 'information_schema', 'auth', 'extensions', 'graphql', 'graphql_public', 'net', 'pgsodium', 'storage', 'supabase_functions', 'vault'
    )
group by
    pgc.oid,
    pgns.nspname,
    pgc.relname
having
    max(coalesce(pgi.indisprimary, false)::int) = 0;
