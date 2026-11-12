**Level:** ERROR / WARN

**Summary:** This function is callable without signing in and appears to `EXECUTE` a SQL string passed in by the caller.

**Ramification:** The function is reachable through `POST /rest/v1/rpc/<name>`, so anyone with the public anon key can run arbitrary SQL through it. If the function is `SECURITY DEFINER` the SQL runs as the function owner and bypasses RLS (level `ERROR`). If it is `SECURITY INVOKER` the SQL runs as `anon` and is limited by that role's grants and RLS (level `WARN`). Either way the caller can read your schema and any data `anon` can reach. Revoke `EXECUTE`, or replace the function with fixed operations.

> **See also: lint [0032_authenticated_dynamic_sql_function_executable](0032_authenticated_dynamic_sql_function_executable.md).** It is the same check for signed-in users. Revoking from `anon` alone usually leaves the function callable by every signed-up user, so address both together. Lint [0028_anon_security_definer_function_executable](0028_anon_security_definer_function_executable.md) covers `SECURITY DEFINER` functions exposed to `anon` in general.

---

### Rationale

Helpers like `exec_sql(query text)` or `run_query(sql text)` let a client send SQL to the database and get the result back. Postgres grants `EXECUTE` on new functions to `PUBLIC`, and Supabase also grants it to `anon` and `authenticated`, so a function like this is callable by clients unless `EXECUTE` is revoked. Checking that the string starts with `select` does not make it safe.

This lint reads the function body, and only for PL/pgSQL functions in exposed schemas. A function is flagged when:

1. a `text` or `varchar` parameter is used inside an `EXECUTE` statement, or
2. a `text` or `varchar` parameter is named like SQL (`sql`, `query`, `stmt`, `statement`, `command`, `cmd`, ...) and the body contains an `EXECUTE` anywhere.

Parameters bound with `EXECUTE ... USING` and parameters wrapped in `quote_ident()`, `quote_literal()` or `quote_nullable()` are not counted.

### How to Resolve

**Option 1: Revoke `EXECUTE`**

```sql
revoke execute on function public.exec_sql(text) from anon, public;
```

**Option 2: Drop the function**

```sql
drop function public.exec_sql(text);
```

**Option 3: Replace it with fixed operations**

Expose one function per operation with typed arguments and no string-built SQL. If you have to build SQL, pass values with `EXECUTE ... USING`, quote identifiers with `quote_ident()`, and check table and column names against an allow-list.

### Example

Given this function:

```sql
create function public.exec_sql(query text) returns json
language plpgsql security definer as $$
declare r json;
begin
  execute 'select json_agg(t) from (' || query || ') t' into r;
  return r;
end $$;
```

Fix:

```sql
revoke execute on function public.exec_sql(text) from anon, authenticated, public;
```

### False Positives

- A `text` parameter used as an identifier through `format('%I', param)` is safe but can still be flagged. Use `quote_ident(param)` instead.
- A function that checks the string against a strict allow-list before running it. Confirm the allow-list is complete, then suppress the finding.
- Only PL/pgSQL bodies are inspected. Functions in other languages, or that build SQL in a helper function, are not detected.
