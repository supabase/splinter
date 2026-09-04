**Level:** WARN (`unreserved`) or ERROR (`lost`). See Rationale below.

**Summary:** Detects replication slots that are inactive and either retaining WAL beyond `max_slot_wal_keep_size` or already invalidated.

**Ramification:** A replication slot with no active consumer keeps every WAL segment since its `restart_lsn` on disk indefinitely; left unattended, this can fill the primary's disk and cause an outage. If retained WAL grows past `max_slot_wal_keep_size` before the consumer catches up, Postgres invalidates the slot instead — at that point the disk risk is gone, but the slot itself is unrecoverable and replication for that consumer is permanently broken.

---

### Rationale

Postgres will never recycle WAL a replication slot still needs, even if nothing is reading from that slot anymore. This is normal and required for the slot to still be useful to a consumer that reconnects, but if the consumer (a read replica, a logical replication client, a CDC tool) is gone for good, the slot just accumulates WAL forever.

Postgres itself tracks how close a slot is to actually causing harm via `pg_replication_slots.wal_status`:

- `reserved`: normal, claimed WAL files are within `max_wal_size`.
- `extended`: `max_wal_size` is exceeded but the files are still retained (by the slot or by `wal_keep_size`). This is benign and can happen on perfectly healthy, currently-active slots (e.g. during a burst of write traffic); it does not by itself indicate a problem.
- `unreserved`: the slot no longer retains its required WAL and some of it is due to be removed at the next checkpoint. This is what actually happens once retained WAL exceeds `max_slot_wal_keep_size`, and it's still recoverable (can return to `reserved`/`extended` if the consumer catches up before the next checkpoint).
- `lost`: the slot has been invalidated (usually because its required WAL is already gone, though Postgres can invalidate a slot for other reasons too) and it can no longer be used to resume replication.

This lint fires on `unreserved` or `lost`, not merely on `active = false`. A slot that's briefly inactive (e.g. its replica restarting) but still `reserved` (or even `extended`) is not yet a problem.

This lint relies on `max_slot_wal_keep_size` being set to a finite value. Supabase's managed Postgres always sets one. On a self-hosted instance left at Postgres's own default (`max_slot_wal_keep_size = -1`, meaning "never invalidate for size"), an abandoned slot can stay `extended` and accumulate WAL indefinitely without ever reaching `unreserved`, so this lint will not catch it. Set `max_slot_wal_keep_size` to a finite value to get this protection.

### How to Resolve

**Option 1: Drop the slot if its consumer is gone for good**

Only do this for a slot you created yourself. A slot named `ip_<x>_<x>_<x>_<x>` (a read replica's IP) or prefixed `supabase_realtime_*` is owned by the platform (a read replica or Realtime), not by you. Dropping it does not fix anything and can break replication or realtime delivery outright. Remove the read replica from the dashboard, or contact support, instead of dropping a platform-managed slot directly. New platform features can introduce other reserved naming patterns over time — if a slot's name doesn't obviously trace back to something you created yourself, contact support before dropping it.

```sql
select pg_drop_replication_slot('<slot_name>');
```

A logical slot must be dropped from the database it was created in, not from `postgres` or any other database in the cluster — the lint's `database` metadata field names that database.

**Option 2: If the slot is `unreserved` and a consumer is expected to reconnect, investigate the disconnect**

Check why the replica/consumer isn't connecting (network issue, instance down, credentials) and monitor disk usage on the primary in the meantime. Once it reconnects and catches up before the next checkpoint, `wal_status` returns to `reserved` on its own.

A `lost` slot has already been invalidated and cannot recover this way — Postgres will refuse to resume replication from it. Drop it (Option 1, unless it is platform-managed) and have the consumer re-establish a fresh slot instead of waiting for it to reconnect.

### Example

Given a physical replication slot whose replica was deleted recently enough that retained WAL has exceeded `max_slot_wal_keep_size` but the next checkpoint hasn't run yet:

```sql
select slot_name, active, wal_status from pg_replication_slots;
--      slot_name      | active | wal_status
-- ---------------------+--------+------------
--  replica_abandoned   | f      | unreserved
```

Fix:

```sql
select pg_drop_replication_slot('replica_abandoned');
```

### False Positives

A slot that is `active = false` but still `wal_status = 'reserved'` or `'extended'` will not fire. This covers a replica restarting, being briefly taken offline for maintenance, or a currently-healthy slot that's simply using more than `max_wal_size` right now, without generating noise. If this lint fires, the slot has already exceeded `max_slot_wal_keep_size` (or been invalidated entirely).
