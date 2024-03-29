
Level: INFO

### Rationale

Referencing the `auth.users` table in a view constrains future migrations within the `auth` schema which can slow down the deployment of security updates to your project.

### Why shouldn't you expose auth.users with a view?

`auth.users` is the primary table that backs Supabase Auth. It contains detailed information about each of your projects users, their login methods, and other personally identifiable information. Supabase Auth periodically executes migrations against `auth.users` and other tables in the `auth` schema to:

- Enable new features
- Improve performance
- Apply security patches

Creating views against the `auth.users` table creates enforced constraints within Postgres that can cause Supabase Auth's migrations to fail. That delays our ability to roll out updates to your project, for example, time sensitive security updates.


### How to Resolve

The recommended solution for managing access to user data is best documented in the [auth docs](https://supabase.com/docs/guides/auth/managing-user-data).

Summarizing from the docs, we recommend creating a table in the public schema e.g. `public.profiles` containing a subset of columns from `auth.users` that are appropriate for your application's use case. You can then set a trigger on `auth.users` to automatically insert the relevant data into `public.profiles` any time a new user is inserted into `auth.users`.

Note that triggers execute in the same transaction as the insert into `auth.users` so you must check the trigger logic carefully as any errors could block user signups to your project. 

### Example

To start we need a location to store public user data in the `public` scheam:

```sql
create table public.profiles (
  id uuid not null references auth.users on delete cascade,
  first_name text,
  last_name text,

  primary key (id)
);

alter table public.profiles enable row level security;
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
create policy "Public profiles are viewable by everyone."
  on profiles for select
  using ( true );

create policy "Users can update own profile."
  on profiles for update
  using ( auth.uid() = id );
```
