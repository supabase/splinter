
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

**Option 1: Drop and recreate concurrently**

```sql
drop index concurrently if exists public.idx_orders_customer_id;

create index concurrently idx_orders_customer_id
on public.orders (customer_id);
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

Fix by dropping and rebuilding it:

```sql
drop index concurrently idx_orders_order_number;

create unique index concurrently idx_orders_order_number
on public.orders (order_number);
```

### False Positives

None expected — a valid, functioning index will never have `indisvalid = false`. If this lint fires, the index genuinely needs to be dropped or rebuilt.
