create view "0001_unindexed_foreign_keys" as

select
    'unindexed_foreign_key' as name,
    'WARN' as level,
    'INTERNAL' as facing,
    'Foreign keys without indexes can degrade performance on joins.' as description,
    format(
		'The foreign key on table %I.%I involving columns (%s) is not indexed.',
		ns.nspname,
		cl.relname,
		string_agg(a.attname, ', ' order by a.attnum)
	) as detail,
    format(
		'create index on %I.%I(%s);',
		ns.nspname,
		cl.relname,
		string_agg(a.attname, ', ' order by a.attnum)
	) as remediation,
    '{}'::jsonb as metadata,
    format(
		'unindexed_foreign_key_%s_%s_%s',
		ns.nspname,
		cl.relname,
		string_agg(a.attname, '_' order by a.attnum)
	) as cache_key
from
    pg_constraint ct
    join pg_class cl
        on ct.conrelid = cl.oid
    join pg_namespace ns
        on cl.relnamespace = ns.oid
    join pg_attribute a
        on a.attrelid = cl.oid
        and a.attnum = any(ct.conkey)
    left join pg_index ix
        on ix.indrelid = ct.conrelid
    left join lateral (
        select array_agg(i) as indkeys
        from unnest(ix.indkey) with ordinality as u(i, ord)
    ) ix_keys on true
    left join pg_depend d
        on d.refobjid = cl.oid
        and d.deptype = 'e'
    left join pg_extension e
        on e.oid = d.objid
where
    ct.contype = 'f' -- foreign key constraints
    and ns.nspname not in ('pg_catalog', 'information_schema', 'auth', 'storage', 'vault', 'extensions')
    and e.oid is null -- exclude tables that are dependencies of extensions
    and (ix.indrelid is null or not (ct.conkey <@ ix_keys.indkeys))
group by
    ns.nspname,
    cl.relname,
    ct.oid
having
    bool_or(ix.indrelid is null) -- check if there's no index covering all columns of the foreign key;

