create view lint."0035_policy_on_anon_role" as

-- A policy applies to `anon` when its role list is `public` (no TO clause) or
-- names a role that `anon` is a member of. SELECT policies are skipped only
-- when the expression is a literal `true` (deliberate public read).
with anon_role as (
    select
        r.oid
    from
        pg_catalog.pg_roles r
    where
        r.rolname = 'anon'
),

policies as (
    select
        nsp.nspname as schema_name,
        pc.relname as table_name,
        pa.polname as policy_name,
        case pa.polcmd
            when 'r' then 'SELECT'
            when 'a' then 'INSERT'
            when 'w' then 'UPDATE'
            when 'd' then 'DELETE'
            when '*' then 'ALL'
        end as command,
        (
            select
                array_agg(x.role_name order by x.role_name)
            from
                (
                    select
                        case when u.role_oid = 0 then 'public' else u.role_oid::pg_catalog.regrole::text end as role_name
                    from
                        unnest(pa.polroles) as u(role_oid)
                    where
                        u.role_oid = 0
                        or pg_catalog.pg_has_role(anon_role.oid, u.role_oid, 'usage')
                ) x
        ) as anon_roles,
        coalesce(pg_catalog.pg_get_expr(pa.polqual, pa.polrelid), '') as qual,
        coalesce(pg_catalog.pg_get_expr(pa.polwithcheck, pa.polrelid), '') as with_check
    from
        pg_catalog.pg_policy pa
        join pg_catalog.pg_class pc
            on pa.polrelid = pc.oid
        join pg_catalog.pg_namespace nsp
            on pc.relnamespace = nsp.oid
        cross join anon_role
        left join pg_catalog.pg_depend dep
            on pc.oid = dep.objid
            and dep.deptype = 'e'
            and dep.classid = 'pg_catalog.pg_class'::pg_catalog.regclass
    where
        pc.relkind in ('r', 'p')
        and pa.polpermissive
        and dep.objid is null -- exclude tables owned by extensions
        -- NOTE: does not exclude realtime or storage in support of monitoring user-authored
        -- policies on realtime.messages and storage.objects
        and nsp.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'repack', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
),

flagged as (
    select
        p.*
    from
        policies p
    where
        p.anon_roles is not null
)

select
    'policy_on_anon_role' as name,
    'RLS Policy Applies to Anon Role' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects permissive RLS policies that apply to the `anon` role, directly or through `public`. `anon` is also the role a JWT without a `role` claim (such as an OIDC ID token) resolves to, so restrict identity-based policies with `TO authenticated`.' as description,
    format(
        'Table `%s.%s` has a permissive RLS policy `%s` for `%s` that applies to the `anon` role (via `%s`). Add `TO authenticated` or an explicit role check if it is not meant for signed-out or role-less tokens.',
        schema_name,
        table_name,
        policy_name,
        command,
        array_to_string(anon_roles, ', ')
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0035_policy_on_anon_role' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', table_name,
        'type', 'table',
        'policy_name', policy_name,
        'command', command,
        'roles', anon_roles
    ) as metadata,
    format(
        'policy_on_anon_role_%s_%s_%s',
        schema_name,
        table_name,
        policy_name
    ) as cache_key
from
    flagged
where
    command <> 'SELECT'
    or qual !~ '^\(*(true)?\)*$'
order by
    schema_name,
    table_name,
    policy_name;
