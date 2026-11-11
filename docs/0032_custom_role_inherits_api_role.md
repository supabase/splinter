**Level:** WARN

**Summary:** Detects custom roles that are members of the `anon` or `authenticated` roles.

**Ramification:** The member inherits every privilege held by the API role: table access, `EXECUTE` on functions, and RLS policies written `TO anon` or `TO authenticated`. Every future grant to the API role widens the member too, and a role meant to be narrow quietly becomes as powerful as the public API.

---

### Rationale

Role membership is how Postgres shares privileges. Granting `authenticated` to a custom role means the custom role can do whatever `authenticated` can, now and later. The membership also defeats any restriction placed on the member, because the inherited privileges apply beneath it.

Platform roles hold these memberships on purpose, so they are not reported. On a stock Supabase database the only members of `anon` and `authenticated` are `authenticator` (which PostgREST connects as and switches into the API role) and `postgres`. The `supabase_*` roles and built-in `pg_*` roles are excluded as well.

### How to Resolve

**Option 1: Revoke the membership and grant the member only what it needs**

```sql
revoke authenticated from report_role;
grant select on public.reports to report_role;
```

**Option 2: Create a separate role for the access pattern**

Give the custom role its own explicit grants instead of borrowing an API role's.

### Example

Given this problematic configuration:

```sql
create role report_role login;
grant authenticated to report_role;
```

Fix:

```sql
revoke authenticated from report_role;
grant usage on schema public to report_role;
grant select on public.reports to report_role;
```

### False Positives

- Projects that run signed-in requests as their own PostgREST role often make that role a member of `authenticated` on purpose, so that existing policies and grants continue to apply. If that is your design, the finding is expected. Keep the role's own grants minimal and ignore the finding.
- Only direct memberships are reported. A role that reaches `anon` or `authenticated` through another role is not listed.
