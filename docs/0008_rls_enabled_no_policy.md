
Level: INFO

## Impact

No access rules defined

### Why it matters

Row-Level Security is enabled but no policies exist, so no data can be read or written through the API.

### Rationale

In Postgres, Row Level Security (RLS) policies control access to rows in a table based on the executing user. If a table has RLS enabled, but no policies exist, no data will be selectable via Supabase APIs.

### How to Resolve

If a table has RLS enabled with no policies, you can resolve the issue by creating a policy on the table

For example:

```sql
create policy select_own_posts on public.blog
    for select
    using ((select auth.uid()) = user_id);
```

### Example

Given the schema:

```sql
create table public.blog(
    id int primary key,
    user_id uuid not null,
    title text not null
);

alter table public.blog enable row level security;
```

No data will be selectable from the public.blog table over Supabase APIs.

To resolve the issue, create a policy on `public.blog` to grant some level of access

```sql
create policy select_own_posts on public.blog
    for select
    using ((select auth.uid()) = user_id);
```

Note that some users may enable RLS with no policies intentionally to restrict access over APIs. In those cases we recommend making that intent explicit with a rejection policy.

```sql
create policy none_shall_pass on public.blog
    for select
    using (false);
```


