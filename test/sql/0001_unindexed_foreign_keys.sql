begin;

    savepoint a;

    set local search_path = '';

    -- Simple Case
    -- No index on bbb.aaa_id produces an error
    create table public.aaa(
        id int primary key
    );

    create table public.bbb(
        id int primary key,
        aaa_id int references public.aaa(id) -- no index
    );

    select * from lint."0001_unindexed_foreign_keys";


    -- When a covering index is created, the error goes away
    create index on public.bbb(aaa_id);
    select * from lint."0001_unindexed_foreign_keys";


    rollback to savepoint a;


    -- Multi-column Case
    -- No index on bbb(foo, bar)
    create table public.aaa(
        foo int,
        bar int,
        primary key (foo, bar)
    );

    create table public.bbb(
        id int primary key,
        foo int,
        bar int,
        foreign key (foo, bar) references public.aaa(foo, bar)
    );

    select * from lint."0001_unindexed_foreign_keys";

    -- Confirm that an index on the correct columns but in the wrong order
    -- does NOT resolve the issue

    create index on public.bbb(bar, foo);
    select * from lint."0001_unindexed_foreign_keys";

    -- When we create a multi-column index in the correct order the issue is resolved
    create index on public.bbb(foo, bar);
    select * from lint."0001_unindexed_foreign_keys";


rollback;
