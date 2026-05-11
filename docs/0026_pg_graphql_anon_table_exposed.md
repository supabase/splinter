
**Level:** WARN

**Summary:** This object is visible in your GraphQL schema to anyone using the public anon key.

**Ramification:** If `anon` can `SELECT` any column on a table, view, materialized view, or foreign table, `pg_graphql` exposes that object's name, columns, relationships, and generated mutations through `/graphql/v1` introspection. RLS does not change that because it protects rows, not schema visibility. If this object should not be discoverable before sign-in, revoke `SELECT` from `anon` or disable `pg_graphql` if you do not use GraphQL.

> **See also: lint [0027_pg_graphql_authenticated_table_exposed](0027_pg_graphql_authenticated_table_exposed.md).** In default Supabase projects `anon` and `authenticated` start with identical default-privilege grants, so revoking from `anon` alone often leaves the same introspection response served to any signed-up user. Address findings from both lints together.

---

### If you are not using `pg_graphql`, disable it

The simplest mitigation — and the right one if your app does not use the GraphQL endpoint — is to drop the extension. With `pg_graphql` not installed, this lint and 0027 stop firing entirely and the `/graphql/v1` endpoint returns nothing exposing your schema.

In the Supabase SQL Editor:

```sql
drop extension pg_graphql;
```

Or in the dashboard: **Database → Extensions**, search for `pg_graphql`, and toggle it off.

If your project does use `pg_graphql`, leave it installed and follow the remediation below.

---

### Rationale

`pg_graphql` introspection is by design: the GraphQL schema reflects the Postgres privileges of the calling role. The Supabase anon key maps to the `anon` Postgres role, so any relation `anon` can `SELECT` is visible in the GraphQL introspection response from `/graphql/v1`, regardless of RLS. Visibility through introspection is governed entirely by `GRANT` / `REVOKE`. This lint flags the objects currently discoverable through the public anon key so you can confirm each one is intentionally public.

The relkinds covered match `pg_graphql`'s own filter (`load_sql_context.sql:395-400`): regular tables (`r`), views (`v`), materialized views (`m`), and foreign tables (`f`). Partitioned table roots (`relkind='p'`) are not covered because `pg_graphql` does not expose them via introspection; their leaf partitions (`relkind='r'`) are still picked up individually.

You can confirm what is visible using only the public anon key:

```bash
curl -X POST https://<PROJECT_REF>.supabase.co/graphql/v1 \
  -H 'apiKey: <ANON_KEY>' \
  -H 'Authorization: Bearer <ANON_KEY>' \
  -H 'Content-Type: application/json' \
  --data-raw '{"query": "{ __schema { types { name fields { name } } } }"}'
```

The response includes one entry per exposed table (e.g. `internal_api_keysCollection`, `ordersCollection`), the full column list for each table, and `Mutation` entries like `insertIntointernal_api_keysCollection`, `updateinternal_api_keysCollection`, `deleteFrominternal_api_keysCollection`.

### How to Resolve

The fix is always a standard Postgres `GRANT` / `REVOKE` run in the SQL Editor. No support ticket, no config file, no extension toggle.

**Important:** revoking from `anon` does not, on its own, hide the relation from `pg_graphql` introspection — `authenticated` is checked separately by lint 0027 and typically has the same default grants. Address both lints' findings together (see "Hide all tables from both roles" in 0027).

**Option 1: Hide every table from `anon` (most thorough)**

```sql
revoke all on all tables in schema public from anon;
```

Then prevent future tables from auto-exposing:

```sql
alter default privileges in schema public
  revoke select on tables from anon;
```

Re-grant access to `authenticated` for tables your app needs after login:

```sql
grant select on public.profiles to authenticated;
grant select on public.products to authenticated;
grant select, insert on public.orders to authenticated;
-- Sensitive tables receive no grant from anon and remain invisible to
-- the public introspection endpoint. Make sure to also handle 0027 for
-- the authenticated-side exposure.
```

**Option 2: Hide a specific sensitive table or view only**

```sql
revoke all on public.internal_api_keys from anon;
```

`anon` continues to see other objects, but `internal_api_keys` is no longer visible in the unauthenticated introspection response. Use the same `revoke all on <object>` pattern for views, materialized views, and foreign tables.

**Option 3: Block the entire GraphQL endpoint for `anon`**

```sql
revoke all on function graphql.resolve from anon;
```

This rejects every unauthenticated GraphQL request, not just introspection. Use only if you do not need GraphQL for unauthenticated users at all. The table-level revokes above are usually preferable because they keep the endpoint alive while returning an empty schema.

### Example

Given a table that anyone can read via the anon key:

```sql
create table public.internal_api_keys(
    id uuid primary key,
    service text,
    key_hash text,
    permissions jsonb,
    last_used timestamptz,
    created_by uuid
);

alter table public.internal_api_keys enable row level security;
-- No policies, but anon still inherits the default SELECT grant.
```

Even though RLS is enabled and no rows are returned, every column name above is now visible through `/graphql/v1` introspection.

Fix:

```sql
revoke all on public.internal_api_keys from anon;
```

Re-running the introspection query with the anon key no longer returns this table. (The same call repeated with a signed-up user's JWT still returns it until you also revoke from `authenticated` — see 0027.)

### Verifying the Fix

After applying the revoke, the introspection query's `Query` type should contain only `{"name": "node"}` (when every table has been hidden) or omit the specific table you revoked. Authenticated users with a valid JWT continue to see only the tables explicitly granted to the `authenticated` role:

```bash
curl -X POST https://<PROJECT_REF>.supabase.co/graphql/v1 \
  -H 'apiKey: <ANON_KEY>' \
  -H 'Authorization: Bearer <USER_JWT>' \
  -H 'Content-Type: application/json' \
  --data-raw '{"query": "{ __schema { types { name fields { name } } } }"}'
```

### Quick Reference

| Goal | SQL |
|------|-----|
| Hide one table from `anon` | `revoke all on public.secret_table from anon;` |
| Hide all tables from `anon` | `revoke all on all tables in schema public from anon;` |
| Prevent future auto-grants | `alter default privileges in schema public revoke select on tables from anon;` |
| Kill GraphQL endpoint for `anon` | `revoke all on function graphql.resolve from anon;` |
| Grant a table to `authenticated` | `grant select on public.my_table to authenticated;` |

### False Positives

This lint flags every `anon`-readable relation when `pg_graphql` is installed. Some of these are intentional — public catalog tables (blog posts, product listings, public FAQs) are meant to be readable without authentication, and exposing their column names is acceptable.

If introspection visibility is intentional for a relation, the lint can be safely ignored for that object. The lint is informational rather than a hard misconfiguration: it surfaces what your project makes visible so you can decide which relations are actually meant to be public.
