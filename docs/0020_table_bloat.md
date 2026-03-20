Level: WARN

### Rationale
In PostgreSQL, bloat occurs when tables contain extra, unused space due to deleted or updated rows. PostgreSQL doesn’t immediately reclaim the space used by these rows but instead marks it as reusable for future operations. Over time, if this space isn’t efficiently reused, the table becomes bloated, meaning it takes up more storage than necessary, slowing down database performance and increasing I/O overhead.

### What Causes Bloat?

Updates: When a row is updated, PostgreSQL creates a new version of the row, leaving the old version in the table as "dead space."
Deletes: Deleting rows leaves behind empty space that’s not automatically removed.
Table Design: Frequent changes to large tables with many columns or high variability in row size can lead to fragmentation.

PostgreSQL’s autovacuum process is designed to clean up these "dead tuples" and prevent excessive bloat. It works in the background to reclaim space and make it available for future use. However, autovacuum may not always keep up with bloat in certain situations, such as:

- Large or high-traffic tables with frequent updates/deletes.
- Inefficient vacuum settings in your database configuration.
- Tables requiring a more aggressive maintenance operation (e.g., vacuum full or cluster).

Excessive table bloat increases the size of your database on disk and slows down operations like reads, writes, and sequential scans. Left unresolved, it can cause noticeable degradation in application performance and higher costs for storage and computing resources.

If this lint repeatedly flags the same table for high bloat, it indicates an issue with your database's maintenance processes. Possible causes include:

- Autovacuum not running frequently enough.
- Maintenance operations being blocked or ineffective.
- Application-level behavior (e.g., frequent updates or deletes) creating excessive dead tuples.

In such cases, you should reach out to Supabase Support for assistance in diagnosing and resolving the underlying problem. They can help you tune autovacuum settings, optimize table design, or recommend appropriate maintenance strategies.

### How to Resolve

Vacuuming a table repacks it to remove fragmentation. However, be cautious when running `vacuum full` on large tables (>300k rows) in a production environment because vacuum full locks the table, blocking all other accesses until it finishes.
For large and heavily used tables, this can lead to significant downtime or performance stalls.

For very large tables a less intrusive alternative might be using [pg_repack](https://supabase.com/docs/guides/database/extensions/pg_repack).

Example of running vacuum full:

```sql
vacuum full public.some_table;
```

Important Note:

If vacuum full is not an option (due to locking concerns), consider plain vacuum (with or without analyze) or tools like [pg_repack](https://supabase.com/docs/guides/database/extensions/pg_repack).
Always test in a staging environment if you are unsure about the impact on live traffic.
You can verify your maintenance steps by checking the size of the table before and after vacuuming:

```sql
-- size before
select pg_size_pretty(pg_table_size('public.some_table'));

-- run vacuum or other maintenance

-- size after
select pg_size_pretty(pg_table_size('public.some_table'));
```

If your maintenance was successful, you should see a noticeable decrease in table size and improved query performance.