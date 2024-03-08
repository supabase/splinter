create view lint."0002_auth_users_exposed" as

select
    'auth_users_exposed' as name,
    'WARN' as level,
    'EXTERNAL' as facing,
    'Detects if auth.users is exposed to anon or authenticated roles via a view or materialized view in the public schema, potentially compromising user data security.' as description,
    format(
        'View/Materialized View "%s" in the public schema may expose auth.users data to anon or authenticated roles.',
        c.relname
    ) as detail,
    'Review the view/materialized view definition to ensure it does not unintentionally expose sensitive user data. Apply proper role permissions and consider using row-level security to protect sensitive data.' as remediation,
    jsonb_build_object(
        'view_name', c.relname,
        'schema', 'public',
        'exposed_to', array_remove(array_agg(DISTINCT case when pg_catalog.has_table_privilege('anon', c.oid, 'SELECT') then 'anon' when pg_catalog.has_table_privilege('authenticated', c.oid, 'SELECT') then 'authenticated' end), null)
    ) as metadata,
    format('auth_users_exposed_%s', c.relname) as cache_key
from
    pg_depend d
    join pg_rewrite r
        on r.oid = d.objid
    join pg_class c
        on c.oid = r.ev_class
    join pg_namespace n
        on n.oid = c.relnamespace
where
    d.refobjid = 'auth.users'::regclass
    and d.deptype = 'n'
    and c.relkind in ('v', 'm') -- v for view, m for materialized view
    and n.nspname = 'public'
    and (
      pg_catalog.has_table_privilege('anon', c.oid, 'SELECT')
      or pg_catalog.has_table_privilege('authenticated', c.oid, 'SELECT')
    )
    -- Exclude self
    and c.relname <> '0002_auth_users_exposed'
group by
    c.relname, c.oid;
