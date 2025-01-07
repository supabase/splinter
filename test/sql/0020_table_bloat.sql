-- drop existing schema if it exists
drop schema if exists test_bloat cascade;

-- create schema and table
create schema test_bloat;
create table test_bloat.bloat_test (
    id serial primary key,
    data text,
    padding char(5000) -- ensure very wide rows to amplify bloat
);

-- disable autovacuum for consistency
alter table test_bloat.bloat_test set (autovacuum_enabled = false);

-- generate +90% bloat so this test doesn't fail randomly
insert into test_bloat.bloat_test (data, padding)
select 'Sample data ' || generate_series(1, 1000), repeat('x', 5);

-- delete 90% of the rows
delete from test_bloat.bloat_test where id % 10 != 0;

-- insert 100k new rows to ensure file growth
insert into test_bloat.bloat_test (data, padding)
select 'New data ' || generate_series(1, 1000), repeat('y', 3000);

-- delete 90% of the rows
delete from test_bloat.bloat_test where id % 10 != 1;

-- analyze the table to update statistics
analyze test_bloat.bloat_test;

-- expect 1 failure
select * from lint."0020_table_bloat";

-- resolve the issue
vacuum  test_bloat.bloat_test;
analyze test_bloat.bloat_test;

-- expect 0 failures
select * from lint."0020_table_bloat";

drop schema test_bloat cascade;



