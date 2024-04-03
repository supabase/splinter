create view lint."0012_auth_allow_anonymous_sign_ins" as

with recursive role_members as (
    select
        roleid,
        member
    from pg_catalog.pg_auth_members
    where roleid = (select oid from pg_roles where rolname = 'authenticated')
    union
    select
        am.roleid,
        am.member
    from pg_catalog.pg_auth_members as am
    inner join role_members as rm on am.roleid = rm.member
),

member_names as (
    select r.rolname from pg_roles as r
    inner join role_members as m on r.oid = m.member
)

select
    'auth_allow_anonymous_sign_ins' as name,
    'INFO' as level,
    'EXTERNAL' as facing,
    'Detects row level security (RLS) policies that allow access to anonymous users.' as description,
    'https://supabase.github.io/splinter/0012_auth_allow_anonymous_sign_ins' as remediation,
    format(
        'Table \`%s.%s\` has policies enforced on roles that allow access to anonymous users. Policies include \`%s\`',
        n.nspname,
        c.relname,
        array_agg(p.policyname order by p.policyname)
    ) as detail,
    jsonb_build_object(
        'schema', n.nspname,
        'name', c.relname,
        'type', 'table'
    ) as metadata,
    format(
        'auth_allow_anonymous_sign_ins_%s_%s',
        n.nspname,
        c.relname
    ) as cache_key
from pg_catalog.pg_policies as p
inner join pg_catalog.pg_class as c on p.tablename = c.relname
inner join pg_catalog.pg_namespace as n on c.relnamespace = n.oid
where
    (
        p.roles = array['public'::name] -- public roles 
        or p.roles = array['authenticated'::name] -- authenticated roles 
        or exists (
            select rolname from member_names where rolname = any(roles)
        ) -- roles that are members of authenticated
    )
    and replace(p.qual, ' ', '') !~ 'auth\.jwt\(\)->>''is_anonymous''::text'
group by n.nspname, c.relname
