**Level:** INFO

**Summary:** Detects tables where `autovacuum_enabled=false` has been set as a storage parameter.

**Ramification:** Dead tuples accumulate without bound, causing table bloat that degrades query performance and increases storage costs. The effect compounds after any UPDATE or DELETE workload.

---

### Rationale

PostgreSQL autovacuum reclaims space from dead tuples left by UPDATE and DELETE operations. Disabling it at the table level (`ALTER TABLE t SET (autovacuum_enabled = false)`) prevents this cleanup entirely for that table, regardless of the cluster-level autovacuum setting.

### How to Resolve

**Re-enable autovacuum and reclaim existing dead tuples immediately:**

```sql
ALTER TABLE public.orders RESET (autovacuum_enabled);
VACUUM ANALYZE public.orders;
```

### False Positives

This lint may fire when the setting is intentional:

- **Read-only archive tables** — no UPDATEs or DELETEs means no dead tuples; autovacuum has nothing to do.
- **Bulk-load staging tables** — autovacuum is temporarily disabled to avoid I/O contention during ETL; should be re-enabled after the load completes.
- **Manual vacuum schedules** — tables vacuumed explicitly via `pg_cron` or another scheduler; autovacuum is disabled to avoid conflicts with the scheduled job.

In these cases the lint can be safely ignored, but verify the table is not accumulating dead tuples via `pg_stat_user_tables.n_dead_tup`.
