begin;
    set local search_path = '';

    savepoint a;

    -- No issues
    select * from lint."0003_auth_rls_initplan";

    -- Create a view that exposes auth.users
    create table public.foo (
        id int primary key,
        user_id uuid,
        jwt jsonb,
        role text,
        email text
    );

    create policy bad_policy_uid on public.foo
    for select
        to authenticated
        using (user_id = auth.uid());

    create policy bad_policy_jwt on public.foo
    for insert
        to authenticated
        with check (jwt = auth.jwt());

    create policy bad_policy_role on public.foo
    for update
        to authenticated
        with check ("role" = auth.role());

    create policy bad_policy_email on public.foo
    for delete
        to authenticated
        using ("email" = auth.email());

    create policy bad_policy_current_setting on public.foo
    for delete
        to authenticated
        -- crazy whitespace is intentional
        using ("email" =   current_setting(  'role'  ));

    create policy good_policy_uid on public.foo
    for select
        to authenticated
        using (user_id = (select auth.uid()));

    create policy good_policy_jwt on public.foo
    for insert
        to authenticated
        with check (jwt = (select auth.jwt()));

    create policy good_policy_role on public.foo
    for update
        to authenticated
        with check ("role" = (select auth.role()));

    create policy good_policy_email on public.foo
    for delete
        to authenticated
        using ("email" = (select auth.email()));

    create policy good_policy_current_setting on public.foo
    for delete
        to authenticated
        using ("email" = (select current_setting('role')));

    -- Still empty because RLS not enabled
    select * from lint."0003_auth_rls_initplan";


    alter table public.foo enable row level security;

    -- 5 entries, 1 per "bad_" policy
    select * from lint."0003_auth_rls_initplan";

    rollback to savepoint a;

    -- Confirm that realtime.messages will be scanned
    create schema realtime;
    create table realtime.messages( id int primary key);

    create policy realtime_check on realtime.messages
    for insert
        to authenticated
        with check ('foo' = auth.role());

    alter table realtime.messages enable row level security;

    -- 1 entry for realtime.messages
    select * from lint."0003_auth_rls_initplan";

rollback;
