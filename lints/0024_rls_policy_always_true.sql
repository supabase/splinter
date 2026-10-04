create view lint."0024_rls_policy_always_true" as

-- Detects RLS policies that are overly permissive (e.g., USING (true), USING (1=1))
-- These policies effectively disable row-level security while giving a false sense of security
with policies as (
    select
        nsp.nspname as schema_name,
        pb.tablename as table_name,
        pc.relrowsecurity as is_rls_active,
        pa.polname as policy_name,
        pa.polpermissive as is_permissive,
        pa.polroles as role_oids,
        (select array_agg(r::regrole::text) from unnest(pa.polroles) as x(r)) as roles,
        case pa.polcmd
            when 'r' then 'SELECT'
            when 'a' then 'INSERT'
            when 'w' then 'UPDATE'
            when 'd' then 'DELETE'
            when '*' then 'ALL'
        end as command,
        pb.qual,
        pb.with_check,
        -- Normalize expressions by removing whitespace and lowercasing, then check for always-true forms
        replace(replace(replace(lower(coalesce(pb.qual, '')), ' ', ''), E'\n', ''), E'\t', '')
            in ('true', '(true)', '1=1', '(1=1)') as qual_always_true,
        replace(replace(replace(lower(coalesce(pb.with_check, '')), ' ', ''), E'\n', ''), E'\t', '')
            in ('true', '(true)', '1=1', '(1=1)') as with_check_always_true,
        -- Policy name claims the policy is scoped to the row owner or a role. Bare words are not enough:
        -- in "Allow reading admin users" or "Public can view vehicle owners" the word describes the
        -- table's contents. Names that declare public, everyone or anyone access never count.
        (
            policy_name_words.words ~ any(array[
                ' (own|their) ',                    -- "Users can view their own posts", "select_own_posts"
                ' only (the )?owners? ',            -- "Only owners can read", "Readable by only the owner"
                ' for (the )?owners? ',             -- "Read access for the owner"
                ' owners? (can|only) ',             -- "Owners can view posts", "Owner only read"
                ' admins? (can|only|read|reads|view|views|see|sees|manage|manages|select|insert|update|delete) ',
                                                    -- "Admins can view orders", "Admin reads all activity", "admin_select_responses"
                ' only admins? ',                   -- "Visible to only admins"
                ' for admins? $',                   -- "Allow authenticated read for admin", but not "... for admin reports"
                ' service role '                    -- "Service role can read logs"
            ])
            and policy_name_words.words !~ ' (public|everyone|anyone) '
        ) as name_implies_scope
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
        -- Lowercased policy name with every non-alphanumeric run turned into one space and a space at each end,
        -- so the patterns above match whole words: "select_own_posts" matches " own ", "shown" does not
        cross join lateral (
            select ' ' || regexp_replace(lower(pa.polname), '[^a-z0-9]+', ' ', 'g') || ' ' as words
        ) as policy_name_words
    where
        pc.relkind = 'r' -- regular tables
        and nsp.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
),
permissive_patterns as (
    select
        p.*,
        -- Check for always-true USING clause patterns
        -- Note: SELECT with (true) is often intentional and documented, so we only flag UPDATE/DELETE,
        -- and SELECT only when the policy name says it is scoped to the row owner or a role
        case when (
            command in ('UPDATE', 'DELETE', 'ALL')
            and (
                qual_always_true
                -- Empty or null qual on permissive policy means allow all
                or (qual is null and is_permissive)
            )
        ) or (
            command = 'SELECT'
            and name_implies_scope
            and qual_always_true
        ) then true else false end as has_permissive_using,
        -- Check for always-true WITH CHECK clause patterns
        case when (
            with_check_always_true
            -- Empty with_check on INSERT means allow all (INSERT has no USING to fall back on)
            or (with_check is null and is_permissive and command = 'INSERT')
            -- Empty with_check on UPDATE/ALL with permissive USING means allow all writes
            or (with_check is null and is_permissive and command in ('UPDATE', 'ALL')
                and qual_always_true)
        ) then true else false end as has_permissive_with_check
    from
        policies p
    where
        -- Only check tables with RLS enabled (otherwise it's a different lint)
        is_rls_active
        -- Only check permissive policies (restrictive policies with true are less dangerous)
        and is_permissive
        -- Only flag policies that apply to anon or authenticated roles (or public/all roles)
        and (
            role_oids = array[0::oid] -- public (all roles)
            or exists (
                select 1
                from unnest(role_oids) as r
                where r::regrole::text in ('anon', 'authenticated')
            )
        )
)
select
    'rls_policy_always_true' as name,
    'RLS Policy Always True' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects RLS policies that use overly permissive expressions like \`USING (true)\` or \`WITH CHECK (true)\` for UPDATE, DELETE, or INSERT operations. SELECT policies with \`USING (true)\` are excluded as this pattern is often used deliberately for public read access, unless the policy name says it is limited to the row owner or a role.' as description,
    format(
        'Table `%s.%s` has an RLS policy `%s` for `%s` that allows unrestricted access%s. This effectively bypasses row-level security for %s.%s',
        schema_name,
        table_name,
        policy_name,
        command,
        case
            when has_permissive_using and has_permissive_with_check then ' (both USING and WITH CHECK are always true)'
            when has_permissive_using then ' (USING clause is always true)'
            when has_permissive_with_check then ' (WITH CHECK clause is always true)'
            else ''
        end,
        array_to_string(roles, ', '),
        -- Only when nothing in the policy checks the caller: every expression it has is always true.
        -- A missing USING only counts for INSERT, which has none.
        case
            when name_implies_scope
                and (qual_always_true or (qual is null and command = 'INSERT'))
                and (with_check is null or with_check_always_true)
                then ' The policy name suggests access is limited to the row owner or a specific role, but the policy does not check who the caller is.'
            else ''
        end
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0024_permissive_rls_policy' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', table_name,
        'type', 'table',
        'policy_name', policy_name,
        'command', command,
        'roles', roles,
        'qual', qual,
        'with_check', with_check,
        'permissive_using', has_permissive_using,
        'permissive_with_check', has_permissive_with_check
    ) as metadata,
    format(
        'rls_policy_always_true_%s_%s_%s',
        schema_name,
        table_name,
        policy_name
    ) as cache_key
from
    permissive_patterns
where
    has_permissive_using or has_permissive_with_check
order by
    schema_name,
    table_name,
    policy_name;
