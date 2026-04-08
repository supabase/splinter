begin;
  set local search_path = '';

  -- BASELINE: 0 issues before storage is installed
  select * from lint."0025_public_bucket_allows_listing";

  create schema storage;

  create table storage.buckets(
    id text primary key,
    name text not null,
    public boolean not null default false
  );

  create table storage.objects(
    bucket_id text not null,
    name text not null
  );

  alter table storage.objects enable row level security;

  savepoint a;

  -- NEGATIVE EXAMPLE: a public bucket without a matching SELECT policy should not fire
  -- Public buckets can rely on object URLs alone, and INSERT policies do not make contents listable
  insert into storage.buckets(id, name, public)
  values ('public-without-policy', 'Public without policy', true);

  create policy "public_without_policy_insert"
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id = 'public-without-policy');

  select * from lint."0025_public_bucket_allows_listing";

  rollback to savepoint a;

  savepoint b;

  -- POSITIVE EXAMPLE: a public bucket with a matching SELECT policy should fire once
  -- The SELECT policy references the public bucket directly, so clients can list its contents
  insert into storage.buckets(id, name, public)
  values ('listable.bucket+1', 'Listable bucket', true);

  create policy "listable_bucket_select"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'listable.bucket+1');

  select
    name,
    metadata->>'bucket_id' as bucket_id,
    metadata->>'bucket_name' as bucket_name,
    metadata->>'policy_count' as policy_count,
    metadata->'policy_names' as policy_names,
    cache_key
  from lint."0025_public_bucket_allows_listing";

  -- RESOLUTION: removing the unnecessary SELECT policy should clear the lint
  drop policy "listable_bucket_select" on storage.objects;

  select * from lint."0025_public_bucket_allows_listing";

  rollback to savepoint b;

  savepoint c;

  -- MULTIPLE POLICIES: the bucket should still produce a single lint with aggregated metadata
  -- Both SELECT policies target the same public bucket, so the lint should collapse them into one result
  insert into storage.buckets(id, name, public)
  values ('multi-policy-bucket', 'Multi policy bucket', true);

  create policy "bucket_listing_policy_a"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'multi-policy-bucket');

  create policy "bucket_listing_policy_b"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'multi-policy-bucket' and name like 'public/%');

  select
    metadata->>'bucket_id' as bucket_id,
    metadata->>'policy_count' as policy_count,
    metadata->'policy_names' as policy_names
  from lint."0025_public_bucket_allows_listing";

  rollback to savepoint c;

  savepoint d;

  -- PRIVATE BUCKET: matching SELECT policy text alone should not fire
  -- Private buckets are out of scope for this lint even when the policy text looks similar
  insert into storage.buckets(id, name, public)
  values ('private-bucket', 'Private bucket', false);

  create policy "private_bucket_select"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'private-bucket');

  select * from lint."0025_public_bucket_allows_listing";

  rollback to savepoint d;

  savepoint e;

  -- MULTIPLE AFFECTED BUCKETS: each affected public bucket should produce its own lint
  -- Two public buckets each have their own matching SELECT policy, so the lint should emit one row per bucket
  insert into storage.buckets(id, name, public)
  values
    ('alpha-bucket', 'Alpha bucket', true),
    ('omega-bucket', 'Omega bucket', true);

  create policy "alpha_bucket_select"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'alpha-bucket');

  create policy "omega_bucket_select"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'omega-bucket');

  select
    metadata->>'bucket_id' as bucket_id,
    cache_key
  from lint."0025_public_bucket_allows_listing";

  rollback to savepoint e;

rollback;
