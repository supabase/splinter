create view lint."0034_definer_function_uses_current_user" as

-- Detects SECURITY DEFINER functions that use `current_user`, `current_role`
-- or `user` to make an authorization decision.
--
-- Inside a SECURITY DEFINER function, `current_user` is the function's owner,
-- not the caller. A check such as `current_user = 'admin'` is therefore
-- decided by who owns the function and is the same for every caller. For
-- caller identity use `auth.uid()`, `auth.role()` or the `request.jwt.claims`
-- setting. `session_user` is not a fix: through the Data API it is the
-- connection role (`authenticator`), not the end user.
--
-- Heuristic (prosrc is matched as text, so it is deliberately narrow):
--   1. Comments, quoted identifiers and string literals are blanked out, so
--      `'current_user'`, `"user"` and `-- current_user` never match.
--   2. Qualified names (`t.user`, `x.current_user`) and longer identifiers
--      (`user_id`, `my_current_user`) never match; `user` is a reserved word,
--      so a bare unquoted `user` is always the function.
--   3. Only authorization-like uses count: the token is an operand of a
--      comparison (`=`, `<>`, `!=`, `in`, `any`, `like`, `is distinct from`)
--      or an argument to a membership/privilege function (`pg_has_role`,
--      `has_*_privilege`). Plain reads, such as an audit column default or
--      `values (current_user)`, and `set col = current_user` assignments are
--      ignored.
--   4. Functions that switch identity first (`set role`,
--      `set session authorization`) are skipped.
-- Only SQL and PL/pgSQL functions are examined.
with definer_functions as (
    select
        n.nspname as schema_name,
        p.proname as function_name,
        pg_catalog.pg_get_function_identity_arguments(p.oid) as function_args,
        l.lanname as function_language,
        -- 1. blank out comments, quoted identifiers and string literals
        pg_catalog.lower(
            pg_catalog.regexp_replace(
                pg_catalog.regexp_replace(
                    pg_catalog.regexp_replace(
                        pg_catalog.regexp_replace(
                            coalesce(p.prosrc, ''),
                            '/\*.*?\*/', ' ', 'g'
                        ),
                        '--[^\n]*', ' ', 'g'
                    ),
                    '''(''''|[^''])*''', '''''', 'g'
                ),
                '"[^"]*"', '""', 'g'
            )
        ) as src
    from
        pg_catalog.pg_proc p
        join pg_catalog.pg_namespace n
            on p.pronamespace = n.oid
        join pg_catalog.pg_language l
            on p.prolang = l.oid
    where
        p.prosecdef
        and l.lanname in ('sql', 'plpgsql')
        and n.nspname = any(array(select trim(unnest(string_to_array(coalesce(current_setting('pgrst.db_schemas', 't'), 'public'), ',')))))
        and n.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
        -- extension-owned functions are not the user's to change
        and not exists (
            select 1
            from pg_catalog.pg_depend d
            where d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                and d.objid = p.oid
                and d.deptype = 'e'
        )
),
cleaned as (
    select
        f.*,
        -- 3. drop `set col = current_user` / `, col = current_user` assignments
        pg_catalog.regexp_replace(
            f.src,
            '(\mset\M|,)\s*[a-z_][a-z0-9_]*\s*=\s*(current_user|current_role|user)\M',
            ' ', 'g'
        ) as src_no_assign
    from
        definer_functions f
),
findings as (
    select
        schema_name,
        function_name,
        function_args,
        function_language
    from
        cleaned
    where
        -- 4. identity is switched inside the function
        src !~ '\mset\s+(local\s+|session\s+)?(role|session\s+authorization)\M'
        and (
            -- token on the left of a comparison
            src_no_assign ~ '(^|[^[:alnum:]_.$])(current_user|current_role|user)\s*(=|<>|!=|\min\M|\mnot\s+in\M|\mlike\M|\mis\s+(not\s+)?distinct\s+from\M)'
            -- token on the right of a comparison
            or src_no_assign ~ '(=|<>|!=|\min\M\s*\(?|\many\M\s*\(?|\mlike\M)\s*\(?\s*(current_user|current_role|user)($|[^[:alnum:]_.$])'
            -- token passed to a membership or privilege function
            or src_no_assign ~ '\m(pg_has_role|has_[a-z_]+_privilege)\s*\(\s*(current_user|current_role|user)($|[^[:alnum:]_.$])'
        )
)
select
    'definer_function_uses_current_user' as name,
    'SECURITY DEFINER Function Checks current_user' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects `SECURITY DEFINER` functions that compare `current_user` or `current_role`. Inside such a function these are the function owner, not the caller. Use `auth.uid()` or `auth.role()` to identify the caller.' as description,
    format(
        'Function `%s.%s(%s)` is `SECURITY DEFINER` and uses `current_user`, `current_role` or `user` in a comparison. It always evaluates to the function owner, not the caller.',
        schema_name,
        function_name,
        function_args
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0034_definer_function_uses_current_user' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', function_name,
        'arguments', function_args,
        'language', function_language,
        'security_definer', true
    ) as metadata,
    format(
        'definer_function_uses_current_user_%s_%s_%s',
        schema_name,
        function_name,
        function_args
    ) as cache_key
from
    findings
order by
    schema_name,
    function_name,
    function_args;
