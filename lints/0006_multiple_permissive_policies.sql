create view lint."0006_multiple_permissive_policies" as

select
    'multiple_permissive_policies' as name,
    'WARN' as level,
    'EXTERNAL' as facing,
    'Detects if multiple permissive row level security policies are present on a table for the same `role` and `action` (e.g. insert). Multiple permissive policies are suboptimal for performance as each policy must be executed for every relevant query.' as description,
    format(
        'Table \`%s.%s\` has multiple permissive policies for role \`%s\` for action \`%s\`. Policies include \`%s\`',
        n.nspname,
        c.relname,
        r.rolname,
        act.cmd,
        array_agg(p.polname order by p.polname)
    ) as detail,
    null as remediation,
    jsonb_build_object(
        'schema', n.nspname,
        'name', c.relname,
        'type', 'table'
    ) as metadata,
    format(
        'multiple_permissive_policies_%s_%s_%s_%s',
        n.nspname,
        c.relname,
        r.rolname,
        act.cmd
    ) as cache_key
from
    pg_catalog.pg_policy p
    join pg_catalog.pg_class c on p.polrelid = c.oid
    join pg_catalog.pg_namespace n on c.relnamespace = n.oid
    join pg_catalog.pg_roles r
        on p.polroles @> array[r.oid]
        or p.polroles = array[0::oid],
    lateral (
        select x.cmd
        from unnest((
            select
                case p.polcmd
                    when 'r' then array['SELECT']
                    when 'a' then array['INSERT']
                    when 'w' then array['UPDATE']
                    when 'd' then array['DELETE']
                    when '*' then array['SELECT', 'INSERT', 'UPDATE', 'DELETE']
                    else array['ERROR']
                end as actions
        )) x(cmd)
    ) act(cmd)
where
    c.relkind = 'r' -- regular tables
    and n.nspname not in (
        'pg_catalog', 'information_schema', 'auth', 'storage', 'vault', 'pgsodium'
    )
    and r.rolname not like 'pg_%'
    and r.rolname not like 'supabase%admin'
    and not r.rolbypassrls
group by
    n.nspname,
    c.relname,
    r.rolname,
    act.cmd
having
    count(1) > 1;
