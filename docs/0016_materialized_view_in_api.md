**Level:** WARN

**Summary:** Materialized view exposed in API

**Ramification:** Materialized views can't be protected by Row-Level Security, so all their data is visible to every API user.

---

### Rationale

Materialized views in Postgres can present a security risk if they are accessible to API roles `anon` and `authenticated`. Unlike regular views, materialized views can not be configured to respect Row Level Security (RLS) policies of the underlying tables they are built upon, nor can they cannot be secured with RLS directly. Therefore, if materialized views are accessible over APIs, all rows are always visible, which may not be intended.

### The Risk of Materialized Views Accessible by Anon or Authenticated Roles

If materialized views are exposed in APIs and accessible by the `anon` or `authenticated` roles, API users bypass any Row-Level Security (RLS) policies implemented on the underlying tables. This can lead to unintended exposure of sensitive data as all users will be able to select all rows of data from the materialized views.

### How to Resolve

To mitigate the risk it is recommended to revoke `select` access from API roles `anon` and `authenticated`.

```sql
revoke select on public.some_mat_view from public, anon, authenticated;
```

Note that the `public` role is a role that sets default permissions for all other roles. If the `public` role allows access by default (as it does in the `public` schema) you must also revoke `select` accesss from it.

You can test if your permissions update worked sucessfully by running

```sql
select pg_catalog.has_table_privilege('anon', 'public.some_mat_view'::regclass::oid, 'select')
-- Should return: 'false'
```

Substituting in the appropriate role and view name.
