**Level:** WARN

**Summary:** Detects `SECURITY DEFINER` functions that compare `current_user`, `current_role` or `user`.

**Ramification:** Inside a `SECURITY DEFINER` function these values are the function owner, not the caller. An authorization check built on them gives the same answer for every caller, so it either lets everyone through or blocks everyone.

---

### Rationale

`SECURITY DEFINER` functions run with the privileges of their owner, and `current_user` reflects that: it is the owner for the whole call. Code written as if it were the caller, such as `if current_user <> 'admin' then raise exception ...`, is decided by who owns the function.

`session_user` is not a replacement. Through the Supabase Data API it is the connection role (`authenticator`), not the signed-in user.

### How to Resolve

Identify the caller from the request JWT:

```sql
-- caller's user id
auth.uid()
-- caller's role claim: anon, authenticated, service_role
auth.role()
-- any other claim
(select auth.jwt() ->> 'email')
```

Or make the function `SECURITY INVOKER` so that `current_user` is the caller, and let RLS and grants decide what the caller may do.

### Example

Given this problematic configuration:

```sql
create function public.delete_everything() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if current_user <> 'admin_role' then
    raise exception 'not allowed';
  end if;
  delete from public.items;
end
$$;
```

`current_user` is the owner, so the check never reflects the caller. Fix:

```sql
create or replace function public.delete_everything() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.role()) <> 'service_role' then
    raise exception 'not allowed';
  end if;
  delete from public.items;
end
$$;
```

### How the Lint Matches

The lint reads the function source as text, so it is intentionally narrow:

- Comments, quoted identifiers and string literals are ignored.
- Qualified names (`t.user`) and longer identifiers (`user_id`) are ignored.
- Only comparisons (`=`, `<>`, `!=`, `in`, `any`, `like`, `is distinct from`) and arguments to `pg_has_role` and `has_*_privilege` count. Reading the value, for example to store it in an audit column, does not.
- Functions that run `SET ROLE` or `SET SESSION AUTHORIZATION` are skipped.
- Only SQL and PL/pgSQL functions in exposed schemas are examined.

### False Positives

- A function that deliberately checks its owner, for example to refuse running under an unexpected owner. Ignore the finding.
- Dynamic SQL built from strings is not inspected, so some real uses are missed.
