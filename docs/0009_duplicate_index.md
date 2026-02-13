
Level: WARN

### Impact

Duplicate index found

#### Why it matters

Identical indexes on the same table waste storage and slow down writes with no performance benefit.

### Rationale

Each index in a Postgres database adds overhead. This overhead occurs because the database must update each index whenever data in the indexed table are inserted, updated, or deleted. If two or more indexes are exact duplicates in their composition, the database incurs additional write overhead for no performance benefit.

### What is an Index?

An index in a database is similar to an index in a book. It allows the database to find data without scanning the entire table. An index is created on a column or a set of columns in a table. Queries that search or sort data based on these columns can find data more quickly and efficiently by referring the index instead of each row in the table.

### How to Resolve

When a table contains a duplicate index, drop instances of the index until only one remains.

For example, if the table `public.blog` has duplicate indexes `public.ix_id_1` and `public.ix_id_2` drop one using:

```sql
drop index public.ix_id_2;
```
