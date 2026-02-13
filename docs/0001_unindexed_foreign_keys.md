
**Level:** INFO

**Summary:** Unindexed foreign keys

**Ramification:** Database queries that filter or join on these columns will be slower because there is no index to speed them up.

---

### Rationale

In relational databases, indexing foreign key columns is a standard practice for improving query performance. Indexing these columns is recommended in most cases because it improves query join performance along a declared relationship.

### What is a Foreign Key?

A foreign key is a constraint on a column (or set of columns) that enforces a relationship between two tables. For example, a foreign key from `book.author_id` to `author.id` enforces that every value in `book.author_id` exists in `author.id`. Once the foriegn key is declared, it is not possible to insert a value into `book.author_id` that does not exist in `author.id`. Similarly, Postgres will not allow us to delete a value from `author.id` that is referenced by `book.author_id`. This concept is known as referential integrity.

### Why Index Foreign Key Columns?

Given that foreign keys define relationships among tables, it is common to use foreign key columns in join conditions when querying the database. Adding an index to the columns making up the foreign key improves the performance of those joins and reduces database resource consumption.

```sql
select
    book.id,
    book.title,
    author.name
from
    book
    join author
        -- Both sides of the following condition should be indexed
        -- for best performance
        on book.author_id = author.id
```

### How to Resolve

Given a table:

```sql
create table book (
    id serial primary key,
    title text not null,
    author_id int references author(id) -- this defines the foreign key
);
```

To apply the best practice of indexing foreign keys, an index is needed on the `book.author_id` column. We can create that index using:

```sql
create index ix_book_author_id on book(author_id);
```

In this case we used the default B-tree index type. Be sure to choose an index type that is appropriate for the data types and use case when working with your own tables.

### Example

Let's look at a practical example involving two tables: `order_item` and `customer`, where `order_item` references `customer`.

Given the schema:

```sql
create table customer (
    id serial primary key,
    name text not null
);

create table order_item (
    id serial primary key,
    order_date date not null,
    customer_id integer not null references customer (id)
);
```

We expect the tables to be joined on the condition

```sql
customer.id = order_item.customer_id
```

As in:

```sql
select
    customer.name,
    order_item.order_date
from
    customer
    join order_item
        on customer.id = order_item.customer_id
```

Using Postgres' "explain plan" functionality, we can see how its query planner expects to execute the query.

```
Hash Join  (cost=38.58..74.35 rows=2040 width=36)
  Hash Cond: (order_item.customer_id = customer.id)
  ->  Seq Scan on order_item  (cost=0.00..30.40 rows=2040 width=8)
  ->  Hash  (cost=22.70..22.70 rows=1270 width=36)
        ->  Seq Scan on customer  (cost=0.00..22.70 rows=1270 width=36)
```

Notice that the condition `order_item.customer_id = customer.id` is being serviced by a `Seq Scan`, a sequential scan across the `order_items` table. That means Postgres intends to sequentially iterate over each row in the table to identify the value of `customer_id`.

Next, if we index `order_item.customer_id` and recompute the query plan:

```sql
create index ix_order_item_customer_id on order_item(customer_id);

explain
select
    customer.name,
    order_item.order_date
from
    customer
    join order_item
        on customer.id = order_item.customer_id
```

We get the query plan:

```
Hash Join  (cost=38.58..74.35 rows=2040 width=36)
  Hash Cond: (order_item.customer_id = customer.id)
  ->  Seq Scan on order_item  (cost=0.00..30.40 rows=2040 width=8)
  ->  Hash  (cost=22.70..22.70 rows=1270 width=36)
        ->  Seq Scan on customer  (cost=0.00..22.70 rows=1270 width=36)
```

Note that nothing changed.

We get an identical result because Postgres' query planner is clever enough to know that a `Seq Scan` over an empty table is extremely fast, so theres no reason for it to reach out to an index. As more rows are inserted into the `order_item` table the tradeoff between sequentially scanning and retriving the index steadily tip in favor of the index. Rather than manually finding this inflection point, we can hint to the query planner that we'd like to use indexes by disabling sequentials scans except where they are the only available option. To provides that hint we can use:

```sql
set local enable_seqscan = off;
```

With that change:

```sql
set local enable_seqscan = off;

explain
select
    customer.name,
    order_item.order_date
from
    customer
    join order_item
        on customer.id = order_item.customer_id
```

We get the query plan:

```
Hash Join  (cost=79.23..159.21 rows=2040 width=36)
  Hash Cond: (order_item.customer_id = customer.id)
  ->  Index Scan using ix_order_item_customer_id on order_item  (cost=0.15..74.75 rows=2040 width=8)
  ->  Hash  (cost=63.20..63.20 rows=1270 width=36)
        ->  Index Scan using customer_pkey on customer  (cost=0.15..63.20 rows=1270 width=36)
```

The new plan services the `order_item.customer_id = customer.id` join condition using an `Index Scan` on `ix_order_item_customer_id` which is far more efficient at scale.
