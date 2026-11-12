create view lint."0032_authenticated_dynamic_sql_function_executable" as

-- Detects PL/pgSQL functions that the `authenticated` role can EXECUTE and that
-- appear to EXECUTE a SQL string passed in by the caller, e.g.
-- `exec_sql(query text)`. PostgREST exposes them at
-- `/rest/v1/rpc/<name>`, so any signed-in user can run arbitrary SQL as the
-- function owner (SECURITY DEFINER) or as `authenticated` (SECURITY INVOKER).
--
-- A function is flagged when either:
--   1. a text/varchar parameter is used inside an EXECUTE statement
--      (EXECUTE ... USING bound values and quote_ident/quote_literal/
--      quote_nullable(param) are ignored), or
--   2. a text/varchar parameter has a SQL-like name (sql, query, stmt,
--      ...) and the body contains an EXECUTE anywhere.
--
-- Level is ERROR for SECURITY DEFINER functions matching (1), WARN
-- otherwise. Unlike 0028/0029 this also covers SECURITY INVOKER.
--
-- See lint 0031 for the equivalent check against `anon`.
with candidates as (
    select
        n.nspname as schema_name,
        p.proname as function_name,
        pg_catalog.pg_get_function_identity_arguments(p.oid) as function_args,
        l.lanname as function_language,
        p.prosecdef as is_security_definer,
        pg_catalog.pg_get_userbyid(p.proowner) as owner_name,
        regexp_replace(lower(p.prosrc), '--[^\n]*', '', 'g') as body,
        p.proargnames,
        p.proargmodes,
        coalesce(p.proallargtypes, p.proargtypes::pg_catalog.oid[]) as all_arg_types
    from
        pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n
            on p.pronamespace = n.oid
        join pg_catalog.pg_language l
            on p.prolang = l.oid
    where
        l.lanname = 'plpgsql'
        and pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE')
        and n.nspname = any(array(select trim(unnest(string_to_array(coalesce(current_setting('pgrst.db_schemas', 't'), 'public'), ',')))))
        and n.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
        -- exclude functions that belong to an extension
        and not exists (
            select 1
            from pg_catalog.pg_depend d
            where d.objid = p.oid
                and d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                and d.deptype = 'e'
        )
        and lower(p.prosrc) like '%execute%'
),
text_params as (
    select
        c.*,
        lower(coalesce(nullif(c.proargnames[a.ord], ''), '$' || a.ord)) as arg_name
    from
        candidates c
        cross join lateral unnest(c.all_arg_types) with ordinality as a(typ, ord)
    where
        coalesce(c.proargmodes[a.ord]::text, 'i') in ('i', 'b', 'v')
        and a.typ in ('pg_catalog.text'::pg_catalog.regtype, 'pg_catalog.varchar'::pg_catalog.regtype)
),
escaped as (
    select
        tp.*,
        regexp_replace(tp.arg_name, '([^a-z0-9_])', '\\\1', 'g') as arg_re
    from
        text_params tp
),
cleaned as (
    select
        e.*,
        -- ignore `USING` bound values and quote_*(param) wrappers
        regexp_replace(
            regexp_replace(e.body, '\musing\s+[^(\x3b\s][^\x3b]*', '', 'g'),
            'quote_(ident|literal|nullable)\s*\(\s*' || e.arg_re || '\s*\)',
            '',
            'g'
        ) as exec_body
    from
        escaped e
),
matches as (
    select
        cl.schema_name,
        cl.function_name,
        cl.function_args,
        cl.function_language,
        cl.is_security_definer,
        cl.owner_name,
        cl.arg_name,
        cl.exec_body ~ ('\mexecute\M[^\x3b]*[^a-z0-9_$]' || cl.arg_re || '([^a-z0-9_]|$)') as direct_use,
        cl.arg_name in ('sql', 'query', 'queries', 'stmt', 'statement', 'command', 'cmd', 'sql_text', 'sql_query', 'sql_string', 'query_text', 'query_string', 'raw_sql', 'raw_query')
            and cl.exec_body ~ '\mexecute\M' as renamed_use
    from
        cleaned cl
),
flagged as (
    select
        schema_name,
        function_name,
        function_args,
        function_language,
        is_security_definer,
        owner_name,
        bool_or(direct_use) as has_direct_use,
        array_agg(arg_name order by arg_name) as sql_parameters
    from
        matches
    where
        direct_use or renamed_use
    group by
        schema_name,
        function_name,
        function_args,
        function_language,
        is_security_definer,
        owner_name
)
select
    'authenticated_dynamic_sql_function_executable' as name,
    'Signed-In Users Can Execute Dynamic SQL Function' as title,
    case when is_security_definer and has_direct_use then 'ERROR' else 'WARN' end as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects functions callable by signed-in users that appear to run a SQL string passed in by the caller. Revoke `EXECUTE` or replace the function with fixed operations.' as description,
    format(
        'Function `%s.%s(%s)` is `SECURITY %s`, can be executed by the `authenticated` role via `/rest/v1/rpc/%s`, and appears to run SQL passed in `%s`. Revoke `EXECUTE` if that is not intentional.',
        schema_name,
        function_name,
        function_args,
        case when is_security_definer then 'DEFINER' else 'INVOKER' end,
        function_name,
        array_to_string(sql_parameters, ', ')
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0032_authenticated_dynamic_sql_function_executable' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', function_name,
        'type', 'function',
        'arguments', function_args,
        'language', function_language,
        'security_definer', is_security_definer,
        'owner', owner_name,
        'sql_parameters', sql_parameters
    ) as metadata,
    format(
        'authenticated_dynamic_sql_function_executable_%s_%s_%s',
        schema_name,
        function_name,
        function_args
    ) as cache_key
from
    flagged
order by
    schema_name,
    function_name,
    function_args;
