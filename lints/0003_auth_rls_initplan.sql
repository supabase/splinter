/*
Usage of auth.uid(), auth.role() ... are common in RLS policies.

A naive policy like

    create policy "rls_test_select" on test_table
    to authenticated
    using ( auth.uid() = user_id );

will re-evaluate the auth.uid() function for every row. That can result in 100s of times slower performance
https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

To resolve that issue, the function calls can be wrapped like "(select auth.uid())" which causes the value to
be executed exactly 1 time per query

For example:

    create policy "rls_test_select" on test_table
    to authenticated
    using ( (select auth.uid()) = user_id );

NOTE:
    This lint requires search_path = '' or 'auth' not in search_path;
    because qual and with_check are dependent on search_path to determine if function calls include the "auth" schema
*/


create view lint."0003_auth_rls_initplan" as

with policies as (
    select
        nsp.nspname as schema_name,
        pb.tablename as table_name,
        pc.relrowsecurity as is_rls_active,
        polname as policy_name,
        polpermissive as is_permissive, -- if not, then restrictive
        (select array_agg(r::regrole) from unnest(polroles) as x(r)) as roles,
        case polcmd
            when 'r' then 'SELECT'
            when 'a' then 'INSERT'
            when 'w' then 'UPDATE'
            when 'd' then 'DELETE'
            when '*' then 'ALL'
        end as command,
        qual,
        with_check
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
)
select
    'auth_rls_initplan' as name,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['PERFORMANCE'] as categories,
    'Detects if calls to \`auth.<function>()\` in RLS policies are being unnecessarily re-evaluated for each row' as description,
    format(
        'Table \`%s.%s\` has a row level security policy \`%s\` that re-evaluates an auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing \`auth.<function>()\` with \`(select auth.<function>())\`. See [docs](https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select) for more info.',
        schema_name,
        table_name,
        policy_name
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', table_name,
        'type', 'table'
    ) as metadata,
    format('auth_rls_init_plan_%s_%s_%s', schema_name, table_name, policy_name) as cache_key
from
    policies
where
    is_rls_active
    and schema_name not in (
        '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'pgtle', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
    )
    and (
        (
            -- Example: auth.uid()
            qual  ~ '(auth)\.(uid|jwt|role|email)\(\)'
            -- Example: select auth.uid()
            and lower(qual) !~ 'select\s+(auth)\.(uid|jwt|role|email)\(\)'
        )
        or
        (
            -- Example: auth.uid()
            with_check  ~ '(auth)\.(uid|jwt|role|email)\(\)'
            -- Example: select auth.uid()
            and lower(with_check) !~ 'select\s+(auth)\.(uid|jwt|role|email)\(\)'
        )
    );
