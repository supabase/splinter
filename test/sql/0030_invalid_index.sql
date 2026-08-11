begin;
  set local search_path = '';

  -- BASELINE: 0 issues on empty schema
  select * from lint."0030_invalid_index";

  savepoint a;

  -- NEGATIVE EXAMPLE: a normal, valid index should NOT trigger
  create table public.orders(
    id int primary key,
    customer_id int
  );
  create index idx_orders_customer_id on public.orders (customer_id);

  select * from lint."0030_invalid_index";  -- expect 0 rows

  rollback to savepoint a;

  -- POSITIVE EXAMPLE: an index left invalid (as happens when
  -- CREATE INDEX CONCURRENTLY / REINDEX CONCURRENTLY fails partway through)
  -- Simulated here via direct catalog update since CONCURRENTLY cannot
  -- run inside a transaction block.
  create table public.orders(
    id int primary key,
    order_number int
  );
  create unique index idx_orders_order_number on public.orders (order_number);
  update pg_catalog.pg_index
    set indisvalid = false
    where indexrelid = 'public.idx_orders_order_number'::regclass;

  select name, detail, cache_key from lint."0030_invalid_index";  -- expect 1 row

  -- RESOLUTION: reindex validates the index. The docs recommend
  -- `reindex index concurrently` but CONCURRENTLY cannot run inside a
  -- transaction block, so the test uses the non-concurrent form.
  reindex index public.idx_orders_order_number;

  select * from lint."0030_invalid_index";  -- expect 0 rows

  rollback to savepoint a;

  -- POSITIVE EXAMPLE (exception): an invalid index backing an exclusion
  -- constraint cannot be reindexed concurrently, so the message recommends
  -- a non-concurrent reindex instead.
  create table public.reservations(
    id int primary key,
    during int4range,
    constraint reservations_during_excl exclude using gist (during with &&)
  );
  update pg_catalog.pg_index
    set indisvalid = false
    where indexrelid = 'public.reservations_during_excl'::regclass;

  select name, detail, cache_key from lint."0030_invalid_index";  -- expect 1 row

  -- RESOLUTION: a non-concurrent reindex validates the index
  reindex index public.reservations_during_excl;

  select * from lint."0030_invalid_index";  -- expect 0 rows

rollback;
