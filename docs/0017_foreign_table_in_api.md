Level: WARN

## Impact

Foreign table exposed in API

### Why it matters

Foreign tables can't be protected by Row-Level Security, so all their data is visible to every API user.

### Rationale

Foreign Tables in Postgres can present a security risk if they are accessible to API roles `anon` and `authenticated`. Unlike regular tables, foreign tables can not be configured to respect Row Level Security (RLS) policies. Therefore, if foreign tables are accessible over APIs, all rows are always visible, which may not be intended.

### How to Resolve

If the foreign table does not need to be accessible over the API you can resolve the issue by revoking `select` access from API roles `anon` and `authenticated`.

```sql
revoke select on public.some_foreign_table from public, anon, authenticated;
```

Note that the `public` role is a role that sets default permissions for all other roles. If the `public` role allows access by default (as it does in the `public` schema) you must also revoke `select` accesss from it.

You can test if your permissions update worked sucessfully by running

```sql
select pg_catalog.has_table_privilege('anon', 'public.some_foreign_table'::regclass::oid, 'select')
-- Should return: 'false'
```

Substituting in the appropriate role and view name.

If you do need to access data from the foreign table over APIs we recommend moving the foreign table out of the API's exposed schemas and then creating a function, accessible [over RPC](https://supabase.com/docs/reference/javascript/rpc), that implements security rules on top of the foreign table. For example, if we wanted to confirm that the Supabase Auth user matches the `author_id` column of the foreign table the function might look like:xt

```sql
-- Create a new schema
create schema private;

-- Move the foreign table out of the API's exposed schemas
alter foreign table public.some_foreign_table set schema private;

-- Make sure the API roles still have access to the FDW
grant select on public.some_foreign_table to anon, authenticated;

-- Create a function/RPC target with security rules
create or replace function fdw_wrapping_function()
  returns table (id integer, data text, author_id uuid)
  language sql
  set search_path = ''
as $$
  select
    id,
    data,
    author_id
  from
    private.some_foreign_table
  where
    author_id = (select auth.uid()); -- SECURITY RULE
$$;
```
