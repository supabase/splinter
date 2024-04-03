
Level: ERROR

### Rationale

Tables in the `public` schema are accessible over Supabase APIs. If row level security (RLS) is not enabled on a `public` table, anyone with the project's URL can CREATE/READ/UPDATE/DELETE (CRUD) rows in the impacted table. Publicly exposing full CRUD to the internet is a critically unsafe configuration.


### How to Resolve

To enable RLS on a table execute:

```sql
alter table <schema>.<table> enable row level security;
```

Note that after enabling RLS you will not be able to read or write data to the table via Supabase APIs until you create [row level security policies](https://supabase.com/docs/guides/auth/row-level-security) to control access.

### Example

Given the schema:

```sql
create table public.blog(
    id int primary key,
    user_id uuid not null,
    title text not null
);
```

Any user with access to the project's URL will be able to perform CRUD operations on the `public.blog` table. To restrict access to users specified in row level security policies, enable RLS with:


```sql
alter table public.blog enable row level security;
```


