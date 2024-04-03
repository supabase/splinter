create view lint."0011_function_search_path_mutable" as

select
    'function_search_path_mutable' as name,
    'WARN' as level,
    'EXTERNAL' as facing,
    'Detects functions with a mutable search_path parameter which could fail to execute sucessfully for some roles.' as description,
    format(
        'Function \`%s.%s\` has a role mutable search_path',
        n.nspname,
        p.proname
    ) as detail,
    'https://supabase.github.io/splinter/0011_function_search_path_mutable' as remediation,
    jsonb_build_object(
        'schema', n.nspname,
        'name', p.proname,
        'type', 'function'
    ) as metadata,
    format(
        'function_search_path_mutable_%s_%s_%s',
        n.nspname,
        p.proname,
        md5(p.prosrc) -- required when function is polymorphic
    ) as cache_key
from
    pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n
        on p.pronamespace = n.oid
where
    n.nspname not in (
        'pg_catalog', 'information_schema', 'auth', 'storage', 'vault', 'pgsodium', 'graphql', 'graphql_public'
    )
    -- Search path not set to ''
    and not coalesce(p.proconfig, '{}') && array['search_path=""'];
