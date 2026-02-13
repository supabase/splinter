
Level: ERROR

## Impact

User data exposed through a view

### Why it matters

A view is exposing your users' personal information to anyone who can access your API.

### Rationale

Referencing the `auth.users` table in a view can inadvertently expose more data than intended.

### Why shouldn't you expose auth.users with a view?

`auth.users` is the primary table that backs Supabase Auth. It contains detailed information about each of your projects users, their login methods, and other personally identifiable information.

In Postgres, the built in mechanism for controlling access to rows within a table is row level security (RLS). By default, views in Postgres are "security definer" which means they do not respect RLS rules associated with the tables in the view's query. Materialized views similarly don't support RLS.

As a result, a `public` security definer view referencing `auth.users` exposes all user records to all API users, which is likely not what application developers intended.

### How to Resolve

There are 2 recommended solutions for exposing user data to your application.

#### Trigger on auth.users

This option involves creating a table in the public schema, e.g. `public.profiles`, containing a subset of columns from `auth.users` that are appropriate for your application's use case. You can then set a trigger on `auth.users` to automatically insert the relevant data into `public.profiles` any time a new user is inserted into `auth.users`.

Note that triggers execute in the same transaction as the insert into `auth.users` so you must check the trigger logic carefully as any errors could block user signups to your project.

An additional benefit of this approach is that the `public.profiles` table provides a logical place to store any additional user metadata that is needed for the application.

To start we need a location to store public user data in the `public` schema:

```sql
create table public.profiles (
  id uuid not null references auth.users on delete cascade,
  first_name text,
  last_name text,

  primary key (id)
);
```

Next, we create a trigger function to copy the data from `auth.users` into `public.profiles` when new rows are inserted


```sql
-- inserts a row into public.profiles
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, first_name, age)
  values (new.id, new.raw_user_meta_data ->> 'first_name', new.raw_user_meta_data['age']::integer);
  return new;
end;
$$;

-- trigger the function every time a user is created
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

Finally, we can create row level security policies on the `public.profiles` schema to restrict access to certain operations:

```sql
alter table public.profiles enable row level security;

create policy "Public profiles are viewable by everyone."
  on profiles for select
  using ( true );

create policy "Users can update own profile."
  on profiles for update
  using ( auth.uid() = id );
```

For more information on this approach see the [auth docs](https://supabase.com/docs/guides/auth/managing-user-data).


#### Security Invoker View with RLS on auth.users

The second recommended approach to securely exposing `auth.users` data is to create a view with the configuration option `security_invoker=on`. That setting, introduced in Postgres 15, tells the view to respect the RLS policies associated with the underlying tables from the query. Next, we can enable RLS on `auth.users` and create any policy we need to restrict access to the data.


To enable security invoker mode on the view we can use the `with (security_invoker=on)` clause:

```sql
create view public.members
    with (security_invoker=on)
    as
select
    id,
    raw_user_meta_data ->> 'first_name' as first_name,
    created_at
from
    auth.users;
```

Next, grant permissions and enable RLS on `auth.users`:

```sql
grant select on auth.users to authenticated;
alter table auth.users enable row level security;
```

and finally, create a policy defining which users should be able to see each record:

```sql
create policy select_self on auth.users
  for select
  using ((select auth.uid()) = id);
```
