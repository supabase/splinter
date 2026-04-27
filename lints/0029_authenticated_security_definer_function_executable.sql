create view lint."0029_authenticated_security_definer_function_executable" as

-- Detects SECURITY DEFINER functions that the `authenticated` role
-- has EXECUTE on. SECURITY DEFINER functions run with the privileges
-- of their owner (typically a superuser-equivalent role) rather than
-- the caller, so they bypass RLS on every table they read or write.
-- Granting EXECUTE to `authenticated` therefore lets any signed-up
-- user invoke a privileged operation through PostgREST
-- `/rest/v1/rpc/<name>`, and through `/graphql/v1` Query/Mutation
-- fields when pg_graphql is installed and the return type is
-- supported. Under open or auto-confirm signup, "authenticated" is in
-- practice anyone with a throwaway email.
--
-- See lint 0028 for the equivalent check against the `anon` role.
-- Together with 0026/0027 they cover the four direct exposure paths:
-- anon-vs-authenticated × table-vs-function.
--
-- This lint deliberately does not gate on pg_graphql being installed:
-- PostgREST exposes `/rest/v1/rpc` independently and is the more
-- commonly deployed surface for the same risk.
select
    'authenticated_security_definer_function_executable' as name,
    'Signed-In Users Can Execute SECURITY DEFINER Function' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects `SECURITY DEFINER` functions that are callable by signed-in users. These functions run with the privileges of their owner, not the caller, so granting `EXECUTE` to `authenticated` can create a privileged RPC endpoint that bypasses RLS for any account holder. Revoke `EXECUTE`, switch the function to `SECURITY INVOKER`, or move it out of your exposed API schema if signed-in users should not call it.' as description,
    format(
        'Function `%s.%s(%s)` can be executed by the `authenticated` role. Because it is `SECURITY DEFINER`, any signed-in user can run it with the privileges of its owner via `/rest/v1/rpc/%s`. Revoke `EXECUTE` or switch it to `SECURITY INVOKER` if that is not intentional.',
        schema_name,
        function_name,
        function_args,
        function_name
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', function_name,
        'arguments', function_args,
        'language', function_language,
        'security_definer', true
    ) as metadata,
    format(
        'authenticated_security_definer_function_executable_%s_%s_%s',
        schema_name,
        function_name,
        function_args
    ) as cache_key
from
    (
        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_catalog.pg_get_function_identity_arguments(p.oid) as function_args,
            l.lanname as function_language
        from
            pg_catalog.pg_proc p
            join pg_catalog.pg_namespace n
                on p.pronamespace = n.oid
            join pg_catalog.pg_language l
                on p.prolang = l.oid
        where
            p.prosecdef = true
            and pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE')
            and n.nspname = any(array(select trim(unnest(string_to_array(current_setting('pgrst.db_schemas', 't'), ',')))))
            and n.nspname not in (
                '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
            )
    ) exposed_functions
order by
    schema_name,
    function_name,
    function_args;
