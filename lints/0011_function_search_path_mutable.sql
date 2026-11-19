create view lint."0011_function_search_path_mutable" as

with security_definer_fn_settings as (
    select
        n.nspname as schema_name,
        p.proname as function_name,
        p.prosrc as function_src,

        string_to_array(
            unnest(p.proconfig),
            '='
        ) as configuration_setting
    from pg_proc as p
    inner join pg_namespace as n on p.pronamespace = n.oid
    union all
    select
        n.nspname as schema_name,
        p.proname as function_name,
        p.prosrc as function_src,
        array[]::text [] as configuration_setting
    from pg_proc as p
    inner join pg_namespace as n on p.pronamespace = n.oid
    where p.proconfig is null
),

security_definer_fn_search_paths as (
    select
        s.schema_name,
        s.function_name,
        s.function_src,
        string_to_array(btrim(
            (s.configuration_setting)[2],
            '"'
        ),
        ',') as search_path_ary
    from security_definer_fn_settings as s
    where (s.configuration_setting)[1] = 'search_path'
    union all
    select
        s.schema_name,
        s.function_name,
        s.function_src,
        array[]::text [] as search_path_ary
    from security_definer_fn_settings as s
    where
        (s.configuration_setting)[1] <> 'search_path'
        or cardinality(s.configuration_setting) = 0

),

security_definer_fn_search_paths_trimmed as (
    select
        s.schema_name,
        s.function_src,
        s.function_name,
        array(
            select pg_catalog.btrim(x)
            from unnest(s.search_path_ary) with ordinality as t (x, i)
            order by i
        ) as search_path_ary
    from security_definer_fn_search_paths as s
)

select
    'function_search_path_mutable' as name,
    'Function Search Path Mutable' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects functions where the search_path parameter is not set.'
        as description,
    format(
        'Function \`%s.%s\` has a role mutable search_path',
        s.schema_name,
        s.function_name
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable'
        as remediation,
    jsonb_build_object(
        'schema', s.schema_name,
        'name', s.function_name,
        'type', 'function'
    ) as metadata,
    format(
        'function_search_path_mutable_%s_%s_%s',
        s.schema_name,
        s.function_name,
        md5(s.function_src) -- required when function is polymorphic
    ) as cache_key
from security_definer_fn_search_paths_trimmed as s
where s.schema_name not in (
    '_timescaledb_cache',
    '_timescaledb_catalog',
    '_timescaledb_config',
    '_timescaledb_internal',
    'auth',
    'cron',
    'extensions',
    'graphql',
    'graphql_public',
    'information_schema',
    'net',
    'pgmq',
    'pgroonga',
    'pgsodium',
    'pgsodium_masks',
    'pgtle',
    'pgbouncer',
    'pg_catalog',
    'realtime',
    'repack',
    'storage',
    'supabas
e_functions',
    'supabase_migrations',
    'tiger',
    'topology',
    'vault'
)
and (
    (
        array_position(s.search_path_ary, 'pg_temp')
        < array_position(s.search_path_ary, 'pg_catalog')
    )
    or array_position(s.search_path_ary, 'pg_temp') is null
    or array_position(s.search_path_ary, 'pg_catalog') is null
);
