begin;

  -- 0 issues
  select * from lint."0012_auth_allow_anonymous_sign_ins";

  create table public.documents( id int primary key );

  -- Create a policy for the authenticated role that would allow access to anonymous login users
  -- if that feature is enabled 
  create policy "allow_access_to_authenticated" on public.documents
    as restrictive
    to authenticated
    using (true);

  -- 1 issues
  select * from lint."0012_auth_allow_anonymous_sign_ins";

  drop policy "allow_access_to_authenticated" on public.documents;

  -- Resolve the issue by excluding anonymous login users
  create policy "allow_access_to_permanent_users" on documents
    as restrictive
    to authenticated
    using ( (select (auth.jwt() ->> 'is_anonymous')::boolean) is false );

  -- 0 issues
  select * from lint."0012_auth_allow_anonymous_sign_ins";
  
rollback;
