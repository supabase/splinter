begin;

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


rollback;
