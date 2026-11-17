
**Level:** WARN

**Summary:** Security policy allows unrestricted access

**Ramification:** An RLS policy uses an always-true condition like `USING (true)`, which defeats the purpose of having Row-Level Security enabled.

---

### Rationale

Row Level Security (RLS) policies that use always-true expressions like `USING (true)` or `WITH CHECK (true)` effectively bypass the security that RLS is meant to provide. While RLS appears to be enabled on the table, these permissive policies allow unrestricted access to all rows for the specified roles.

This is a common misconfiguration that occurs when:
- Developers create placeholder policies during development and forget to update them
- Policies are incorrectly configured with the assumption that other policies will restrict access
- Copy-paste errors from documentation examples

### Patterns Detected

The lint identifies policies with these always-true patterns:

**USING Clause (controls which rows can be read):**
- `USING (true)` - explicitly allows reading all rows
- `USING (1=1)` - tautology that always evaluates to true

`SELECT` policies with `USING (true)` are not flagged, because public read access is often intentional. The exception is a `SELECT` policy whose name says it is limited to the row owner or a role (see below).

**WITH CHECK Clause (controls which rows can be written):**
- `WITH CHECK (true)` - allows writing any row
- `WITH CHECK (1=1)` - tautology that always evaluates to true
- Missing WITH CHECK clause on permissive INSERT/UPDATE policies

### Security Impact

When a permissive policy with `USING (true)` exists:
- **For SELECT**: Any user with the specified role can read ALL rows in the table
- **For INSERT**: Any user can insert ANY data into the table
- **For UPDATE**: Any user can modify ANY row in the table
- **For DELETE**: Any user can delete ANY row from the table

This is particularly dangerous when the policy applies to `anon` or `authenticated` roles, as it exposes data to all API users.

### Policy Names That Claim Ownership

A policy name is what people read when they review RLS. Postgres only enforces the expression. A policy like this looks correct in a list of policies, but returns every row to every signed in user:

```sql
create policy "Users can view their own posts"
on public.posts
for select
to authenticated
using (true);
```

A policy name counts as claiming scope when it contains one of these (matched as whole words, case-insensitive, with `_`, `-` and other punctuation treated as spaces):

- `own` or `their`, e.g. "Users can view their own posts", "select_own_posts"
- `only owner`, `only owners`, `only the owner`, `only the owners`
- `for owner`, `for owners`, `for the owner`, `for the owners`
- `owner can`, `owners can`, `owner only`, `owners only`
- `admin` or `admins` followed by `can`, `only`, `read`, `reads`, `view`, `views`, `see`, `sees`, `manage`, `manages`, `select`, `insert`, `update` or `delete`, e.g. "Admin reads all activity", "admin_select_responses"
- `only admin`, `only admins`
- `for admin` or `for admins` at the very end of the name, e.g. "Allow authenticated read for admin" (but not "... for admin reports")
- `service role`

A bare `owner` or `admin` is not enough, because it often names the table's contents ("Allow reading admin users", "Public can view vehicle owners"). A name that contains `public`, `everyone` or `anyone` never counts as claiming scope.

These are English-name heuristics, so some names that do claim scope are not matched:

- a name that also says `public`, `everyone` or `anyone`, e.g. "Anyone can read own payments by phone", or one where `public` is part of a table name, e.g. "Users can view own public_profiles"
- camelCase names, e.g. "usersViewOwnPosts"
- names in other languages

For a policy name that claims scope, the lint:

- flags a `SELECT` policy with an always-true `USING` clause, which it would otherwise skip
- adds a note to the detail message of any flagged policy where nothing in the policy checks the caller

A policy for the `service_role` is not needed at all, because the `service_role` bypasses RLS. A policy named after it applies to the roles in its `to` clause, and to every role when `to` is left out.

### How to Resolve

**Option 1: Add proper row-level conditions**

Replace the permissive policy with one that properly restricts access:

```sql
-- Instead of: USING (true)
-- Use a proper condition:
drop policy "allow_all" on public.posts;

create policy "users_own_posts"
on public.posts
for select
using (auth.uid() = user_id);
```

**Option 2: Use restrictive policies in combination**

If you need a base permissive policy, combine it with restrictive policies:

```sql
-- Base permissive policy
create policy "authenticated_access"
on public.posts
for select
to authenticated
using (true);

-- Restrictive policy to limit access
create policy "only_published"
on public.posts
as restrictive
for select
to authenticated
using (status = 'published' or auth.uid() = user_id);
```

**Option 3: Remove the policy if RLS is not needed**

If you don't need row-level restrictions, consider whether RLS should be disabled:

```sql
drop policy "allow_all" on public.posts;
alter table public.posts disable row level security;
```

Note: Only disable RLS if you're certain the table should be fully accessible.

### Example

Given this problematic configuration:

```sql
create table public.user_data(
    id uuid primary key,
    user_id uuid references auth.users(id),
    sensitive_info text
);

alter table public.user_data enable row level security;

-- This policy defeats the purpose of RLS!
create policy "allow_all_select"
on public.user_data
for select
to authenticated
using (true);
```

The `allow_all_select` policy allows ANY authenticated user to read ALL rows, including other users' sensitive information.

Fix by adding a proper condition:

```sql
drop policy "allow_all_select" on public.user_data;

create policy "users_own_data"
on public.user_data
for select
to authenticated
using (auth.uid() = user_id);
```

### False Positives

In some cases, `USING (true)` may be intentional:
- Public read-only tables (e.g., blog posts, product catalogs)
- Tables where access is controlled by other means (e.g., API layer)

If the policy is intentional, you can document why in a comment or consider suppressing this lint for specific tables.

If a `SELECT` policy is flagged only because of its name and the table really is public, rename the policy so the name matches what it does:

```sql
alter policy "Users can view their own posts" on public.posts rename to "Posts are viewable by everyone";
```
