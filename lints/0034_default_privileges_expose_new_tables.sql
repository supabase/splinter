create view lint."0034_default_privileges_expose_new_tables" as

-- Detects ALTER DEFAULT PRIVILEGES entries that grant table privileges
-- to `anon`, `authenticated` or `PUBLIC` in a schema exposed through
-- the Data API (or in every schema). Since October 30, 2026 new tables
-- are no longer exposed automatically: each one needs an explicit
-- GRANT. A default-privileges entry like this re-creates the old
-- behavior for every table its owner creates from now on, usually
-- added to silence the first 42501 "permission denied for table".
-- Nothing is exposed by it today; the next table created without
-- `enable row level security` is readable (and writable) with the
-- public anon key the moment it exists.
--
-- Default privileges owned by platform roles (supabase_*, pg_*) are
-- skipped: the project owner cannot alter them.
select
    'default_privileges_expose_new_tables' as name,
    'Default Privileges Expose New Tables' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects default privileges that grant every future table to the API roles, re-enabling automatic Data API exposure. Revoke them and grant each new table explicitly in the migration that creates it.' as description,
    format(
        'Default privileges make every table `%s` creates in %s accessible to %s.',
        owner_name,
        case when schema_name is null then 'any schema' else format('schema `%s`', schema_name) end,
        grants
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0034_default_privileges_expose_new_tables' as remediation,
    jsonb_build_object(
        'owner', owner_name,
        'schema', schema_name,
        'grants', grants,
        'type', 'default_privileges'
    ) as metadata,
    format(
        'default_privileges_expose_new_tables_%s_%s',
        owner_name,
        coalesce(schema_name, '*')
    ) as cache_key
from
    (
        select
            owner_name,
            schema_name,
            string_agg(grantee_name || ' (' || privileges || ')', ', ' order by grantee_name) as grants
        from
            (
                select
                    pg_catalog.pg_get_userbyid(d.defaclrole) as owner_name,
                    n.nspname as schema_name,
                    case when a.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(a.grantee) end as grantee_name,
                    string_agg(a.privilege_type, ', ' order by a.privilege_type) as privileges
                from
                    pg_catalog.pg_default_acl d
                    left join pg_catalog.pg_namespace n
                        on n.oid = d.defaclnamespace
                    cross join lateral pg_catalog.aclexplode(d.defaclacl) a
                where
                    d.defaclobjtype = 'r'
                    and (
                        a.grantee = 0
                        or pg_catalog.pg_get_userbyid(a.grantee) in ('anon', 'authenticated')
                    )
                    and (
                        d.defaclnamespace = 0
                        or n.nspname = any(array(select trim(unnest(string_to_array(coalesce(current_setting('pgrst.db_schemas', 't'), 'public'), ',')))))
                    )
                    and (
                        n.nspname is null
                        or n.nspname not in (
                            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
                        )
                    )
                    and pg_catalog.pg_get_userbyid(d.defaclrole) not like 'supabase\_%'
                    and pg_catalog.pg_get_userbyid(d.defaclrole) not like 'pg\_%'
                group by
                    1, 2, 3
            ) per_grantee
        group by
            owner_name,
            schema_name
    ) exposing_defaults
order by
    owner_name,
    schema_name nulls first;
