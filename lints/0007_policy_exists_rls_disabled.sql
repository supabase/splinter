create view lint."0007_policy_exists_rls_disabled" as

select
    'policy_exists_rls_disabled' as name,
    'INFO' as level,
    'EXTERNAL' as facing,
    'Detects cases where row level security (RLS) policies have been created, but RLS has not been enabled for the underlying table.' as description,
    format(
        'Table \`%s.%s\` has RLS policies but RLS is not enabled on the table. Policies include %s.',
        n.nspname,
        c.relname,
        array_agg(p.polname order by p.polname)
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0007_policy_exists_rls_disabled' as remediation,
    jsonb_build_object(
        'schema', n.nspname,
        'name', c.relname,
        'type', 'table'
    ) as metadata,
    format(
        'policy_exists_rls_disabled_%s_%s',
        n.nspname,
        c.relname
    ) as cache_key
from
    pg_catalog.pg_policy p
    join pg_catalog.pg_class c
        on p.polrelid = c.oid
    join pg_catalog.pg_namespace n
        on c.relnamespace = n.oid
where
    c.relkind = 'r' -- regular tables
    and n.nspname not in (
        'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgsodium', 'pgsodium_masks', 'pgbouncer', 'pg_catalog', 'pgtle', 'realtime', 'storage', 'supabase_functions', 'supabase_migrations', 'vault'
    )
    -- RLS is disabled
    and not c.relrowsecurity
group by
    n.nspname,
    c.relname;
