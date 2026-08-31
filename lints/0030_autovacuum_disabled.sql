create view lint."0030_autovacuum_disabled" as
select
    'autovacuum_disabled' as name,
    'Autovacuum Disabled' as title,
    'INFO' as level,
    'EXTERNAL' as facing,
    array['PERFORMANCE'] as categories,
    'Table has autovacuum_enabled=false set as a storage parameter. Without autovacuum, dead tuples accumulate and cause table bloat — see the docs for legitimate exceptions before acting.' as description,
    format(
        'Table `%s`.`%s` has autovacuum_enabled=false set as a storage parameter.',
        nsp.nspname,
        cls.relname
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0030_autovacuum_disabled' as remediation,
    jsonb_build_object(
        'schema', nsp.nspname,
        'name', cls.relname,
        'type', 'table'
    ) as metadata,
    format('autovacuum_disabled_%s_%s', nsp.nspname, cls.relname) as cache_key
from pg_catalog.pg_class cls
join pg_catalog.pg_namespace nsp on cls.relnamespace = nsp.oid
where
    cls.relkind = 'r'
    and 'autovacuum_enabled=false' = any(cls.reloptions)
    and nsp.nspname not in (
        '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config',
        '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql',
        'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga',
        'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog',
        'realtime', 'repack', 'storage', 'supabase_functions',
        'supabase_migrations', 'tiger', 'topology', 'vault'
    )
order by
    nsp.nspname,
    cls.relname;
