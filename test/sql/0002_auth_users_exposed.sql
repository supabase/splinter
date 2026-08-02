begin;
    set local search_path = '';
    set local pgrst.db_schemas = 'public';

    -- No issues
    select * from lint."0002_auth_users_exposed";

    savepoint a;


    -- Failure mode 1: A materialized view
    -- Materialized views can not support row level security so they are always an overexposure risk
    create materialized view public.foo as select * from auth.users;
    -- 1 entry
    select * from lint."0002_auth_users_exposed";


    rollback to savepoint a;


    -- Failure mode 2: View that is security definer
    create view public.bar as select * from auth.users;
    -- 1 entry
    select * from lint."0002_auth_users_exposed";


    rollback to savepoint a;


    -- Failure mode 3: View that is security invoker, but RLS not enabled on auth.user
    create view public.baz with (security_invoker=on) as select * from auth.users;
    -- 1 entry
    select * from lint."0002_auth_users_exposed";
    -- resolve the issue by enabling RLS on auth.users
    alter table auth.users enable row level security;
    -- 0 entries
    select * from lint."0002_auth_users_exposed";


    rollback to savepoint a;


    -- Not a failure mode: a view depending on an object from another catalog
    -- whose oid numerically collides with auth.users' pg_class oid.
    -- pg_depend.refobjid is only unique within a refclassid, so without a
    -- refclassid filter such a view is reported even though it never
    -- references auth.users.
    create table public.orders (id int primary key);
    create function public.order_count() returns bigint language sql as
        $$select pg_catalog.count(*) from public.orders$$;
    -- move the function's pg_proc oid onto auth.users' pg_class oid
    update pg_catalog.pg_proc
        set oid = (
            select c.oid
            from pg_catalog.pg_class c
            join pg_catalog.pg_namespace n
                on n.oid = c.relnamespace
            where n.nspname = 'auth' and c.relname = 'users'
        )
        where oid = 'public.order_count'::pg_catalog.regproc;
    create view public.order_stats as select public.order_count() as total;
    -- 0 entries
    select * from lint."0002_auth_users_exposed";


rollback;
