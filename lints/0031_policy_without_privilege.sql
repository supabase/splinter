create view lint."0031_policy_without_privilege" as

-- Detects permissive RLS policies targeting anon/authenticated on tables where that
-- role lacks the matching table privilege. Privileges are checked before RLS, so
-- such a policy never applies and API requests fail with "permission denied".
with api_roles as (
    select
        r.oid as role_oid,
        r.rolname as role_name
    from
        pg_catalog.pg_roles r
    where
        r.rolname in ('anon', 'authenticated')
),
policies as (
    select
        n.nspname as schema_name,
        c.relname as table_name,
        c.oid as table_oid,
        p.polname as policy_name,
        p.polroles as role_oids,
        case p.polcmd
            when 'r' then 'SELECT'
            when 'a' then 'INSERT'
            when 'w' then 'UPDATE'
            when 'd' then 'DELETE'
            when '*' then 'ALL'
        end as command
    from
        pg_catalog.pg_policy p
        join pg_catalog.pg_class c
            on p.polrelid = c.oid
        join pg_catalog.pg_namespace n
            on c.relnamespace = n.oid
        left join pg_catalog.pg_depend dep
            on c.oid = dep.objid
            and dep.deptype = 'e'
            and dep.classid = 'pg_catalog.pg_class'::regclass
    where
        c.relkind = 'r' -- regular tables
        and c.relrowsecurity
        and p.polpermissive
        and n.nspname = any(array(select trim(unnest(string_to_array(coalesce(current_setting('pgrst.db_schemas', 't'), 'public'), ',')))))
        and n.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
        and dep.objid is null -- exclude tables owned by extensions
),
policy_roles as (
    -- Each API role the policy targets, along with whether that role holds the privilege
    select
        p.schema_name,
        p.table_name,
        p.policy_name,
        p.command,
        p.role_oids = array[0::oid] as targets_public,
        ar.role_name,
        case p.command
            -- has_any_column_privilege also accepts column-level grants
            when 'SELECT' then pg_catalog.has_any_column_privilege(ar.role_oid, p.table_oid, 'SELECT')
            when 'INSERT' then pg_catalog.has_any_column_privilege(ar.role_oid, p.table_oid, 'INSERT')
            when 'UPDATE' then pg_catalog.has_any_column_privilege(ar.role_oid, p.table_oid, 'UPDATE')
            when 'DELETE' then pg_catalog.has_table_privilege(ar.role_oid, p.table_oid, 'DELETE')
            -- A FOR ALL policy is effective as long as the role holds any of the four privileges
            when 'ALL' then pg_catalog.has_any_column_privilege(ar.role_oid, p.table_oid, 'SELECT, INSERT, UPDATE')
                or pg_catalog.has_table_privilege(ar.role_oid, p.table_oid, 'DELETE')
        end as has_privilege
    from
        policies p
        join api_roles ar
            on p.role_oids = array[0::oid] -- public (all roles)
            or ar.role_oid = any(p.role_oids)
),
ineffective_policies as (
    select
        schema_name,
        table_name,
        policy_name,
        command,
        array_agg(role_name order by role_name) filter (where not has_privilege) as roles
    from
        policy_roles
    group by
        schema_name,
        table_name,
        policy_name,
        command,
        targets_public
    having
        -- Explicitly targeted roles: flag if any of them lacks the privilege.
        -- Policies for public: flag only if no API role holds the privilege, since a
        -- policy for public is commonly meant for authenticated users only.
        case
            when targets_public then not bool_or(has_privilege)
            else not bool_and(has_privilege)
        end
)
select
    'policy_without_privilege' as name,
    'Policy Without Privilege' as title,
    'INFO' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects RLS policies for the anon or authenticated roles on tables where that role lacks the matching table privilege. Privileges are checked before RLS, so the policy has no effect until the privilege is granted.' as description,
    format(
        'Table `%s.%s` has RLS policy `%s` for `%s`, but %s %s no %s privilege on the table, so the policy has no effect.',
        schema_name,
        table_name,
        policy_name,
        command,
        array_to_string(roles, ' and '),
        case when cardinality(roles) > 1 then 'have' else 'has' end,
        case command
            when 'ALL' then 'SELECT, INSERT, UPDATE, or DELETE'
            else command
        end
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0031_policy_without_privilege' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', table_name,
        'type', 'table',
        'policy_name', policy_name,
        'command', command,
        'roles', roles
    ) as metadata,
    format(
        'policy_without_privilege_%s_%s_%s',
        schema_name,
        table_name,
        policy_name
    ) as cache_key
from
    ineffective_policies
order by
    schema_name,
    table_name,
    policy_name;
