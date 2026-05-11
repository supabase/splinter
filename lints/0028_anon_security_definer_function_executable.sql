create view lint."0028_anon_security_definer_function_executable" as

-- Detects SECURITY DEFINER functions that the `anon` role has EXECUTE
-- on. SECURITY DEFINER functions run with the privileges of their
-- owner (typically a superuser-equivalent role) rather than the
-- caller, so they bypass RLS on every table they read or write.
-- Granting EXECUTE to `anon` therefore lets any holder of the public
-- anon key invoke a privileged operation through PostgREST
-- `/rest/v1/rpc/<name>`, and through `/graphql/v1` Query/Mutation
-- fields when pg_graphql is installed and the return type is
-- supported.
--
-- See lint 0029 for the equivalent check against the `authenticated`
-- role. Together with 0026/0027 they cover the four direct
-- exposure paths: anon-vs-authenticated × table-vs-function.
--
-- This lint deliberately does not gate on pg_graphql being installed:
-- PostgREST exposes `/rest/v1/rpc` independently and is the more
-- commonly deployed surface for the same risk.
select
    'anon_security_definer_function_executable' as name,
    'Public Can Execute SECURITY DEFINER Function' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects `SECURITY DEFINER` functions that are callable without signing in. Revoke `EXECUTE`, switch the function to `SECURITY INVOKER`, or move it out of your exposed API schema if it is not meant to be public.' as description,
    format(
        'Function `%s.%s(%s)` can be executed by the `anon` role as a `SECURITY DEFINER` function via `/rest/v1/rpc/%s`. Revoke `EXECUTE` or switch it to `SECURITY INVOKER` if that is not intentional.',
        schema_name,
        function_name,
        function_args,
        function_name
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', function_name,
        'arguments', function_args,
        'language', function_language,
        'security_definer', true
    ) as metadata,
    format(
        'anon_security_definer_function_executable_%s_%s_%s',
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
            and pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE')
            and n.nspname = any(array(select trim(unnest(string_to_array(current_setting('pgrst.db_schemas', 't'), ',')))))
            and n.nspname not in (
                '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
            )
    ) exposed_functions
order by
    schema_name,
    function_name,
    function_args;
