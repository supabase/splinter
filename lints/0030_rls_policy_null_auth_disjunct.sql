create view lint."0030_rls_policy_null_auth_disjunct" as

-- Detects permissive RLS read policies (SELECT / ALL) whose USING clause has a
-- top-level OR disjunct that is true when an auth function returns NULL --
-- e.g. `auth.uid() IS NULL OR owner_id = auth.uid()`, the `auth.jwt()` /
-- `auth.role()` / `current_setting(name, true)` variants, or the
-- `NOT (auth.uid() IS NOT NULL)` inversion. For any session where that function
-- is NULL the disjunct is true, so the whole USING is true and the policy admits
-- every row. It is a logic error -- the author almost always meant
-- `IS NOT NULL AND ...` or a scoped predicate -- and is distinct from
-- 0024 (literal `USING (true)`), which cannot see this shape.
with policies as (
    select
        nsp.nspname as schema_name,
        pb.tablename as table_name,
        pc.relrowsecurity as is_rls_active,
        pa.polname as policy_name,
        pa.polpermissive as is_permissive,
        pa.polroles as role_oids,
        (
            select array_agg(case when r = 0 then 'public' else r::regrole::text end order by r)
            from unnest(pa.polroles) as x(r)
        ) as roles,
        case pa.polcmd
            when 'r' then 'SELECT'
            when 'a' then 'INSERT'
            when 'w' then 'UPDATE'
            when 'd' then 'DELETE'
            when '*' then 'ALL'
        end as command,
        pb.qual,
        -- Normalize: lowercase, strip whitespace (matches 0024's normalization)
        lower(replace(replace(replace(coalesce(pb.qual, ''), ' ', ''), E'\n', ''), E'\t', '')) as normalized_qual
    from
        pg_catalog.pg_policy pa
        join pg_catalog.pg_class pc
            on pa.polrelid = pc.oid
        join pg_catalog.pg_namespace nsp
            on pc.relnamespace = nsp.oid
        join pg_catalog.pg_policies pb
            on pc.relname = pb.tablename
            and nsp.nspname = pb.schemaname
            and pa.polname = pb.policyname
    where
        pc.relkind = 'r' -- regular tables
        and nsp.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
),
candidates as (
    select
        p.*,
        -- (1) Replace each *nullable* auth null-check with a paren-free sentinel:
        --     the `NOT (<fn> IS NOT NULL)` inversion, then the `<fn> IS NULL` form,
        --     for auth.uid()/auth.jwt()/auth.role() and current_setting(name, true).
        --     current_setting(name) / current_setting(name, false) RAISE rather
        --     than return NULL, so they are deliberately excluded.
        -- (2) Neutralize any remaining auth.*()/current_setting(...) call parens to
        --     a paren-free token so only *structural* parens are left to analyze.
        regexp_replace(
            regexp_replace(
                regexp_replace(
                    regexp_replace(
                        normalized_qual,
                        'not\((auth\.(uid|jwt|role)\(\)|current_setting\([^)]*,true\))isnotnull\)', 'xnullchkx', 'g'
                    ),
                    '(auth\.(uid|jwt|role)\(\)|current_setting\([^)]*,true\))isnull', 'xnullchkx', 'g'
                ),
                'current_setting\([^)]*\)', 'fff', 'g'
            ),
            'auth\.(uid|jwt|role)\(\)', 'fff', 'g'
        ) as sentinel
    from policies p
    where
        is_rls_active
        and is_permissive
        -- Read side only: SELECT (and ALL, whose USING is the read filter)
        and command in ('SELECT', 'ALL')
        -- Only policies that apply to public / anon / authenticated (as 0024 does)
        and (
            role_oids = array[0::oid] -- public (all roles)
            or exists (
                select 1
                from unnest(role_oids) as r
                where r::regrole::text in ('anon', 'authenticated')
            )
        )
),
classified as (
    select
        c.*,
        -- strip the single outer paren pair Postgres always deparses around qual
        regexp_replace(regexp_replace(sentinel, '^\(', ''), '\)$', '') as stripped
    from candidates c
),
analyzed as (
    select
        c.*,
        -- collapse balanced (paren) groups (up to 6 levels) so only the
        -- top-level connective(s) remain -- distinguishes a top-level OR from an
        -- OR nested inside an AND (the gated, safe case).
        regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
            stripped,
            '\([^()]*\)', '', 'g'), '\([^()]*\)', '', 'g'), '\([^()]*\)', '', 'g'),
            '\([^()]*\)', '', 'g'), '\([^()]*\)', '', 'g'), '\([^()]*\)', '', 'g'
        ) as core
    from classified c
)
select
    'rls_policy_null_auth_disjunct' as name,
    'RLS Policy True When Auth Is Null' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects permissive RLS read policies whose USING clause has a top-level OR disjunct that is true when an auth function returns NULL (for example `auth.uid() IS NULL OR ...`). Such a policy admits every row for any session where that function is NULL, which is almost always an inverted-logic mistake rather than intended access.' as description,
    format(
        'Table `%s.%s` has a permissive policy `%s` for `%s` whose USING clause is unconditionally true when `auth.uid()` / `auth.jwt()` / `auth.role()` (or `current_setting(..., true)`) is NULL, so it exposes every row to those sessions (roles: %s). This is almost always a logic error -- the author likely intended `IS NOT NULL AND ...` or a scoped check. Remove the `IS NULL` disjunct or replace it with an explicit deny.',
        schema_name,
        table_name,
        policy_name,
        command,
        array_to_string(roles, ', ')
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0030_rls_policy_null_auth_disjunct' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', table_name,
        'type', 'table',
        'policy_name', policy_name,
        'command', command,
        'roles', roles,
        'qual', qual
    ) as metadata,
    format(
        'rls_policy_null_auth_disjunct_%s_%s_%s',
        schema_name,
        table_name,
        policy_name
    ) as cache_key
from
    analyzed
where
    -- top-level connective is OR (not a gated AND) ...
    (core ~ 'or' and core !~ 'and')
    -- ... and one top-level disjunct is exactly the nullable auth null-check
    and stripped ~ '(^|or)\(xnullchkx\)($|or)'
order by
    schema_name,
    table_name,
    policy_name;
