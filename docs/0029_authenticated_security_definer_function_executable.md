
**Level:** WARN

**Summary:** This `SECURITY DEFINER` function is callable by signed-in users.

**Ramification:** Because this function is `SECURITY DEFINER`, it runs with the privileges of its owner rather than the caller. If `authenticated` has `EXECUTE`, any signed-in user can call it through `POST /rest/v1/rpc/<name>` and potentially read or modify data that RLS would normally block. In projects with open signup, that can mean any throwaway account, so revoke `EXECUTE`, switch the function to `SECURITY INVOKER`, or move it out of your exposed API schema if every account holder should not be able to call it.

> **See also: lint [0028_anon_security_definer_function_executable](0028_anon_security_definer_function_executable.md).** The two checks are paired — revoking from one role alone usually leaves the other side callable. Address findings from both lints together. The `pg_graphql_*` lints (0026/0027) cover the parallel risk for tables/views.

---

### If you are not using `pg_graphql`, disable it

Disabling `pg_graphql` closes the `/graphql/v1` Query/Mutation surface, which is one of two ways this function is reachable. **The function is still callable via PostgREST `/rest/v1/rpc/<name>`** — so this lint will continue to fire after the drop, and the remediation below is still required. Disable `pg_graphql` only if your app does not use the GraphQL endpoint; do not treat it as a fix for this lint.

In the Supabase SQL Editor:

```sql
drop extension pg_graphql;
```

Or in the dashboard: **Database → Extensions**, search for `pg_graphql`, and toggle it off.

---

### Rationale

Two facts combine to make this a high-impact misconfiguration:

1. **`SECURITY DEFINER` bypasses RLS.** When a function is declared `SECURITY DEFINER`, it executes with the role of its owner, not the caller. The owner is usually a privileged role created by Supabase (for example `postgres` or `supabase_admin`) which can read every row in every RLS-protected table. So calling the function returns rows that the caller — `authenticated` — could never read with a direct `SELECT`.

2. **Postgres' default function ACL is `EXECUTE` to `PUBLIC`**, and Supabase additionally grants default privileges for new functions to `anon, authenticated, service_role`. So a function created in `public` is, by default, executable by `authenticated`. The author has to actively revoke to remove that grant.

The result: a developer writes a helper function intending it to be called from an admin script, doesn't think about the API surface, and the function becomes an exfiltration endpoint for any signed-up user. PostgREST exposes it at `/rest/v1/rpc/<name>` automatically; pg_graphql exposes it as a query or mutation field if the return type is supported. The function does not need to appear anywhere in the documented API for the call to work — `/rest/v1/rpc` accepts any function name the role has `EXECUTE` on. Because Supabase signup is often open or email-auto-confirm, the audience for `authenticated` is effectively the public internet.

This lint deliberately ignores `SECURITY INVOKER` functions: those run as the caller, so RLS still applies to any tables they touch. They can still be problematic if the *underlying* tables are unprotected, but that risk is covered by lints `0008_rls_enabled_no_policy` and `0013_rls_disabled_in_public` on the data, not by this lint on the function.

### How to Resolve

The fix is per-function. For each finding, decide whether `authenticated` should genuinely be able to invoke the operation, then take one of three paths:

**Option 1: Revoke `EXECUTE` (most common)**

```sql
revoke execute on function public.my_priv_op(int, text) from authenticated, anon, public;
```

Revoke from `PUBLIC` as well, because Postgres' default-grant lives there. Revoking from `anon` at the same time also clears the matching 0028 finding.

**Option 2: Keep the function exposed but switch to `SECURITY INVOKER`**

```sql
alter function public.my_priv_op(int, text) security invoker;
```

The function still runs, but it now executes as the caller. RLS on the underlying tables takes effect, and the operator can model access through policies instead of through an unrestricted `EXECUTE`. Suitable when the function does not actually need to bypass RLS — it was just declared `SECURITY DEFINER` by habit or default.

**Option 3: Keep both `SECURITY DEFINER` and the `EXECUTE` grant — intentional**

Some functions are deliberately exposed to signed-up users: a "create my profile" function that initialises rows the user cannot otherwise insert, a "submit feedback" function that writes to a table they cannot otherwise write to, etc. If the lint flags one of these, the finding is intentional and can be suppressed for that object. The function should validate inputs and limit what it does — a `SECURITY DEFINER` exposed to `authenticated` is effectively a public API endpoint to anyone who can sign up.

### Identifying the Owner

To see who the function actually runs as (this is what determines what RLS it bypasses):

```sql
select
    p.proname,
    pg_get_function_identity_arguments(p.oid) as args,
    pg_catalog.pg_get_userbyid(p.proowner) as owner,
    p.prosecdef as security_definer
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
order by p.proname;
```

If the owner is a high-privilege role, the function can read and write everything that role can.

### Quick Reference

| Goal | SQL |
|------|-----|
| Hide one function from `authenticated` | `revoke execute on function public.f(int) from authenticated, public;` |
| Hide one function from both roles | `revoke execute on function public.f(int) from anon, authenticated, public;` |
| Hide all functions in a schema from `authenticated` | `revoke execute on all functions in schema public from authenticated;` |
| Prevent future auto-grants of EXECUTE | `alter default privileges in schema public revoke execute on functions from anon, authenticated, public;` |
| Switch a function to caller's privileges | `alter function public.f(int) security invoker;` |

### False Positives

This lint flags every `SECURITY DEFINER` function in a user schema with `EXECUTE` granted to `authenticated`. There are two situations where the finding is not a real risk:

- **The function is intentionally a per-user privileged operation.** A "register my account profile" or "submit feedback as me" function may be `SECURITY DEFINER` (so it can write to a table `authenticated` cannot otherwise write to) and meant to be executable by every signed-up user. Confirm the function validates input and limits what it does, then suppress.
- **The owner is a low-privilege role.** If the function's owner has no more privileges than the caller, `SECURITY DEFINER` does not actually escalate. This is rare because Supabase functions are typically owned by a privileged role, but worth checking the owner column shown above.

In every other case the lint is reporting a real privilege escalation: any signed-up user — including throwaway accounts created via open signup — can run code that reads or writes data they otherwise could not.
