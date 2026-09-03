-- Unlike other lint tests, this file cannot use begin/savepoint/rollback: replication slots are non-transactional (they survive a rollback) and ALTER SYSTEM is rejected inside a transaction block, so every statement here autocommits individually and cleanup is explicit instead.
set search_path = '';

-- Converge to a clean starting state instead of trusting the tail cleanup below. bin/installcheck initdb's a fresh cluster per run, so this has no effect there, but it makes the file safe to re-run by hand (psql -f) against a persistent dev cluster without a stray splinter_test_* slot or non-default GUC from a prior manual run causing a confusing failure.
do $$
declare
    stray record;
begin
    for stray in select slot_name from pg_catalog.pg_replication_slots where slot_name like 'splinter_test_%' loop
        perform pg_catalog.pg_drop_replication_slot(stray.slot_name);
    end loop;
end $$;
alter system reset max_wal_size;
alter system reset max_slot_wal_keep_size;
-- pins the checkpointer to explicit `checkpoint;` calls below; the default 300s timeout could otherwise fire mid-fixture on a slow runner and desync the WARN/ERROR assertions.
alter system set checkpoint_timeout = '1h';
select pg_catalog.pg_reload_conf();

-- pg_switch_wal() is a no-op at a segment boundary, so each iteration writes one trivial WAL record first to move off it before switching again; 10 iterations assumes the default 16MB wal_segment_size.
create function pg_temp.advance_wal() returns void language plpgsql as $fn$
begin
    for i in 1..10 loop
        perform pg_catalog.pg_logical_emit_message(false, 'splinter_test', 'advance');
        perform pg_catalog.pg_switch_wal();
    end loop;
end
$fn$;

-- BASELINE: 0 issues, no slots exist. None of the fixtures below exercise `active = true`: pg_regress has no easy way to hold open a real walsender connection, so the view's `active = false` predicate itself is untested here.
select * from lint."0030_unused_replication_slot";

-- NEGATIVE EXAMPLE: a freshly created slot (LSN reserved, as a real replica connection would) is wal_status='reserved' while inactive, e.g. a replica that just restarted, and must NOT fire.
do $$ begin perform pg_catalog.pg_create_physical_replication_slot('splinter_test_negative_slot', true); end $$;
select name, detail, cache_key from lint."0030_unused_replication_slot";  -- expect 0 rows
select pg_catalog.pg_drop_replication_slot('splinter_test_negative_slot');

-- NEGATIVE EXAMPLE (logical slot): the same reserved/inactive guarantee applies to logical slots, not just physical
do $$ begin perform pg_catalog.pg_create_logical_replication_slot('splinter_test_negative_logical_slot', 'test_decoding'); end $$;
select name, detail, cache_key from lint."0030_unused_replication_slot";  -- expect 0 rows
select pg_catalog.pg_drop_replication_slot('splinter_test_negative_logical_slot');

-- NEGATIVE EXAMPLE (extended): max_wal_size exceeded but max_slot_wal_keep_size left at its default (disabled), so the slot is 'extended', not 'unreserved', and must NOT fire
do $$ begin perform pg_catalog.pg_create_physical_replication_slot('splinter_test_extended_slot', true); end $$;
alter system set max_wal_size = '2MB';
select pg_catalog.pg_reload_conf();
do $$ begin perform pg_temp.advance_wal(); end $$;
select slot_name, wal_status from pg_catalog.pg_replication_slots where slot_name = 'splinter_test_extended_slot';  -- confirm wal_status is actually 'extended'
select name, detail, cache_key from lint."0030_unused_replication_slot";  -- expect 0 rows
select pg_catalog.pg_drop_replication_slot('splinter_test_extended_slot');
alter system reset max_wal_size;
select pg_catalog.pg_reload_conf();
-- drain any checkpoint still pending from the WAL burst above; otherwise it can land mid-way through the positive fixture below and invalidate the slot before the 'unreserved' assertion runs.
checkpoint;

-- POSITIVE EXAMPLE (physical): shrink max_slot_wal_keep_size and generate enough WAL past it so the slot's retained WAL exceeds the limit.
do $$ begin perform pg_catalog.pg_create_physical_replication_slot('splinter_test_positive_slot', true); end $$;
alter system set max_slot_wal_keep_size = '1MB';
select pg_catalog.pg_reload_conf();
do $$ begin perform pg_temp.advance_wal(); end $$;

-- before any checkpoint runs, the slot has exceeded max_slot_wal_keep_size but hasn't been invalidated yet: wal_status is 'unreserved', level WARN
select name, level, detail, cache_key from lint."0030_unused_replication_slot";  -- expect 1 row, wal_status unreserved

-- a checkpoint is what actually invalidates an 'unreserved' slot once its required WAL is gone: wal_status becomes 'lost', level ERROR
checkpoint;
select name, level, detail, cache_key from lint."0030_unused_replication_slot";  -- expect 1 row, wal_status lost

-- dropping is the only way to stop WAL accumulation once the consumer is confirmed gone for good
select pg_catalog.pg_drop_replication_slot('splinter_test_positive_slot');
select * from lint."0030_unused_replication_slot";  -- expect 0 rows

-- POSITIVE EXAMPLE (logical): same escalation as the physical case, but also proves the entity/plugin metadata Studio needs for logical slots is actually populated.
do $$ begin perform pg_catalog.pg_create_logical_replication_slot('splinter_test_positive_logical_slot', 'test_decoding'); end $$;
alter system set max_slot_wal_keep_size = '1MB';
select pg_catalog.pg_reload_conf();
do $$ begin perform pg_temp.advance_wal(); end $$;
select name, level, metadata ->> 'entity' as entity, metadata ->> 'plugin' as plugin, metadata ->> 'database' as database, cache_key from lint."0030_unused_replication_slot";  -- expect 1 row, wal_status unreserved
checkpoint;
select name, level, metadata ->> 'entity' as entity, metadata ->> 'plugin' as plugin, metadata ->> 'database' as database, cache_key from lint."0030_unused_replication_slot";  -- expect 1 row, wal_status lost
select pg_catalog.pg_drop_replication_slot('splinter_test_positive_logical_slot');
select * from lint."0030_unused_replication_slot";  -- expect 0 rows

alter system reset max_slot_wal_keep_size;
alter system reset checkpoint_timeout;
select pg_catalog.pg_reload_conf();
