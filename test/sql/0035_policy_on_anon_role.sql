begin;
  set local search_path = '';

  -- BASELINE: 0 issues on empty schema
  select * from lint."0035_policy_on_anon_role";

  create table public.docs(
    id int primary key,
    owner_id uuid,
    published boolean
  );
  alter table public.docs enable row level security;

  savepoint a;

  -- NEGATIVE: TO authenticated is not reachable by anon
  create policy "own_rows" on public.docs
    for all to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());
  select * from lint."0035_policy_on_anon_role";

  rollback to savepoint a;

  -- NEGATIVE: SELECT policies with a literal true are deliberate public read
  create policy "explicit_anon_read" on public.docs
    for select to anon
    using (true);
  create policy "public_read" on public.docs
    for select
    using (true);
  select * from lint."0035_policy_on_anon_role";

  rollback to savepoint a;

  -- NEGATIVE: restrictive policies only narrow access
  create policy "restrict" on public.docs
    as restrictive
    for all to anon
    using (owner_id = auth.uid());
  select * from lint."0035_policy_on_anon_role";

  rollback to savepoint a;

  -- POSITIVE: explicit TO anon with an identity check
  create policy "anon_own_rows" on public.docs
    for all to anon
    using (owner_id = auth.uid());
  select name, detail, cache_key from lint."0035_policy_on_anon_role";

  rollback to savepoint a;

  -- POSITIVE: no TO clause defaults to public, which includes anon
  create policy "no_to_clause" on public.docs
    for all
    using (owner_id = auth.uid());
  select metadata->>'policy_name' as policy_name, metadata->>'roles' as roles from lint."0035_policy_on_anon_role";

  rollback to savepoint a;

  -- POSITIVE: SELECT policies with any expression beyond a literal true are flagged
  create policy "select_column" on public.docs
    for select
    using (published);
  create policy "select_setting" on public.docs
    for select to anon
    using (current_setting('app.tenant', true) = owner_id::text);
  create policy "select_uid" on public.docs
    for select
    using (auth.uid() = owner_id);
  select metadata->>'policy_name' as policy_name, metadata->>'roles' as roles from lint."0035_policy_on_anon_role";

  rollback to savepoint a;

  -- POSITIVE: explicit TO public with initplan-wrapped identity on a SELECT
  create policy "public_select_identity" on public.docs
    for select to public
    using (owner_id = (select auth.uid()));
  select metadata->>'policy_name' as policy_name, metadata->>'roles' as roles from lint."0035_policy_on_anon_role";

  rollback to savepoint a;

  -- POSITIVE: write policies are flagged without any identity reference
  create policy "anon_insert" on public.docs
    for insert to anon
    with check (true);
  select metadata->>'policy_name' as policy_name, metadata->>'command' as command from lint."0035_policy_on_anon_role";

  rollback to savepoint a;

  -- POSITIVE: a role that anon is a member of also applies to anon
  create role api_base;
  grant api_base to anon;
  create policy "via_member_role" on public.docs
    for update to api_base
    using (owner_id = auth.uid());
  select metadata->>'policy_name' as policy_name, metadata->>'roles' as roles from lint."0035_policy_on_anon_role";

  rollback to savepoint a;

  -- POSITIVE: only the anon-matching roles are reported
  create policy "anon_and_authenticated" on public.docs
    for all to anon, authenticated
    using (owner_id = auth.uid());
  select metadata->>'policy_name' as policy_name, metadata->>'roles' as roles from lint."0035_policy_on_anon_role";

  rollback to savepoint a;

  -- POSITIVE: user-authored policies on storage.objects (the role-less JWT case)
  create schema storage;
  create table storage.objects(
    id int primary key,
    bucket_id text,
    name text
  );
  alter table storage.objects enable row level security;
  create policy "folder_is_uid" on storage.objects
    for all
    using (bucket_id = 'files' and (string_to_array(name, '/'))[1] = auth.uid()::text);
  select name, detail, cache_key from lint."0035_policy_on_anon_role";

  -- RESOLUTION: scope the policy to authenticated
  drop policy "folder_is_uid" on storage.objects;
  create policy "folder_is_uid" on storage.objects
    for all to authenticated
    using (bucket_id = 'files' and (string_to_array(name, '/'))[1] = auth.uid()::text);
  select * from lint."0035_policy_on_anon_role";

rollback;
