create view lint."0030_invalid_index" as

-- Detects indexes marked as invalid in pg_index.indisvalid, typically left behind
-- by a failed `CREATE INDEX CONCURRENTLY` or `REINDEX CONCURRENTLY`. Invalid
-- indexes are never used by the query planner but still consume disk space and
-- take a write penalty to maintain.
select
    'invalid_index' as name,
    'Invalid Index' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['PERFORMANCE'] as categories,
    'Detects indexes marked as invalid, typically left behind by a failed `CREATE INDEX CONCURRENTLY` or `REINDEX CONCURRENTLY`. Invalid indexes are ignored by the planner but still incur maintenance overhead.' as description,
    case
        when con.oid is not null then format(
            'Index `%s` on table `%s.%s` is invalid and is not used by the query planner. It backs an exclusion constraint and cannot be reindexed concurrently. Rebuild it with `reindex index %s.%s;`. Note that a non-concurrent reindex blocks writes to the table and may take significant time on large tables.',
            ic.relname,
            nsp.nspname,
            tc.relname,
            pg_catalog.quote_ident(nsp.nspname),
            pg_catalog.quote_ident(ic.relname)
        )
        else format(
            'Index `%s` on table `%s.%s` is invalid and is not used by the query planner. Rebuild it with `reindex index concurrently %s.%s;`',
            ic.relname,
            nsp.nspname,
            tc.relname,
            pg_catalog.quote_ident(nsp.nspname),
            pg_catalog.quote_ident(ic.relname)
        )
    end as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0030_invalid_index' as remediation,
    jsonb_build_object(
        'schema', nsp.nspname,
        'name', tc.relname,
        'type', 'table',
        'index_name', ic.relname
    ) as metadata,
    format('invalid_index_%s_%s_%s', nsp.nspname, tc.relname, ic.relname) as cache_key
from
    pg_catalog.pg_index pi
    join pg_catalog.pg_class ic
        on pi.indexrelid = ic.oid
    join pg_catalog.pg_class tc
        on pi.indrelid = tc.oid
    join pg_catalog.pg_namespace nsp
        on tc.relnamespace = nsp.oid
    left join pg_catalog.pg_depend dep
        on dep.objid = ic.oid
        and dep.deptype = 'e'
        and dep.classid = 'pg_catalog.pg_class'::regclass
    left join pg_catalog.pg_constraint con
        on con.conindid = ic.oid
        and con.contype = 'x'
where
    not pi.indisvalid
    and pi.indisready -- exclude indexes that are still being built (phase 1)
    and not exists ( -- exclude indexes actively being built (phase 2+)
        select 1 from pg_catalog.pg_stat_progress_create_index pci
        where pci.index_relid = ic.oid
    )
    and dep.objid is null -- exclude indexes owned by extensions
    and nsp.nspname not in (
        '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config',
        '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql',
        'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga',
        'pgsodium', 'pgsodium_masks', 'pgbouncer', 'pg_catalog',
        'pgtle', 'realtime', 'repack', 'storage', 'supabase_functions',
        'supabase_migrations', 'tiger', 'topology', 'vault'
    )
order by
    nsp.nspname,
    tc.relname,
    ic.relname;
