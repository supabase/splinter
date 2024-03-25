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
    null as remediation,
     jsonb_build_object(
        'schema', pgns.nspname,
        'table', pgc.relname
    ) as metadata,
    format(
        'no_primary_key_%s_%s',
        pgns.nspname,
        pgc.relname
    ) as cache_key
from
    pg_class pgc
    join pg_namespace pgns
        on pgns.oid = pgc.relnamespace
    left join pg_index pgi
        on pgi.indrelid = pgc.oid
where
    pgc.relkind = 'r' -- regular tables
    and pgns.nspname not in (
        'pg_catalog', 'information_schema', 'auth', 'storage', 'vault', 'pgsodium'
    )
group by
    pgc.oid,
    pgns.nspname,
    pgc.relname
having
    max(coalesce(pgi.indisprimary, false)::int) = 0;
