
**Level:** WARN

**Summary:** Default privileges grant every future table to `anon`, `authenticated` or `PUBLIC`.

**Ramification:** Since October 30, 2026, new tables are not exposed to the Data API until you `grant` them. A default-privileges entry like this brings back automatic exposure for every table its owner creates. Nothing leaks because of it today, but the next table created without `enable row level security` can be read (and, with write privileges, changed) with the public anon key as soon as it exists.

---

### Rationale

On October 30, 2026 Supabase stopped exposing new tables in `public` to the Data API by default. Before, default privileges granted `select`, `insert`, `update` and `delete` on every new table to `anon`, `authenticated` and `service_role`, so a table was reachable through PostgREST and pg_graphql the moment it was created, protected or not. After the change, each table needs an explicit `grant`, which keeps access a reviewable, per-table decision.

The first sign of the change is usually a `42501 permission denied for table` error. A common way to make it go away is to put the old behavior back:

```sql
alter default privileges in schema public
  grant select, insert, update, delete on tables to anon, authenticated;
```

That silences the error for every future table at once, and with it the safety net the change added: a table created by a migration, the SQL editor, the Management API or an AI tool is exposed before anyone has enabled RLS or written a policy.

The lint reports one row per owner role and schema (or one row for an entry without `in schema`, which applies to every schema). It only looks at table defaults (`on tables`): sequences and functions are out of scope. Entries owned by platform roles (`supabase_*`, `pg_*`) are skipped because the project owner can't change them. Entries that only grant to `service_role` are not reported.

### How to Resolve

**Option 1: Revoke the default privileges and grant per table (recommended)**

Use the owner and schema from the finding:

```sql
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated, public;
```

Then grant each table in the migration that creates it, next to its RLS policies, and only the privileges each role needs:

```sql
create table public.notes (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid(),
  body text
);
alter table public.notes enable row level security;

grant select, insert, update, delete on public.notes to authenticated;

create policy "own notes" on public.notes
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
```

Revoking default privileges does not change tables that already exist: they keep the grants they have.

**Option 2: Keep the defaults, with a guarantee that RLS is always on**

If you keep the defaults on purpose, make sure every table in the exposed schemas gets RLS when it is created, for example with an event trigger, and watch lints `0013_rls_disabled_in_public` and `0008_rls_enabled_no_policy`. Without that guarantee, keeping the defaults is exactly the exposure the October 30 change removed.

### Example

The quick fix after the first 42501:

```sql
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to anon, authenticated;
```

Fix:

```sql
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;

grant select on public.your_table to authenticated;
```

### False Positives

A project that deliberately exposes every new table, and enforces RLS on creation some other way, can treat this finding as accepted. A default that grants only to `service_role` is never reported.
