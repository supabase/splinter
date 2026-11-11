**Level:** WARN

**Summary:** Detects column-level privileges for `anon` or `authenticated` that have no effect because the role also holds the same privilege on the whole table.

**Ramification:** The column grant looks like a restriction but is not one. The role can still read or write every column, including the ones the grant was meant to hide.

---

### Rationale

Postgres allows an operation if the role holds the privilege on the table or on the specific columns. A table-level `SELECT` covers every column, so a column-level `SELECT` on top of it adds nothing, and a column-level `REVOKE` cannot take away what the table-level grant gives.

This is easy to hit on Supabase. New tables in `public` can start with table-level grants to `anon` and `authenticated`, and a later `GRANT SELECT (a, b) ...` is meant to narrow that. It does not.

The lint reports a role that holds an entry for a privilege (`SELECT`, `INSERT`, `UPDATE` or `REFERENCES`) at column level and the same privilege at table level. Privileges inherited through role membership or granted to `PUBLIC` count as table-level.

### How to Resolve

Revoke the table-level privilege, then grant only the columns the role needs. Revoking at table level also clears the role's column-level entries of that kind, so grant the columns again afterwards:

```sql
revoke select on public.profiles from anon;
grant select (id, display_name) on public.profiles to anon;
```

If the privilege comes from `PUBLIC`, revoke it from `PUBLIC` instead:

```sql
revoke select on public.profiles from public;
```

If the role should see every column, drop the column-level grant, because it is redundant.

### Example

Given this problematic configuration:

```sql
grant select on public.profiles to anon;
grant select (id, display_name) on public.profiles to anon;
-- anon can still select email
```

Fix:

```sql
revoke select on public.profiles from anon;
grant select (id, display_name) on public.profiles to anon;
```

### False Positives

- Column grants left over from an earlier, stricter setup, while the table-level grant is intentional. Drop the column grant to silence the lint.
- Only `anon` and `authenticated` are examined.

### Limitation

A plain `REVOKE select (email) ON public.profiles FROM anon` against a table-level grant leaves no trace in the catalogue, because Postgres has nothing to remove. This lint cannot see that case. It only reports the column grants that were made alongside a table-level grant.
