create or replace view lint."0020_table_bloat" as

with bloat_data as (
    select
        c.oid as table_oid,
        n.oid as nsp_oid,
        n.nspname as schema_name,
        c.relname as table_name,
        -- compute pct bloat by comparing the estimated bytes to actual table bytes
        round(
            (
                (c.relpages * const.bs) - e.est_bytes
            ) * 100.0 / (c.relpages * const.bs)
        , 2) as pct_bloat,

        -- compute bloat in mb
        round(
            (
                (c.relpages * const.bs) - e.est_bytes
            ) / 1024.0 / 1024.0
        , 2) as bloat_mb

    from
        pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        -- cross join a small subquery to get constants (block size, row overhead, alignment)
        cross join (
            select
                current_setting('block_size')::numeric as bs, -- block size in bytes
                24 as hdr, -- estimated header size per row
                8 as ma    -- memory alignment
        ) const
        -- get the average column width for each table, ignoring null fraction
        left join (
            select
                schemaname,
                tablename,
                sum((1 - null_frac) * avg_width)::numeric as datawidth
            from pg_stats
            group by schemaname, tablename
        ) w on w.schemaname = n.nspname
           and w.tablename = c.relname

        -- use cross join lateral to calculate estimated table bytes for each row
        cross join lateral (
            select ceil(
                c.reltuples::numeric * (
                    coalesce(w.datawidth, 0)
                    + const.hdr + (const.hdr + 1) + const.ma
                    - (
                        case
                            when (coalesce(w.datawidth, 0) + const.hdr) % const.ma = 0
                            then const.ma
                            else (coalesce(w.datawidth, 0) + const.hdr) % const.ma
                        end
                    )
                ) / (const.bs - 20)
            ) * const.bs as est_bytes
        ) e

    -- filter out indexes, system schemas, and any tables with 0 pages
    where
        c.relkind = 'r'
        and n.nspname not in ('pg_catalog','information_schema')
        and c.relpages > 0
        -- ensure actual size is bigger than our estimate to count as bloat
        and (c.relpages * const.bs) > e.est_bytes
)
select
    'table_bloat' as name,
    'Table Bloat' as title,
    'INFO' as level,
    'EXTERNAL' as facing,
    array['PERFORMANCE'] as categories,
    'Detects if a table has excess bloat and may benefit from maintenance operations like vacuum full or cluster.' as description,
    format(
        'Table `%s`.`%s` has bloat > 50%%s percent bloat',
        bloat_data.schema_name,
        bloat_data.table_name,
        bloat_data.pct_bloat
    ) as detail,
    'Consider running vacuum full (WARNING: incurs downtime) and tweaking autovacuum settings to reduce bloat.' as remediation,
    jsonb_build_object(
        'schema', bloat_data.schema_name,
        'name', bloat_data.table_name,
        'type', 'table'
    ) as metadata,
    format(
        'table_bloat_%s_%s',
        bloat_data.schema_name,
        bloat_data.table_name
    ) as cache_key
from
    bloat_data
order by
    schema_name,
    table_name;
