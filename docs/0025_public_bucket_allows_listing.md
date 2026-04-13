**Level:** WARN

**Summary:** Detects public storage buckets whose broad `SELECT` policies on `storage.objects` make their contents listable.

**Ramification:** Clients can enumerate the files in a public bucket, which often exposes more information than intended even though public object URLs would still work without the policy.

---

### Rationale

Supabase public buckets are already readable by URL. They do not need a `SELECT` policy on `storage.objects` for clients to fetch known object paths.

The footgun appears when a public bucket also has one or more broad permissive `SELECT` or `ALL` policies on `storage.objects`, for example `bucket_id = 'avatars'` or `true`. That combination allows API clients to list objects in the bucket through Storage APIs, which is often broader access than the project intended.

This lint is intentionally narrow. It does not warn on all public buckets. It only warns when a public bucket also has a matching `SELECT` policy that makes its contents enumerable.

### How to Resolve

**Option 1: Remove the unnecessary `SELECT` policy**

```sql
drop policy if exists "Public bucket listing" on storage.objects;
```

Object URLs for the public bucket will continue to work after removing the `SELECT` policy.

**Option 2: Make the bucket private if listing is actually required**

```sql
update storage.buckets
set public = false
where id = 'avatars';
```

Use private bucket access patterns if the project truly needs authenticated listing behavior.

### Example

Given this problematic configuration:

```sql
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true);

create policy "Public bucket listing"
on storage.objects
for select
to authenticated
using (bucket_id = 'avatars');
```

Fix:

```sql
drop policy if exists "Public bucket listing" on storage.objects;
```

### False Positives

This lint may fire when broad bucket listing is intentional for a public bucket. In that case, keep the policy and handle the warning as an accepted risk.

The lint is also intentionally conservative. It detects broad permissive policies for the `public`, `anon`, or `authenticated` roles with direct bucket-only `bucket_id = '<bucket id>'` matches or always-true policy expressions such as `true` or `1 = 1`. It does not warn on restrictive-only policies or policies that add additional object, path, or user constraints such as `bucket_id = 'avatars' and owner = auth.uid()`.
