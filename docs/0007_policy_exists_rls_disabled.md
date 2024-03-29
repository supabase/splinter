
Level: INFO

### Rationale

In Postgres, Row Level Security (RLS) policies control access to rows in a table based on the executing user. Policies can be created, but will not be enforced until the table is updated to enable row level security. Failing to enable row level security is a common misconfiguration that can lead to data leaks. 


### How to Resolve

To enable existing policies on a table execute:

```sql
alter table <schema>.<table> enable row level security;
```

### Example

Given the schema:

```sql
create table public.blog(
    id int primary key
);

create policy select_own_posts on public.blog
    for select
    using (true);

create policy all_own_posts on public.blog
    for all
    using (true);
```

A user may incorrectly believe that their policies are being applied. Before the policies will take effect, we first must enable row level security on the underlying table.


```sql
alter table public.blog enable row level security;
```


