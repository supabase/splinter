
**Level:** WARN

**Summary:** Tables, views, materialized views, and foreign tables readable by the `authenticated` role have their schema (names, columns, relationships) made visible through `pg_graphql` introspection to any signed-up user.

**Ramification:** Every relation the `authenticated` role can SELECT is enumerable by anyone with a valid Supabase user JWT — even when RLS is enabled. RLS hides rows; it does not hide the schema. In default Supabase projects the `authenticated` role starts with the same default-privilege grants as `anon` (both come from `ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin … TO anon, authenticated, service_role`), and under open or auto-confirm signup, "authenticated" is in practice anyone with a throwaway email rather than a meaningfully smaller audience.

> **See also: lint [0026_pg_graphql_anon_table_exposed](0026_pg_graphql_anon_table_exposed.md).** The two checks are paired — revoking from one role alone usually leaves the other side of the introspection response unchanged. Address findings from both lints together.

---

### If you are not using `pg_graphql`, disable it

The simplest mitigation — and the right one if your app does not use the GraphQL endpoint — is to drop the extension. With `pg_graphql` not installed, this lint and 0026 stop firing entirely and the `/graphql/v1` endpoint returns nothing exposing your schema.

In the Supabase SQL Editor:

```sql
drop extension pg_graphql;
```

Or in the dashboard: **Database → Extensions**, search for `pg_graphql`, and toggle it off.

If your project does use `pg_graphql`, leave it installed and follow the remediation below.

---

### Rationale

`pg_graphql` introspection runs under whichever role the caller's JWT claims, not specifically `anon`. A request with the public anon key runs as `anon`; a request with a real user JWT runs as `authenticated`. The introspection response reflects the privileges of that role.

That makes the documented remediation for 0026 — "revoke from `anon`, grant to `authenticated`" — incomplete on its own. Because the two roles share identical default-privilege grants, an operator who follows the 0026 doc verbatim can clear that lint and still see the `/graphql/v1` introspection response served to any signed-up user remain byte-for-byte unchanged. Lint 0027 catches that case: it fires whenever `authenticated` has `SELECT` on a relation that `pg_graphql` would expose.

The relkinds covered match `pg_graphql`'s own filter (`load_sql_context.sql:395-400`): regular tables (`r`), views (`v`), materialized views (`m`), and foreign tables (`f`). Partitioned table roots (`relkind='p'`) are not covered because `pg_graphql` does not expose them via introspection; their leaf partitions (`relkind='r'`) are still picked up individually.

You can confirm what is visible to authenticated users by repeating the introspection request with a real user JWT in the `Authorization` header:

```bash
curl -X POST https://<PROJECT_REF>.supabase.co/graphql/v1 \
  -H 'apiKey: <ANON_KEY>' \
  -H 'Authorization: Bearer <USER_JWT>' \
  -H 'Content-Type: application/json' \
  --data-raw '{"query": "{ __schema { types { name fields { name } } } }"}'
```

### How to Resolve

The fix is a standard Postgres `GRANT` / `REVOKE`. Unlike 0026, you cannot simply revoke from `authenticated` — your app probably needs `authenticated` to read most tables. The right move is per-relation: keep grants on the tables signed-up users genuinely need, and revoke from the rest.

**Option 1: Audit and revoke per-relation (recommended)**

```sql
-- A relation that should never be visible to signed-up users:
revoke all on public.internal_api_keys from authenticated, anon, public;

-- A relation that signed-up users do need; introspection visibility is
-- intentional and the lint can be ignored for this object:
grant select on public.profiles to authenticated;
```

Walk the 0027 findings list; for each relation, decide whether `authenticated` visibility is intentional. If it is, suppress the finding for that object. If it is not, revoke.

**Option 2: Hide every table from both roles, re-grant only what is needed**

```sql
revoke all on all tables in schema public from anon, authenticated;

alter default privileges in schema public
  revoke select on tables from anon, authenticated;

-- Re-grant per-relation only where genuinely required:
grant select on public.profiles to authenticated;
grant select on public.products to authenticated;
grant select, insert on public.orders to authenticated;
```

This pairs cleanly with 0026's Option 1 and is the cleanest end state for projects that want introspection to expose only an explicit allowlist.

**Option 3: Block the entire GraphQL endpoint for both roles**

```sql
revoke all on function graphql.resolve from anon, authenticated;
```

This rejects every GraphQL request, not just introspection. Use only if you do not use the `/graphql/v1` endpoint at all. The table-level revokes above are usually preferable because they keep the endpoint alive while returning an empty schema.

### Example

Given a table that signed-up users should not be able to see in introspection:

```sql
create table public.internal_api_keys(
    id uuid primary key,
    service text,
    key_hash text,
    permissions jsonb
);

alter table public.internal_api_keys enable row level security;
-- No policies, but `authenticated` still inherits the default SELECT
-- grant — every signed-up user sees the column list via introspection.
```

Lint 0027 fires for `public.internal_api_keys`. Fix:

```sql
revoke all on public.internal_api_keys from authenticated, anon, public;
```

The introspection query no longer returns this table for any role. (If 0026 was also firing for this table, the same revoke clears it.)

### Verifying the Fix

After applying the revoke, repeat the introspection query with a real user JWT and confirm the relation is no longer in the response:

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
| Hide one table from `authenticated` | `revoke all on public.secret_table from authenticated, public;` |
| Hide all tables from `authenticated` | `revoke all on all tables in schema public from authenticated;` |
| Prevent future auto-grants | `alter default privileges in schema public revoke select on tables from authenticated;` |
| Hide one table from both roles | `revoke all on public.secret_table from anon, authenticated, public;` |
| Kill GraphQL endpoint for both roles | `revoke all on function graphql.resolve from anon, authenticated;` |

### False Positives

This lint flags every `authenticated`-readable relation when `pg_graphql` is installed. The majority of findings are usually intentional — most app-facing tables genuinely need to be readable by signed-up users, and exposing their column names through introspection is acceptable.

If introspection visibility is intentional for a relation, the lint can be safely ignored for that object. The lint is informational: it surfaces what your project makes visible to authenticated users so you can decide which relations are actually meant to be discoverable by every account holder, including throwaway accounts created via open signup.
