
Level: WARN

### Impact

Security policy allows unrestricted access

#### Why it matters

An RLS policy uses an always-true condition like `USING (true)`, which defeats the purpose of having Row-Level Security enabled.

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
- `USING ('a'='a')` - string comparison tautology
- Missing USING clause on permissive SELECT policies

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
