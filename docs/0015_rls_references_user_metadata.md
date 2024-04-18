
Level: ERROR

### Rationale

Supabase Auth [user_metadata](https://supabase.com/docs/guides/auth/managing-user-data#accessing-user-metadata) is used to set metadata about the user on sign up. It is designed to be manipulated by the user themselves. Because the user can change it (either directly or indirectly by sending a user update API call) to any value (there is no validation) this should not be used to base security policies.

### The Risk

Row-Level Security (RLS) policies are the mechanism for controlling access to data based on user roles or attributes. Supabase Auth [user_metadata](https://supabase.com/docs/guides/auth/managing-user-data#accessing-user-metadata) allows metadata to be assigned to users, but that metadata can also be manipulated by the end user using client libraries. For example, in supabase-js:

```js
updateUser({ data: { is_admin: true } }) 
```

For that reason, it is not safe to rely on the contents of `user_metadata` in row level security policies.

An example insecure policy could be:

```sql
create policy bad_policy on public.foo
for select
  to authenticated
  using ( (( select auth.jwt() ) -> 'user_metadata' ->> 'is_admin' )::bool );
```

The policy is insecure because end users could execute `updateUser({ data: { is_admin: true } })` to bypass the security check.

### How to Resolve

There is no one-size-fits-all solution to replacing a RLS policy that references `user_metadata`.

If you're unsure how to refactor your policy to remove its dependance on `user_metadata` [open a ticket with support](https://supabase.com/dashboard/support/new) for assistance.
