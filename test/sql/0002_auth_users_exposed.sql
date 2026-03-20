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


rollback;
