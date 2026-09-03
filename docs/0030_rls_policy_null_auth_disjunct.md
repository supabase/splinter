**Level:** WARN

**Summary:** An RLS read policy is unconditionally true whenever an auth function returns NULL.

**Ramification:** A policy like `USING (auth.uid() IS NULL OR owner_id = auth.uid())` admits **every row** to any session where `auth.uid()` is NULL — the disjunct short-circuits the intended row scoping.

---

### Rationale

Row Level Security policies are easy to write so that they read like the correct sentence in English while evaluating to *true for every row* in a class of sessions.

The canonical shape is an `OR` whose first branch tests a nullable auth function for NULL:

```sql
using ( auth.uid() is null or owner_id = auth.uid() )
```

For any request where `auth.uid()` returns NULL, the `auth.uid() IS NULL` branch is `true`, the `OR` short-circuits, and the policy returns every row of the table — regardless of `owner_id`. The author almost always intended the negation (`auth.uid() IS NOT NULL AND owner_id = auth.uid()`) or simply the scoped predicate, and accidentally turned the policy into a no-op.

This is a **correctness** defect: the predicate is unconditionally true for the NULL-auth case whether or not anonymous access is otherwise intended. Its severity depends on which roles the policy applies to:

- For a policy granted to `public` / `anon`, an ordinary token-less request runs as a role the policy applies to **and** has `auth.uid()` NULL — so every row is readable by unauthenticated callers.
- For a policy granted only to `authenticated`, a token-less request runs as `anon` (which the policy does not apply to), so the exposure requires an `authenticated`-role session whose `sub` claim is NULL — a narrower, but still incorrect, case.

This lint complements `0024_rls_policy_always_true`: that lint matches a literal `USING (true)` (and only flags it for write commands); this one matches a predicate that is *true for NULL auth* and applies to reads.

The supported nullable auth functions are `auth.uid()`, `auth.jwt()`, `auth.role()`, and `current_setting(name, true)` (the two-argument, `missing_ok => true` form, which returns NULL when unset). The never-NULL identity functions (`current_user`, `session_user`, `current_role`) and the raising form `current_setting(name)` / `current_setting(name, false)` are deliberately **not** treated as nullable and do not trigger the lint.

### How to Resolve

**Option 1 (preferred): drop the `IS NULL` disjunct and keep the scoped predicate.**

```sql
alter policy "read own" on public.documents
  using ( owner_id = auth.uid() );
```

**Option 2: if both branches were intended, AND the auth check instead of OR-ing it.**

```sql
alter policy "read own" on public.documents
  using ( auth.uid() is not null and owner_id = auth.uid() );
```

### Example

Given this problematic configuration:

```sql
create policy "read own" on public.documents
  for select to authenticated
  using ( auth.uid() is null or owner_id = auth.uid() );
```

Fix:

```sql
create policy "read own" on public.documents
  for select to authenticated
  using ( owner_id = auth.uid() );
```

### False Positives

- A genuine intent to expose rows to NULL-auth sessions (rare) should be made explicit with a dedicated, documented policy rather than an `IS NULL` disjunct folded into a scoped check — allowlist it if so.
- The lint only inspects the *top-level* `OR` of the `USING` clause. A NULL-auth check that is gated by a top-level `AND` (e.g. `owner_id = auth.uid() AND (auth.uid() IS NULL OR is_public)`) is not unconditionally true and is **not** flagged.
- `current_setting(name)` / `current_setting(name, false)` raise an error when the setting is unset rather than returning NULL, so those disjuncts are not treated as a NULL bypass.
