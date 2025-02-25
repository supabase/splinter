Level: INFO

### Rationale

Anonymous users use the same `authenticated` Postgres role as permanent users when accessing the database. If you have enabled anonymous sign-in for your project, existing RLS policies may allow unintended access to an anonymous user's JWT.

### Difference between an anonymous user and a permanent user

An anonymous user is a user created through Supabase Auth. It is just like a permanent user, except the user can't access their account if they sign out, clear browsing data or use another device. An anonymous user can be differentiated from a permanent user by checking if the `is_anonymous` claim is true. These claims are returned by the `auth.jwt()` function.

### How to Resolve

Determine if existing row level security (RLS) policies are meant to allow access to anonymous users. Affected policies include those that are associated to the `authenticated` or `public` roles, and members of those roles that inherit privileges.

For example, consider the policy:

```sql
create policy "allow_access_to_authenticated" on documents
as restrictive
to authenticated
using (true);
```

In this policy, any JWT that contains the authenticated role will be allowed to access the documents table. If we want to restrict access to permanent users only, we can modify the policy to:

```sql
create policy "allow_access_to_permanent_users" on documents
as restrictive
to authenticated
using ( (select (auth.jwt()->>'is_anonymous')::boolean) is false );
```