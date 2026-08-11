
**Level:** WARN

**Summary:** Index is marked invalid and is never used by the query planner.

**Ramification:** The index still consumes disk space and is maintained (slowing writes) on every insert/update, but provides zero query benefit and, if it was meant to back a unique constraint, that constraint is not being enforced.

---

### Rationale

Postgres marks an index `invalid` (`pg_index.indisvalid = false`) when it is left in a partially built state, most commonly:

- `CREATE INDEX CONCURRENTLY` fails partway through (e.g. a conflicting row, a timeout, or the session was killed)
- `REINDEX CONCURRENTLY` fails partway through
- A crash occurred while `CREATE INDEX CONCURRENTLY` was running

An invalid index is never used by the planner, but Postgres does not automatically drop it. It sits on disk, still gets updated on every write to the underlying table, and does nothing useful in return.

### How to Resolve

**Option 1: Reindex concurrently**

```sql
reindex index concurrently public.idx_orders_customer_id;
```

This rebuilds and validates the index without blocking writes to the table.

Indexes backing exclusion constraints cannot be reindexed concurrently, and a plain `drop index` is rejected because the constraint requires the index. Only in that case, reindex non-concurrently. This blocks writes to the table and may take significant time on large tables, so run it in a maintenance window:

```sql
reindex index public.reservations_during_excl;
```

**Option 2: Investigate why it failed first**

If the original `CREATE INDEX CONCURRENTLY` failed due to a constraint violation (common for unique indexes), fix the underlying data before recreating the index, otherwise the rebuild will fail the same way.

### Example

Given this problematic configuration:

```sql
-- This fails partway through, e.g. due to a lock timeout or duplicate values
create unique index concurrently idx_orders_order_number
on public.orders (order_number);
```

The resulting index is left behind as invalid — still consuming space, still slowing down writes, enforcing nothing.

Fix by rebuilding it:

```sql
reindex index concurrently idx_orders_order_number;
```

### False Positives

1. Partitioned parent indexes can be marked as invalid even after the children have been repaired, see the [Postgres mailing list for more information](https://www.postgresql.org/message-id/CAGnOmWqi1D9ycBgUeOGf6mOCd2Dcf%3D6sKhbf4sHLs5xAcKVCMQ%40mail.gmail.com)
2. In progress indexes - an index that is still being built can show as invalid. To address this the lint only considers indexes where `indisready` is true and excludes builds reported in `pg_stat_progress_create_index`, but there may be edge cases
