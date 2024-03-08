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
        polrelid::regclass table_,
        pc.relrowsecurity is_rls_active,
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
        pg_policy pa
        join pg_class pc
            on pa.polrelid = pc.oid
        join pg_namespace nsp
            on pc.relnamespace = nsp.oid
        join pg_policies pb
            on pc.relname = pb.tablename
            and nsp.nspname = pb.schemaname
            and pa.polname = pb.policyname
)
select
    'auth_rls_initplan' as name,
    'WARN' as level,
    'EXTERNAL' as facing,
    'Detects if calls to auth.<function>() in RLS policies are being unnecessarily re-evaluated for each row' as description,
    format(
        'Table "%s" has a row level security policy "%s" that re-evaluates an auth.<function>() for each row. This produces suboptimal query performance at scale. Resolve the issue by replacing "auth.<function>()" with "(select auth.<function>())". See https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select for more.',
        table_,
        policy_name
    ) as detail,
    null as remediation,
    null as metadata,
    format('auth_rls_init_plan_%s_%s', table_, policy_name) as cache_key
from
    policies
where
    is_rls_active
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
