create view lint."0010_security_definer_view" as

select
    'security_definer_view' as name,
    'WARN' as level,
    'EXTERNAL' as facing,
    'Detects views that are SECURITY DEFINER meaning that they ignore row level security (RLS) policies.' as description,
    format(
        'View \`%s.%s\` is SECURITY DEFINER',
        n.nspname,
        c.relname
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view' as remediation,
    jsonb_build_object(
        'schema', n.nspname,
        'name', c.relname,
        'type', 'view'
    ) as metadata,
    format(
        'security_definer_view_%s_%s',
        n.nspname,
        c.relname
    ) as cache_key
from
    pg_catalog.pg_class c
    join pg_catalog.pg_namespace n
        on n.oid = c.relnamespace
    left join pg_catalog.pg_depend dep
        on c.oid = dep.objid
        and dep.deptype = 'e'
where
    c.relkind = 'v'
    and n.nspname = 'public'
    and dep.objid is null -- exclude views owned by extensions
	and not (
		lower(coalesce(c.reloptions::text,'{}'))::text[]
		&& array[
			'security_invoker=1',
			'security_invoker=true',
			'security_invoker=yes',
			'security_invoker=on'
		]
	);
