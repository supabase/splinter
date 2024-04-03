create view lint."0001_unindexed_foreign_keys" as

with foreign_keys as (
    select
        cl.relnamespace::regnamespace as schema_,
        cl.oid::regclass as table_,
        ct.conname as fkey_name,
        ct.conkey col_attnums
    from
        pg_catalog.pg_constraint ct
        join pg_catalog.pg_class cl -- fkey owning table
            on ct.conrelid = cl.oid
        left join pg_catalog.pg_depend d
            on d.objid = cl.oid
            and d.deptype = 'e'
    where
        ct.contype = 'f' -- foreign key constraints
        and d.objid is null -- exclude tables that are dependencies of extensions
        and cl.relnamespace::regnamespace::text not in (
            'pg_catalog', 'information_schema', 'auth', 'storage', 'vault', 'extensions'
        )
),
index_ as (
    select
        indrelid::regclass as table_,
        indexrelid::regclass as index_,
        string_to_array(indkey::text, ' ')::smallint[] as col_attnums
    from
        pg_catalog.pg_index
    where
        indisvalid
)
select
    'unindexed_foreign_keys' as name,
    'INFO' as level,
    'EXTERNAL' as facing,
    'Identifies foreign key constraints without a covering index, which can impact database performance.' as description,
    format(
        'Table \`%s.%s\` has a foreign key \`%s\` without a covering index. This can lead to suboptimal query performance.',
        fk.schema_,
        fk.table_,
        fk.table_,
        fk.fkey_name
    ) as detail,
    'https://supabase.github.io/splinter/0001_unindexed_foreign_keys' as remediation,
    jsonb_build_object(
        'schema', fk.schema_,
        'name', fk.table_,
        'type', 'table',
        'fkey_name', fk.fkey_name,
        'fkey_columns', fk.col_attnums
    ) as metadata,
    format('unindexed_foreign_keys_%s_%s_%s', fk.schema_, fk.table_, fk.fkey_name) as cache_key
from
    foreign_keys fk
    left join index_ idx
        on fk.table_ = idx.table_
        and fk.col_attnums = idx.col_attnums
where
    idx.index_ is null
order by
    fk.table_,
    fk.fkey_name;
