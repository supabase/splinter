
**Level:** WARN

**Summary:** Tables readable by the `anon` role leak their schema (table names, columns, relationships) through `pg_graphql` introspection.

**Ramification:** Anyone with your public anon key can enumerate every table the `anon` role can SELECT — even when RLS is enabled. RLS hides rows; it does not hide the schema. This is schema reconnaissance: every table name, column name, type, relationship, and mutation endpoint becomes public knowledge.

---

### Rationale

`pg_graphql` introspection results reflect the Postgres privileges of the calling role. The Supabase anon key maps to the `anon` Postgres role. If `anon` can `SELECT` a table, the table is visible in the GraphQL introspection response from `/graphql/v1`, regardless of RLS. The PostgREST Data API blocks schema inspection without a service role key, but `pg_graphql` does not — its introspection is governed entirely by `GRANT` / `REVOKE`.

You can confirm the leak using only the public anon key:

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
-- Sensitive tables receive no grant and remain invisible to introspection.
```

**Option 2: Hide a specific sensitive table only**

```sql
revoke all on public.internal_api_keys from anon;
```

`anon` continues to see other tables, but `internal_api_keys` disappears from introspection.

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

Re-running the introspection query no longer returns this table.

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

This lint flags every `anon`-readable table when `pg_graphql` is installed. Some of these are intentional — public catalog tables (blog posts, product listings, public FAQs) are meant to be readable without authentication, and exposing their column names is acceptable.

If introspection visibility is intentional for a table, the lint can be safely ignored for that table. The lint is informational rather than a hard misconfiguration: it surfaces what your project leaks so you can decide which tables are actually meant to be public.
