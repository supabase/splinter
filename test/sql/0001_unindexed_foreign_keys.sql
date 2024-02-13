begin;

	savepoint a;

	-- Simple Case
	-- No index on bbb.aaa_id produces an error
    create table aaa(
        id int primary key
    );

    create table bbb(
        id int primary key,
        aaa_id int references aaa(id) -- no index
    );

    select * from "0001_unindexed_foreign_keys";


	-- When a covering index is created, the error goes away
	create index on bbb(aaa_id);
    select * from "0001_unindexed_foreign_keys";


	rollback to savepoint a;


	-- Multi-column Case
	-- No index on bbb(foo, bar)
    create table aaa(
        foo int,
		bar int,
		primary key (foo, bar)
    );

    create table bbb(
        id int primary key,
		foo int,
		bar int,
		foreign key (foo, bar) references aaa(foo, bar)
    );

    select * from "0001_unindexed_foreign_keys";

	-- Confirm that an index on the correct columns but in the wrong order
	-- does NOT resolve the issue

	create index on bbb(bar, foo);
    select * from "0001_unindexed_foreign_keys";

	-- When we create a multi-column index in the correct order the issue is resolved
	create index on bbb(foo, bar);
    select * from "0001_unindexed_foreign_keys";


rollback;
