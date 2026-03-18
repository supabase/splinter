
**Level:** INFO

**Summary:** Table has no primary key

**Ramification:** Without a primary key, rows can't be uniquely identified, which can cause data issues and slower queries.

---

### Rationale

Tables in a relational database should ideally have a key that uniquely identifies a row within that table. Tables lacking a primary key is often considered poor design, as it can lead to data anomalies, complicate data relationships, and degrade query performance.

### What is a Primary Key?

A primary key is a single column or a set of columns that uniquely identifies each row in a table.

Primary keys are important because they enable:

1. **Uniqueness and Integrity**: Ensures that each row in the table is unique and identifiable.
2. **Performance**: The database automatically creates an index for the primary key, improving query performance when retrieving or manipulating data based on the primary key.
3. **Relationships**: Unique keys, like primary keys, are a prerequisite for defining foreign keys in other tables, which are critical for relational database design and efficient joins.

### How to Resolve

For a table that lacks a primary key, the resolution involves identifying a column (or a set of columns) that can uniquely identify each row and altering the table to designate those columns as the primary key.

Given a table:

```sql
create table customer (
    id integer not null,
    name text not null,
    email text not null
    -- Notice the lack of a PRIMARY KEY constraint
);
```

If we assume `id` is unique for each customer, we can add a primary key constraint to the table using:

```sql
alter table customer add primary key (id);
```

If no single column can serve as a unique identifier, consider using a composite key. A composite key combines multiple columns to form a unique identifier for each row.

Example:

Consider a table event_log that logs user activities without a primary key:

```sql
create table event_log (
    user_id integer not null,
    event_time timestamp not null,
    action text not null
    -- A combination of user_id and event_time can uniquely identify rows
);
```

To resolve the lack of a primary key and ensure that each log entry is uniquely identifiable, we can add a composite primary key on user_id and event_time:

```sql
alter table event_log add primary key (user_id, event_time);
```

Ensure every table has a primary key, even if it's a synthetic key that doesn't have a natural counterpart in the data model.
When possible, use a simple fixed size types like `int`, `bigint`, and `uuid` as the primary key for maximum efficiency.
