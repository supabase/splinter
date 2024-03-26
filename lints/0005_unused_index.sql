create view lint."0005_unused_index" as

select
    'unused_index' as name,
    'INFO' as level,
    'EXTERNAL' as facing,
    'Detects if an index has never been used and may be a candidate for removal.' as description,
    format(
        'Index `\%s\` on table \`%s.%s\` has not been used',
        psui.indexrelname,
        psui.schemaname,
        psui.relname
    ) as detail,
    null as remediation,
    jsonb_build_object(
        'schema', psui.schemaname,
        'name', psui.relname,
        'type', 'table'
    ) as metadata,
    format(
        'unused_index_%s_%s_%s',
        psui.schemaname,
        psui.relname,
        psui.indexrelname
    ) as cache_key

from
    pg_catalog.pg_stat_user_indexes psui
    join pg_catalog.pg_index pi
        on psui.indexrelid = pi.indexrelid
where
    psui.idx_scan = 0
    and not pi.indisunique
    and not pi.indisprimary
    and psui.schemaname not in (
        'pg_catalog', 'information_schema', 'auth', 'storage', 'vault', 'pgsodium'
    );
