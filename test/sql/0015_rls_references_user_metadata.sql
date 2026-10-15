begin;
    set local search_path = '';

    -- No issues
    select * from lint."0015_rls_references_user_metadata";

    -- Create a view that exposes auth.users
    create table public.foo (
        id int primary key,
        user_id uuid,
        jwt jsonb,
        role text,
        email text
    );

    create policy bad_policy_1 on public.foo
    for select
        to authenticated
        using ( (( select auth.jwt() ) ->> 'user_metadata' )::bool );

    create policy bad_policy_2 on public.foo
    for insert
        to authenticated
        with check ( ( current_setting($$request.jwt.claims$$, true)::json ->> 'user_metadata' )::boolean );

    create policy ok_policy_1 on public.foo
    for select
        to authenticated
        using ( (( select auth.jwt() ) ->> 'is_acessible' )::bool );


    -- 2 errors, both 'bad_*' policies
    select * from lint."0015_rls_references_user_metadata";
    savepoint a;
    drop table public.foo;

    -- Confirm that storage.objects and realtime.messages will be scanned (#35)
    create schema storage;
    create table storage.objects( id int primary key);

    create policy storage_user_metadata on storage.objects
    for select
        to authenticated
        using ( (( select auth.jwt() ) -> 'user_metadata' ->> 'is_admin' )::bool );

    create schema realtime;
    create table realtime.messages( id int primary key);

    create policy realtime_user_metadata on realtime.messages
    for select
        to authenticated
        using ( (( select auth.jwt() ) -> 'user_metadata' ->> 'is_admin' )::bool );

    -- 2 errors, one each for storage.objects and realtime.messages
    select * from lint."0015_rls_references_user_metadata";

    rollback to savepoint a;
    drop table public.foo;

    -- auth remains excluded: users do not author policies there
    create table auth.sessions( id int primary key);

    create policy auth_user_metadata on auth.sessions
    for select
        to authenticated
        using ( (( select auth.jwt() ) -> 'user_metadata' ->> 'is_admin' )::bool );

    -- No issues
    select * from lint."0015_rls_references_user_metadata";

rollback;
