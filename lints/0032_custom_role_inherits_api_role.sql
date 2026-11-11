create view lint."0032_custom_role_inherits_api_role" as

-- Detects custom roles that are members of the Data API roles `anon` or
-- `authenticated`.
--
-- Membership in a role normally means inheriting every privilege of that role
-- (unless the member is NOINHERIT). Anything granted to `anon` or
-- `authenticated` (table access, EXECUTE on functions, RLS policies written
-- `TO anon`) is silently available to the member, and a later `GRANT` to
-- either API role widens the member too. Platform roles that legitimately
-- hold these memberships are excluded: on a stock Supabase image the only
-- members are `authenticator` and `postgres`. Other `supabase_*` and built-in
-- `pg_*` roles are excluded as well.
--
-- Only direct memberships are listed. The finding is about the grant itself,
-- so no exposed-schema filter applies.
select
    'custom_role_inherits_api_role' as name,
    'Custom Role Inherits From API Role' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects custom roles that are members of `anon` or `authenticated`. Such a role inherits every privilege of the API role. Revoke the membership and grant the member only what it needs.' as description,
    format(
        'Role `%s` is a member of `%s` and inherits all of its privileges. Revoke the membership unless this is intentional.',
        member_name,
        granted_role
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0032_custom_role_inherits_api_role' as remediation,
    jsonb_build_object(
        'name', member_name,
        'type', 'role',
        'granted_role', granted_role
    ) as metadata,
    format(
        'custom_role_inherits_api_role_%s_%s',
        member_name,
        granted_role
    ) as cache_key
from
    (
        select
            m.rolname::text as member_name,
            g.rolname::text as granted_role
        from
            pg_catalog.pg_auth_members am
            join pg_catalog.pg_roles g
                on g.oid = am.roleid
            join pg_catalog.pg_roles m
                on m.oid = am.member
        where
            g.rolname in ('anon', 'authenticated')
            and m.rolname not in ('authenticator', 'postgres')
            and m.rolname not like 'supabase\_%'
            and m.rolname not like 'pg\_%'
    ) memberships
order by
    member_name,
    granted_role;
