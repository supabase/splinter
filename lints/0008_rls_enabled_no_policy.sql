create view lint."0008_rls_enabled_no_policy" as

select
    'rls_enabled_no_policy' as name,
    'INFO' as level,
    'EXTERNAL' as facing,
    'Detects cases where row level security (RLS) has been enabled on a table but no RLS policies have been created.' as description,
    format(
        'Table \`%s.%s\` has RLS enabled, but no policies exist',
        n.nspname,
        c.relname
    ) as detail,
    'https://supabase.github.io/splinter/0008_rls_enabled_no_policy' as remediation,
    jsonb_build_object(
        'schema', n.nspname,
        'name', c.relname,
        'type', 'table'
    ) as metadata,
    format(
        'rls_enabled_no_policy_%s_%s',
        n.nspname,
        c.relname
    ) as cache_key
from
    pg_catalog.pg_class c
    left join pg_catalog.pg_policy p
        on p.polrelid = c.oid
    join pg_catalog.pg_namespace n
        on c.relnamespace = n.oid
where
    c.relkind = 'r' -- regular tables
    and n.nspname not in (
        'pg_catalog', 'information_schema', 'auth', 'extensions', 'graphql', 'graphql_public', 'net', 'pgsodium', 'storage', 'supabase_functions', 'vault'
    )
    -- RLS is enabled
    and c.relrowsecurity
    and p.polname is null
group by
    n.nspname,
    c.relname;
