**Level:** INFO

**Summary:** An RLS policy targets `anon` or `authenticated`, but that role has no privilege on the table for the policy's command.

**Ramification:** The policy never takes effect. Requests through the Data API fail with `permission denied for table` instead of being filtered by the policy.

---

### Rationale

Postgres checks table privileges before it evaluates Row Level Security. A role needs both:

1. the table privilege for the command (`SELECT`, `INSERT`, `UPDATE`, or `DELETE`), granted with `GRANT`, and
2. a permissive RLS policy that allows the row.

If the privilege is missing, the query is rejected before any policy runs, so a policy such as:

```sql
create policy "insert_own"
on public.posts
for insert
to authenticated
with check (user_id = auth.uid());
```

has no effect unless `authenticated` also has `INSERT` on `public.posts`.

Previously, Supabase projects granted `SELECT`, `INSERT`, `UPDATE`, and `DELETE` on every new table in the `public` schema to `anon` and `authenticated` by default, so this rarely came up. Projects created since 2026-05-30, and all projects from 2026-10-30, no longer get these grants automatically on new tables ([changelog](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically)). A migration that creates a table and its policies without matching `GRANT` statements produces exactly this pattern.

### What is checked

The lint only looks at tables that have RLS enabled, in schemas exposed through the Data API (`pgrst.db_schemas`, defaulting to `public`). For each permissive policy:

- **Policy targets `anon` and/or `authenticated`:** flagged if any targeted role lacks the privilege matching the policy's command.
- **Policy targets `public` (no `TO` clause):** flagged only if neither `anon` nor `authenticated` holds the privilege. It is common for such a policy to be meant for signed-in users only.
- **`FOR ALL` policies:** flagged only if the role holds none of `SELECT`, `INSERT`, `UPDATE`, or `DELETE`.

Privileges inherited from role membership or granted to `PUBLIC` count, and so do column-level grants (for example `grant update (title) on public.posts to authenticated`).

Restrictive policies are not checked. Without the privilege the role is already denied, which is what a restrictive policy is for.

### How to Resolve

If the policy is meant to be used, grant the matching privilege to the role:

```sql
grant insert on public.posts to authenticated;
```

If the policy is left over and the role should not have access, drop it so the table's access rules are easier to read:

```sql
drop policy "insert_own" on public.posts;
```

### False Positives

- **Intentionally disabled access:** privileges were revoked on purpose to block a role temporarily, and the policy was kept for later. Consider dropping the policy instead, or ignore the lint for that table.
