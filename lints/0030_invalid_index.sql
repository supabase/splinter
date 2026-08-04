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
    format(
        'Index `%s` on table `%s.%s` is invalid and is not used by the query planner.',
        ic.relname,
        nsp.nspname,
        tc.relname
    ) as detail,
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
where
    not pi.indisvalid
    and dep.objid is null -- exclude indexes owned by extensions
    and nsp.nspname not in (
        '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config',
        '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql',
        'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga',
        'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog',
        'pgtle', 'realtime', 'repack', 'storage', 'supabase_functions',
        'supabase_migrations', 'tiger', 'topology', 'vault'
    )
order by
    nsp.nspname,
    tc.relname,
    ic.relname;
