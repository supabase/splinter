
Level: INFO

### Impact

Unused index found

#### Why it matters

This index is never used by any query but still slows down every insert, update, and delete on the table.

### Rationale

Unused indexes in a database are a silent performance issue. While indexes are important for speeding up search queries, every index also adds overhead to the database. This overhead occurs because the database must update each index whenever data in the indexed table are inserted, updated, or deleted. If an index is never used by your queries, it burdens the database with unnecessary work, which can slow down write operations and consume additional storage space.

### What is an Index?

An index in a database is similar to an index in a book. It allows the database to find data without scanning the entire table. An index is created on a column or a set of columns in a table. Queries that search or sort data based on these columns can find data more quickly and efficiently by referring the index instead of each row in the table.

### What are Unused Indexes

Unused indexes are indexes that have not been accessed by any query execution plans. This might occur if indexes were created proactively to support potential future query patterns or if application usage patterns change after a schema migration.

### How to Resolve

Before deleting an index, it's important to confirm that the index is genuinely unused and was unintentionally created:

- Consider future usage patterns. An index might be unused now but could be critical for upcoming features or during specific times of the year.
- Test the impact of removing the index in a development or staging environment to ensure that performance or query plans are not adversely affected.

To remove an unused index, use the `drop index` statement:

```sql
drop index <schema_name>.<index_name>;
```

Replacing `schema_name` and `index_name` with the actual names from your database.
