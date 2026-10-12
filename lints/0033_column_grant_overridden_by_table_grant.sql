create view lint."0033_column_grant_overridden_by_table_grant" as

-- Detects column-level privileges that have no effect because the same role
-- already holds the same privilege on the whole table.
--
-- Postgres checks table-level and column-level privileges separately and
-- allows the operation if either is held. A table-level SELECT therefore
-- covers every column, whatever column-level grants or revokes exist. A
-- project that grants `select (a, b)` to a role to expose only those columns,
-- while the role also holds table-level `select`, still exposes every column.
--
-- What the catalogue can and cannot show:
--   * Detectable: a role holds a column-level entry in pg_attribute.attacl
--     and the same privilege at table level. The column entry is redundant,
--     which is the footprint of a restriction that never took effect.
--   * Not detectable: a plain `REVOKE select (col) ... FROM role` against a
--     table-level grant. Postgres removes nothing and stores nothing, so no
--     trace remains in the catalogue.
-- The table-level check uses `has_table_privilege`, so privileges inherited
-- through role membership or granted to PUBLIC count. Only the Supabase API
-- roles `anon` and `authenticated` are examined.
with column_grants as (
    select
        a.attrelid,
        acl.grantee,
        acl.privilege_type,
        array_agg(a.attname::text order by a.attnum) as column_names
    from
        pg_catalog.pg_attribute a
        cross join lateral pg_catalog.aclexplode(a.attacl) acl
    where
        a.attnum > 0
        and not a.attisdropped
        and a.attacl is not null
        and acl.privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
    group by
        a.attrelid,
        acl.grantee,
        acl.privilege_type
),
findings as (
    select
        nsp.nspname as schema_name,
        cls.relname as table_name,
        r.rolname as role_name,
        cg.privilege_type,
        cg.column_names
    from
        column_grants cg
        join pg_catalog.pg_class cls
            on cls.oid = cg.attrelid
        join pg_catalog.pg_namespace nsp
            on nsp.oid = cls.relnamespace
        join pg_catalog.pg_roles r
            on r.oid = cg.grantee
    where
        cls.relkind in ('r', 'p', 'v', 'm', 'f')
        and r.rolname in ('anon', 'authenticated')
        and pg_catalog.has_table_privilege(r.rolname, cls.oid, cg.privilege_type)
        and nsp.nspname = any(array(select trim(unnest(string_to_array(coalesce(current_setting('pgrst.db_schemas', 't'), 'public'), ',')))))
        and nsp.nspname not in (
            '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config', '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
        )
        -- extension-owned tables are not the user's to change
        and not exists (
            select 1
            from pg_catalog.pg_depend d
            where d.classid = 'pg_catalog.pg_class'::pg_catalog.regclass
                and d.objid = cls.oid
                and d.deptype = 'e'
        )
)
select
    'column_grant_overridden_by_table_grant' as name,
    'Column Privilege Overridden By Table Privilege' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects column-level privileges for `anon` or `authenticated` that have no effect because the role also holds the same privilege on the whole table. Revoke the table-level privilege to make the column grant restrictive.' as description,
    format(
        'Role `%s` has table-level `%s` on `%s.%s`, so its column-level `%s` grant on (%s) does not restrict access. The role can use every column.',
        role_name,
        privilege_type,
        schema_name,
        table_name,
        privilege_type,
        array_to_string(column_names, ', ')
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0033_column_grant_overridden_by_table_grant' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', table_name,
        'type', 'table',
        'role', role_name,
        'privilege', privilege_type,
        'columns', column_names
    ) as metadata,
    format(
        'column_grant_overridden_by_table_grant_%s_%s_%s_%s',
        schema_name,
        table_name,
        role_name,
        privilege_type
    ) as cache_key
from
    findings
order by
    schema_name,
    table_name,
    role_name,
    privilege_type;
