create view lint."0005_unused_index" as

select
    'unused_index' as name,
    'Unused Index' as title,
    'INFO' as level,
    'EXTERNAL' as facing,
    array['PERFORMANCE'] as categories,
    'Detects if an index has never been used and may be a candidate for removal.' as description,
    format(
        'Index \`%s\` on table \`%s.%s\` has not been used',
        i.relname,
        n.nspname,
        c.relname
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index' as remediation,
    jsonb_build_object(
        'schema', n.nspname,
        'name', c.relname,
        'type', 'table'
    ) as metadata,
    format(
        'unused_index_%s_%s_%s',
        n.nspname,
        c.relname,
        i.relname
    ) as cache_key

from
    -- pg_stat_user_indexes, inlined so idx_scan is read only for the candidate indexes
    pg_catalog.pg_index pi
    join pg_catalog.pg_class i
        on i.oid = pi.indexrelid
    join pg_catalog.pg_class c
        on c.oid = pi.indrelid
        and c.relkind in ('r', 't', 'm')
    join pg_catalog.pg_namespace n
        on n.oid = c.relnamespace
    left join pg_catalog.pg_depend dep
        on c.oid = dep.objid
        and dep.deptype = 'e'
        and dep.classid = 'pg_catalog.pg_class'::regclass
where
    pg_catalog.pg_stat_get_numscans(i.oid) = 0
    and not pi.indisunique
    and not pi.indisprimary
    and dep.objid is null -- exclude tables owned by extensions
    and n.nspname not in ('pg_catalog', 'information_schema')
    and n.nspname !~ '^pg_toast'
    and n.nspname not in (
        '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
    );
