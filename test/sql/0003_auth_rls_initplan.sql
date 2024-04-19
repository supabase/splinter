begin;
    set local search_path = '';

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

    savepoint a;

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

    -- Still empty because RLS not enabled
    select * from lint."0003_auth_rls_initplan";


    alter table public.foo enable row level security;

    -- 4 entries, 1 per "bad_" policy
    select * from lint."0003_auth_rls_initplan";

    rollback to savepoint a;

    create table public.lessons (
        id int primary key,
        userid uuid
    );

    alter table public.lessons enable row level security;

    create policy "users control their lessons" on "public"."lessons"
        as permissive
        for all to public
        using
            (userid = (SELECT auth.uid()))
        with check
            (userid = (SELECT auth.uid()));

    select
        qual,
        with_check
    from
        pg_catalog.pg_policy pa
        join pg_catalog.pg_class pc
            on pa.polrelid = pc.oid
        join pg_catalog.pg_namespace nsp
            on pc.relnamespace = nsp.oid
        join pg_catalog.pg_policies pb
            on pc.relname = pb.tablename
            and nsp.nspname = pb.schemaname
            and pa.polname = pb.policyname
    where
        polname = 'users control their lessons';

    -- Should be empty
    select * from lint."0003_auth_rls_initplan";

rollback;
