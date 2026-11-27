**Level:** WARN

**Summary:** An RLS policy applies to the `anon` role, directly or through `public`.

**Ramification:** `anon` is the role used for signed-out requests and for any JWT that has no `role` claim, such as an OIDC ID token issued to an OAuth client. A policy that applies to `anon` and relies on `auth.uid()` or `auth.jwt()` can therefore grant access to a token that was never meant to reach your data API or Storage.

---

### Rationale

PostgREST and Storage run a request as the role named in the JWT `role` claim and fall back to `anon` when the claim is missing. Tokens that carry a `sub` but no `role` therefore run as `anon`, and `auth.uid()` still returns the `sub`.

A policy with no `TO` clause applies to `public`, which includes `anon`. Writing `for all using (owner_id = auth.uid())` without `to authenticated` looks like a signed-in-only rule, but it also applies to `anon`. Identity-based policies should never rely on `anon`.

### What is flagged

A permissive policy on a table is flagged when it applies to `anon`:

- the policy names `anon` explicitly (`TO anon`),
- the policy has no `TO` clause or uses `TO public`, or
- the policy names a role that `anon` is a member of.

Policies on `storage.objects` and `realtime.messages` are included.

Two kinds of policy are not flagged:

- restrictive policies (`AS RESTRICTIVE`), which can only narrow access, and
- `SELECT` policies whose expression is a literal `true`, which is the usual deliberate public-read pattern.

Every other `SELECT` policy that applies to `anon` is flagged, whether or not it uses `auth.` functions. That includes plain column checks such as `using (published)`, comparisons with constants, and `current_setting(...)` expressions. Policies for `INSERT`, `UPDATE`, `DELETE` and `ALL` are always flagged when they apply to `anon`.

### How to Resolve

**Option 1: Scope the policy to signed-in users**

```sql
drop policy "own_rows" on public.docs;

create policy "own_rows" on public.docs
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
```

**Option 2: Keep the policy for several roles and check the role explicitly**

```sql
using (
  (select auth.role()) = 'authenticated'
  and owner_id = (select auth.uid())
)
```

### Example

Given this problematic configuration:

```sql
create policy "folder_is_uid" on storage.objects
  for all
  using (
    bucket_id = 'files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
```

Fix:

```sql
drop policy "folder_is_uid" on storage.objects;

create policy "folder_is_uid" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'files'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
```

### False Positives

- Public-read policies that are more than a literal `true`, for example `using (published)`. Add `TO anon` only if you intend public access, and dismiss the finding for that object.
- Policies that are deliberately open to signed-out users and also check identity, for example one that lets anyone read published rows and owners read their own drafts. Dismiss the finding for that object, or split it into a `TO anon` policy without the identity check and a `TO authenticated` policy with it.
- Policies that already check the role with `auth.role()` or `auth.jwt() ->> 'role'` but have no `TO` clause are still flagged. Adding `TO authenticated` makes the intent explicit and clears the finding.

### Limitations

- The lint does not look inside expressions, so any expression other than a literal `true` is flagged, including ones that already restrict access to signed-in users.
- The lint does not check table grants. A policy that applies to `anon` is reported even if `anon` has no privilege on the table, because a later `GRANT` activates it.

See also lint [0024_permissive_rls_policy](0024_permissive_rls_policy.md) for policies that are always true.
