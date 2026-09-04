create view lint."0031_unused_replication_slot" as

select
    'unused_replication_slot' as name,
    'Unused Replication Slot' as title,
    case when prs.wal_status = 'lost' then 'ERROR' else 'WARN' end as level,
    'EXTERNAL' as facing,
    array['PERFORMANCE'] as categories,
    'Detects replication slots that are inactive and either retaining WAL beyond max_slot_wal_keep_size (risking disk bloat) or already invalidated (unrecoverable, breaking replication for that consumer).' as description,
    format(
        'Replication slot `%s` is inactive and its wal_status is `%s`',
        prs.slot_name,
        prs.wal_status
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0031_unused_replication_slot' as remediation,
    jsonb_build_object(
        -- Studio's getLintEntityString needs schema+name or entity to render anything, and slots have no schema, so entity is set to short-circuit straight to the slot name.
        'entity', prs.slot_name,
        'type', 'replication_slot',
        'slot_type', prs.slot_type,
        'wal_status', prs.wal_status,
        'plugin', prs.plugin,
        -- a logical slot's drop only succeeds when run against the database it was created in. physical slots have no database.
        'database', prs.database
    ) as metadata,
    format('unused_replication_slot_%s_%s', prs.slot_name, prs.wal_status) as cache_key
from
    pg_catalog.pg_replication_slots prs
where
    not prs.active
    -- 'reserved'/'extended' are still within retention limits, or a replica is reconnecting. Only 'unreserved' (limit already exceeded) and 'lost' (already invalidated) are worth flagging.
    and prs.wal_status in ('unreserved', 'lost')
order by
    prs.slot_name;
