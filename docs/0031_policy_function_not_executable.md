**Level:** ERROR

**Summary:** Detects RLS policies that call a function the policy's role is not allowed to execute.

**Ramification:** Every query by that role on the table fails with `permission denied for function`. This is a hard error, not a filtered result, so the table is unusable for that role until the privilege is restored.

---

### Rationale

A policy expression is evaluated with the privileges of the role running the query, not the policy owner. If the expression calls a function and that role has no `EXECUTE` privilege on it, Postgres raises an error instead of evaluating the policy.

This most often appears after a hardening change that revokes `EXECUTE` from a role without checking where the function is used. Searching application code or other function bodies does not find policy callers. Policy dependencies are visible in `pg_depend` and in `pg_policies.qual` / `pg_policies.with_check`.

A policy with no `TO` clause applies to `PUBLIC`. The lint checks the Supabase API roles `anon` and `authenticated` in that case.

### How to Resolve

**Option 1: Grant `EXECUTE` back to exactly the roles the policy applies to**

```sql
grant execute on function public.is_owner(uuid) to authenticated;
```

Do not grant to `PUBLIC` as a shortcut. Name the roles in the policy's `TO` clause.

**Option 2: Remove the function call from the policy**

Rewrite the policy so it no longer depends on the function, or apply the policy to a role that can execute it.

### Example

Given this problematic configuration:

```sql
create function public.is_owner(uid uuid) returns boolean
language sql stable as $$ select uid = auth.uid() $$;

revoke execute on function public.is_owner(uuid) from public;

create policy docs_select on public.docs
  for select to authenticated
  using (public.is_owner(owner_id));
```

Every `select` on `public.docs` by `authenticated` fails. Fix:

```sql
grant execute on function public.is_owner(uuid) to authenticated;
```

### False Positives

- **Policies on tables with RLS disabled** are not reported, because the policy is never evaluated.
- **Roles that never query the table.** A policy lists a role that never connects, for example a retired role. Drop the role from the policy if it is not needed.
- Only functions recorded as dependencies of the policy are checked. Built-in functions are not recorded and are always executable.
