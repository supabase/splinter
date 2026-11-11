create view lint."0031_policy_function_not_executable" as

-- Detects RLS policies whose USING / WITH CHECK expression calls a function
-- that a role the policy applies to cannot EXECUTE.
--
-- A policy expression is evaluated with the privileges of the querying role,
-- not the policy owner. If that role lacks EXECUTE on a function named in the
-- expression, every statement the policy applies to fails with
-- `permission denied for function`. It is a hard error, not a filtered row.
--
-- Dependencies come from pg_depend (policy -> function, normal dependency).
-- Built-in functions are pinned and never appear there, so only user or
-- extension functions are checked. A policy with no TO clause applies to
-- PUBLIC, which is expanded to the Supabase API roles anon and authenticated.
-- Roles that do not exist in the database are ignored.
--
-- The check is not limited to exposed schemas: the failure happens for any
-- querying role, not only through the Data API.
with policy_functions as (
    select distinct
        pol.oid as policy_oid,
        pol.polrelid,
        pol.polname,
        pol.polcmd,
        pol.polroles,
        dep.refobjid as function_oid
    from
        pg_catalog.pg_policy pol
        join pg_catalog.pg_depend dep
            on dep.classid = 'pg_catalog.pg_policy'::pg_catalog.regclass
            and dep.objid = pol.oid
            and dep.refclassid = 'pg_catalog.pg_proc'::pg_catalog.regclass
            and dep.deptype = 'n'
),
policy_roles as (
    select
        pf.*,
        r.rolname as role_name
    from
        policy_functions pf
        cross join lateral (
            select
                ro.rolname
            from
                pg_catalog.pg_roles ro
            where
                case
                    when pf.polroles = array[0::oid] then ro.rolname in ('anon', 'authenticated')
                    else ro.oid = any(pf.polroles)
                end
        ) r
),
findings as (
    select
        nsp.nspname as schema_name,
        cls.relname as table_name,
        pr.polname as policy_name,
        case pr.polcmd
            when 'r' then 'SELECT'
            when 'a' then 'INSERT'
            when 'w' then 'UPDATE'
            when 'd' then 'DELETE'
            when '*' then 'ALL'
        end as command,
        fn_nsp.nspname as function_schema,
        fn.proname as function_name,
        pg_catalog.pg_get_function_identity_arguments(fn.oid) as function_args,
        pr.role_name
    from
        policy_roles pr
        join pg_catalog.pg_class cls
            on cls.oid = pr.polrelid
        join pg_catalog.pg_namespace nsp
            on nsp.oid = cls.relnamespace
        join pg_catalog.pg_proc fn
            on fn.oid = pr.function_oid
        join pg_catalog.pg_namespace fn_nsp
            on fn_nsp.oid = fn.pronamespace
    where
        -- Policies on tables without RLS enabled are never evaluated
        cls.relrowsecurity
        and not pg_catalog.has_function_privilege(pr.role_name, fn.oid, 'EXECUTE')
        and nsp.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
)
select
    'policy_function_not_executable' as name,
    'Policy Calls Function Its Role Cannot Execute' as title,
    'ERROR' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects RLS policies that call a function the policy''s role has no `EXECUTE` privilege on. Every query by that role on the table fails with `permission denied for function`. Grant `EXECUTE` to exactly the roles the policy applies to.' as description,
    format(
        'Policy `%s` on table `%s.%s` calls function `%s.%s(%s)`, but role `%s` cannot execute it. Queries by this role on the table fail with a permission error.',
        policy_name,
        schema_name,
        table_name,
        function_schema,
        function_name,
        function_args,
        role_name
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0031_policy_function_not_executable' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', table_name,
        'type', 'table',
        'policy_name', policy_name,
        'command', command,
        'role', role_name,
        'function_schema', function_schema,
        'function_name', function_name,
        'function_arguments', function_args
    ) as metadata,
    format(
        'policy_function_not_executable_%s_%s_%s_%s_%s_%s',
        schema_name,
        table_name,
        policy_name,
        function_schema,
        function_name || '(' || function_args || ')',
        role_name
    ) as cache_key
from
    findings
order by
    schema_name,
    table_name,
    policy_name,
    function_schema,
    function_name,
    function_args,
    role_name;
