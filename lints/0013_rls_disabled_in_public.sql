create view lint."0013_rls_disabled_in_public" as

select
    'rls_disabled_in_public' as name,
    'ERROR' as level,
    'EXTERNAL' as facing,
    'Detects cases where row level security (RLS) has not been enabled on a table in the `public` schema.' as description,
    format(
        'Table \`%s.%s\` is in the `public` but RLS has not been enabled.',
        n.nspname,
        c.relname
    ) as detail,
    'https://supabase.github.io/splinter/0013_rls_disabled_in_public' as remediation,
    jsonb_build_object(
        'schema', n.nspname,
        'name', c.relname,
        'type', 'table'
    ) as metadata,
    format(
        'rls_disabled_in_public_%s_%s',
        n.nspname,
        c.relname
    ) as cache_key
from
    pg_catalog.pg_class c
    join pg_catalog.pg_namespace n
        on c.relnamespace = n.oid
where
    c.relkind = 'r' -- regular tables
    and n.nspname = 'public'
    -- RLS is disabled
    and not c.relrowsecurity;
