begin;
  set local search_path = '';
  set local pgrst.db_schemas = 'public';

  -- 0 issues - no tables yet
  select * from lint."0024_rls_policy_always_true";

  -- Create a table with RLS enabled
  create table public.posts(
    id int primary key,
    user_id uuid,
    title text
  );
  alter table public.posts enable row level security;

  ----------------------------------------
  -- Test: SELECT with USING (true) should NOT be flagged
  -- SELECT with (true) is often intentional for public read access
  ----------------------------------------
  create policy "select_using_true"
  on public.posts
  for select
  to authenticated
  using (true);

  select count(*) from lint."0024_rls_policy_always_true";

  drop policy "select_using_true" on public.posts;

  ----------------------------------------
  -- Test: UPDATE with USING (true) SHOULD be flagged
  ----------------------------------------
  create policy "update_using_true"
  on public.posts
  for update
  to authenticated
  using (true);

  select metadata->>'policy_name' as policy_name, metadata->>'command' as command from lint."0024_rls_policy_always_true";

  drop policy "update_using_true" on public.posts;

  ----------------------------------------
  -- Test: DELETE with USING (true) SHOULD be flagged
  ----------------------------------------
  create policy "delete_using_true"
  on public.posts
  for delete
  to authenticated
  using (true);

  select metadata->>'policy_name' as policy_name, metadata->>'command' as command from lint."0024_rls_policy_always_true";

  drop policy "delete_using_true" on public.posts;

  ----------------------------------------
  -- Test: ALL command with USING (true) SHOULD be flagged
  ----------------------------------------
  create policy "all_using_true"
  on public.posts
  for all
  to authenticated
  using (true);

  select metadata->>'policy_name' as policy_name, metadata->>'command' as command from lint."0024_rls_policy_always_true";

  drop policy "all_using_true" on public.posts;

  ----------------------------------------
  -- Test: INSERT with WITH CHECK (true) SHOULD be flagged
  ----------------------------------------
  create policy "insert_with_check_true"
  on public.posts
  for insert
  to authenticated
  with check (true);

  select metadata->>'policy_name' as policy_name, metadata->>'command' as command from lint."0024_rls_policy_always_true";

  drop policy "insert_with_check_true" on public.posts;

  ----------------------------------------
  -- Test: INSERT with WITH CHECK (1=1) SHOULD be flagged
  ----------------------------------------
  create policy "insert_with_check_1eq1"
  on public.posts
  for insert
  to authenticated
  with check (1=1);

  select metadata->>'policy_name' as policy_name, metadata->>'command' as command from lint."0024_rls_policy_always_true";

  drop policy "insert_with_check_1eq1" on public.posts;

  ----------------------------------------
  -- Test: UPDATE with WITH CHECK (true) SHOULD be flagged
  ----------------------------------------
  create policy "update_with_check_true"
  on public.posts
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (true);

  select metadata->>'policy_name' as policy_name, metadata->>'command' as command from lint."0024_rls_policy_always_true";

  drop policy "update_with_check_true" on public.posts;

  ----------------------------------------
  -- Test: UPDATE with both USING (true) and WITH CHECK (true) SHOULD be flagged
  -- and should show "both USING and WITH CHECK are always true"
  ----------------------------------------
  create policy "update_both_true"
  on public.posts
  for update
  to authenticated
  using (true)
  with check (true);

  select
    metadata->>'policy_name' as policy_name,
    metadata->>'command' as command,
    metadata->>'permissive_using' as permissive_using,
    metadata->>'permissive_with_check' as permissive_with_check
  from lint."0024_rls_policy_always_true";

  drop policy "update_both_true" on public.posts;

  ----------------------------------------
  -- Test: Whitespace and case variations should be normalized
  -- Using TRUE with extra spaces
  ----------------------------------------
  create policy "update_using_TRUE_spaces"
  on public.posts
  for update
  to authenticated
  using (  TRUE  );

  select metadata->>'policy_name' as policy_name from lint."0024_rls_policy_always_true";

  drop policy "update_using_TRUE_spaces" on public.posts;

  ----------------------------------------
  -- Test: Restrictive policy with true should NOT be flagged
  ----------------------------------------
  create policy "restrictive_true"
  on public.posts
  as restrictive
  for update
  to authenticated
  using (true);

  select count(*) from lint."0024_rls_policy_always_true";

  drop policy "restrictive_true" on public.posts;

  ----------------------------------------
  -- Test: Policy for custom role (not anon/authenticated) should NOT be flagged
  ----------------------------------------
  create role custom_role;
  create policy "custom_role_policy"
  on public.posts
  for update
  to custom_role
  using (true);

  select count(*) from lint."0024_rls_policy_always_true";

  drop policy "custom_role_policy" on public.posts;

  ----------------------------------------
  -- Test: Policy for anon role SHOULD be flagged
  ----------------------------------------
  create policy "anon_update_true"
  on public.posts
  for update
  to anon
  using (true);

  select metadata->>'policy_name' as policy_name from lint."0024_rls_policy_always_true";

  drop policy "anon_update_true" on public.posts;

  ----------------------------------------
  -- Test: Policy for public (all roles) SHOULD be flagged for UPDATE
  ----------------------------------------
  create policy "public_update_true"
  on public.posts
  for update
  using (true);

  select metadata->>'policy_name' as policy_name from lint."0024_rls_policy_always_true";

  drop policy "public_update_true" on public.posts;

  ----------------------------------------
  -- Test: Table without RLS enabled should NOT be flagged
  ----------------------------------------
  create table public.no_rls_table(
    id int primary key
  );
  -- RLS not enabled
  create policy "no_rls_policy"
  on public.no_rls_table
  for update
  to authenticated
  using (true);

  select count(*) from lint."0024_rls_policy_always_true";

  drop table public.no_rls_table;

  ----------------------------------------
  -- Test: Proper policy with actual USING and WITH CHECK should NOT be flagged
  ----------------------------------------
  create policy "proper_policy"
  on public.posts
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

  select count(*) from lint."0024_rls_policy_always_true";

  drop policy "proper_policy" on public.posts;

  ----------------------------------------
  -- Test: ALL command with proper USING but no WITH CHECK should NOT be flagged
  -- PostgreSQL uses USING for WITH CHECK when not specified
  ----------------------------------------
  create policy "all_proper_using_no_with_check"
  on public.posts
  for all
  to authenticated
  using (user_id = auth.uid());

  select count(*) from lint."0024_rls_policy_always_true";

  drop policy "all_proper_using_no_with_check" on public.posts;

  ----------------------------------------
  -- Test: ALL command with USING (true) and no WITH CHECK SHOULD be flagged
  -- Both permissive_using (for UPDATE/DELETE) and permissive_with_check (USING falls back)
  ----------------------------------------
  create policy "all_true_using_no_with_check"
  on public.posts
  for all
  to authenticated
  using (true);

  select
    metadata->>'policy_name' as policy_name,
    metadata->>'permissive_using' as permissive_using,
    metadata->>'permissive_with_check' as permissive_with_check
  from lint."0024_rls_policy_always_true";

  drop policy "all_true_using_no_with_check" on public.posts;

  ----------------------------------------
  -- Test: INSERT with no WITH CHECK (null) SHOULD be flagged
  ----------------------------------------
  create policy "insert_no_with_check"
  on public.posts
  for insert
  to authenticated;

  select
    metadata->>'policy_name' as policy_name,
    metadata->>'permissive_with_check' as permissive_with_check
  from lint."0024_rls_policy_always_true";

  drop policy "insert_no_with_check" on public.posts;

  ----------------------------------------
  -- Test: SELECT with USING (true) whose name claims ownership SHOULD be flagged
  -- The name says the policy is per-user, so the always-true expression is not intentional public read access
  ----------------------------------------
  create policy "Users can view their own posts"
  on public.posts
  for select
  to authenticated
  using (true);

  select metadata->>'policy_name' as policy_name, metadata->>'command' as command, detail, cache_key from lint."0024_rls_policy_always_true";

  drop policy "Users can view their own posts" on public.posts;

  ----------------------------------------
  -- Test: name matching treats underscores and hyphens as word separators
  ----------------------------------------
  create policy "select_own_posts"
  on public.posts
  for select
  to authenticated
  using (true);

  select metadata->>'policy_name' as policy_name from lint."0024_rls_policy_always_true";

  drop policy "select_own_posts" on public.posts;

  ----------------------------------------
  -- Test: SELECT with USING (true) whose name claims a role SHOULD be flagged
  ----------------------------------------
  create policy "Admins can view all posts"
  on public.posts
  for select
  to authenticated
  using (true);

  create policy "Service role can read posts"
  on public.posts
  for select
  using (true);

  select metadata->>'policy_name' as policy_name, metadata->>'command' as command from lint."0024_rls_policy_always_true";

  drop policy "Admins can view all posts" on public.posts;
  drop policy "Service role can read posts" on public.posts;

  ----------------------------------------
  -- Test: SELECT with USING (true) and a public-sounding or neutral name should NOT be flagged
  -- "own" inside another word (e.g. "shown") must not match
  ----------------------------------------
  create policy "Public profiles are viewable by everyone."
  on public.posts
  for select
  using (true);

  create policy "Posts shown on the homepage"
  on public.posts
  for select
  to anon
  using (true);

  create policy "Public read only"
  on public.posts
  for select
  to anon, authenticated
  using (true);

  select count(*) from lint."0024_rls_policy_always_true";

  drop policy "Public profiles are viewable by everyone." on public.posts;
  drop policy "Posts shown on the homepage" on public.posts;
  drop policy "Public read only" on public.posts;

  ----------------------------------------
  -- Test: real SELECT USING (true) policy names that claim per-user or admin scope SHOULD be flagged
  ----------------------------------------
  create policy "Admin reads all activity" on public.posts for select to authenticated using (true);
  create policy "Users can view their restaurant's marketing data" on public.posts for select to authenticated using (true);
  create policy "Users can view their own import jobs" on public.posts for select to authenticated using (true);
  create policy "Allow authenticated read for admin" on public.posts for select to authenticated using (true);
  create policy "admin_select_responses" on public.posts for select to authenticated using (true);

  select metadata->>'policy_name' as policy_name from lint."0024_rls_policy_always_true";

  drop policy "Admin reads all activity" on public.posts;
  drop policy "Users can view their restaurant's marketing data" on public.posts;
  drop policy "Users can view their own import jobs" on public.posts;
  drop policy "Allow authenticated read for admin" on public.posts;
  drop policy "admin_select_responses" on public.posts;

  ----------------------------------------
  -- Test: real SELECT USING (true) policy names should NOT be flagged when the owner or admin word
  -- describes the table's contents, or when the name declares public or anyone access
  ----------------------------------------
  create policy "Allow reading admin users" on public.posts for select to authenticated using (true);
  create policy "Allow public read access for admins" on public.posts for select using (true);
  create policy "Allow public read access for admin activity logs" on public.posts for select using (true);
  create policy "Public can view vehicle owners" on public.posts for select using (true);
  create policy "Anyone can read own payments by phone" on public.posts for select using (true);

  select metadata->>'policy_name' as policy_name from lint."0024_rls_policy_always_true";

  drop policy "Allow reading admin users" on public.posts;
  drop policy "Allow public read access for admins" on public.posts;
  drop policy "Allow public read access for admin activity logs" on public.posts;
  drop policy "Public can view vehicle owners" on public.posts;
  drop policy "Anyone can read own payments by phone" on public.posts;

  ----------------------------------------
  -- Test: each owner and admin phrase SHOULD be flagged on its own, an "all users" name that
  -- claims ownership SHOULD be flagged, and USING (1=1) counts as always true for SELECT
  ----------------------------------------
  create policy "Owners can view posts" on public.posts for select to authenticated using (true);
  create policy "Only owners can read" on public.posts for select to authenticated using (true);
  create policy "Readable by only the owner" on public.posts for select to authenticated using (true);
  create policy "Read access for the owner" on public.posts for select to authenticated using (true);
  create policy "Owner only read" on public.posts for select to authenticated using (true);
  create policy "Visible to only admins" on public.posts for select to authenticated using (true);
  create policy "All users can view their own posts" on public.posts for select to authenticated using (true);
  create policy "Users can view own posts" on public.posts for select to authenticated using (1=1);

  select metadata->>'policy_name' as policy_name from lint."0024_rls_policy_always_true";

  drop policy "Owners can view posts" on public.posts;
  drop policy "Only owners can read" on public.posts;
  drop policy "Readable by only the owner" on public.posts;
  drop policy "Read access for the owner" on public.posts;
  drop policy "Owner only read" on public.posts;
  drop policy "Visible to only admins" on public.posts;
  drop policy "All users can view their own posts" on public.posts;
  drop policy "Users can view own posts" on public.posts;

  ----------------------------------------
  -- Test: "for admin" only counts at the end of the name, and "everyone" blocks a scope word
  ----------------------------------------
  create policy "Authenticated can read for admin reports" on public.posts for select to authenticated using (true);
  create policy "Everyone can view their posts" on public.posts for select using (true);

  select metadata->>'policy_name' as policy_name from lint."0024_rls_policy_always_true";

  drop policy "Authenticated can read for admin reports" on public.posts;
  drop policy "Everyone can view their posts" on public.posts;

  ----------------------------------------
  -- Test: each word after "admin" SHOULD be flagged on its own
  -- ("can", "reads" and "select" are covered above)
  ----------------------------------------
  create policy "Admin only" on public.posts for select to authenticated using (true);
  create policy "Admin read posts" on public.posts for select to authenticated using (true);
  create policy "Admin view" on public.posts for select to authenticated using (true);
  create policy "Admin views posts" on public.posts for select to authenticated using (true);
  create policy "Admins see posts" on public.posts for select to authenticated using (true);
  create policy "Admin sees posts" on public.posts for select to authenticated using (true);
  create policy "Admins manage posts" on public.posts for select to authenticated using (true);
  create policy "Admin manages posts" on public.posts for select to authenticated using (true);

  select metadata->>'policy_name' as policy_name from lint."0024_rls_policy_always_true";

  drop policy "Admin only" on public.posts;
  drop policy "Admin read posts" on public.posts;
  drop policy "Admin view" on public.posts;
  drop policy "Admin views posts" on public.posts;
  drop policy "Admins see posts" on public.posts;
  drop policy "Admin sees posts" on public.posts;
  drop policy "Admins manage posts" on public.posts;
  drop policy "Admin manages posts" on public.posts;

  ----------------------------------------
  -- Test: write policies named "admin insert/update/delete" get the name note in detail,
  -- and a write policy with a neutral name does not
  ----------------------------------------
  create policy "admin_insert_posts" on public.posts for insert to authenticated with check (true);
  create policy "admin_update_posts" on public.posts for update to authenticated using (true);
  create policy "admin_delete_posts" on public.posts for delete to authenticated using (true);
  create policy "update_any_post" on public.posts for update to authenticated using (true);

  select metadata->>'policy_name' as policy_name, detail from lint."0024_rls_policy_always_true";

  drop policy "admin_insert_posts" on public.posts;
  drop policy "admin_update_posts" on public.posts;
  drop policy "admin_delete_posts" on public.posts;
  drop policy "update_any_post" on public.posts;

  ----------------------------------------
  -- Test: SELECT whose name claims ownership and whose USING checks the owner should NOT be flagged
  ----------------------------------------
  create policy "Users can view their own posts"
  on public.posts
  for select
  to authenticated
  using (user_id = auth.uid());

  select count(*) from lint."0024_rls_policy_always_true";

  drop policy "Users can view their own posts" on public.posts;

  ----------------------------------------
  -- Test: write policies whose name claims ownership get the name note in detail
  -- when nothing in the policy checks the caller
  ----------------------------------------
  create policy "Users can update their own posts"
  on public.posts
  for update
  to authenticated
  using (true);

  create policy "Users can insert their own posts"
  on public.posts
  for insert
  to authenticated
  with check (true);

  select metadata->>'policy_name' as policy_name, detail from lint."0024_rls_policy_always_true";

  drop policy "Users can update their own posts" on public.posts;
  drop policy "Users can insert their own posts" on public.posts;

  ----------------------------------------
  -- Test: UPDATE policies where one clause is always true and the other checks the owner
  -- are still flagged, without the name note, because part of the policy does check the caller
  ----------------------------------------
  create policy "Users can update their own posts"
  on public.posts
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (true);

  create policy "Owners can update posts"
  on public.posts
  for update
  to authenticated
  using (true)
  with check (user_id = auth.uid());

  select metadata->>'policy_name' as policy_name, detail from lint."0024_rls_policy_always_true";

  drop policy "Users can update their own posts" on public.posts;
  drop policy "Owners can update posts" on public.posts;

  ----------------------------------------
  -- Test: a DELETE policy with no USING is still flagged, but without the name note,
  -- since a missing USING only counts as "checks nobody" for INSERT
  ----------------------------------------
  create policy "Users can delete their own posts"
  on public.posts
  for delete
  to authenticated;

  select metadata->>'policy_name' as policy_name, detail from lint."0024_rls_policy_always_true";

  drop policy "Users can delete their own posts" on public.posts;

rollback;
