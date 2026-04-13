create view lint."0025_public_bucket_allows_listing" as

with storage_bucket_table as (
    select
        1
    from
        pg_catalog.pg_class c
        join pg_catalog.pg_namespace n
            on c.relnamespace = n.oid
    where
        n.nspname = 'storage'
        and c.relname = 'buckets'
        and c.relkind in ('r', 'p')
),
public_buckets as (
    -- Read storage.buckets at runtime so the lint can load even when storage is not installed.
    select
        bucket_id,
        bucket_name
    from
        (
            select
                (xpath('/row/id/text()', bucket_xml))[1]::text as bucket_id,
                (xpath('/row/name/text()', bucket_xml))[1]::text as bucket_name
            from
                storage_bucket_table
        cross join lateral unnest(
            xpath(
                '/table/row',
                pg_catalog.query_to_xml(
                    'select id, name from storage.buckets where public = true order by id',
                    false,
                    false,
                    ''
                )
            )
        ) as bucket_rows(bucket_xml)
        ) public_bucket_rows
),
matching_policies as (
    select
        b.bucket_id,
        b.bucket_name,
        p.policyname
    from
        public_buckets b
        join pg_catalog.pg_policies p
            on p.schemaname = 'storage'
            and p.tablename = 'objects'
            and p.cmd in ('SELECT', 'ALL')
            and p.permissive = 'PERMISSIVE'
            and p.roles && array['public'::name, 'anon'::name, 'authenticated'::name]
    where
        (
            p.qual is null
            or replace(replace(replace(lower(p.qual), ' ', ''), E'\n', ''), E'\t', '')
                in ('true', '(true)', '1=1', '(1=1)')
            or exists (
                select
                    1
                from
                    pg_catalog.regexp_match(
                        p.qual,
                        $re$\A\s*\(*\s*bucket_id\s*=\s*('(?:[^']|'')*')(\s*::\s*[[:alnum:]_\.]+)?\s*\)*\s*\Z$re$,
                        'i'
                    ) as bucket_match(matches)
                where
                    bucket_match.matches[1] = '''' || replace(b.bucket_id, '''', '''''') || ''''
            )
        )
),
affected_buckets as (
    select
        bucket_id,
        bucket_name,
        array_agg(policyname order by policyname) as policy_names,
        count(*)::int as policy_count
    from
        matching_policies
    group by
        bucket_id,
        bucket_name
)
select
    'public_bucket_allows_listing' as name,
    'Public Bucket Allows Listing' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    'Detects public storage buckets with a broad SELECT policy on `storage.objects`, which allows clients to list all files in the bucket.' as description,
    format(
        'Public bucket `%s` has %s broad SELECT %s on `storage.objects` (%s), allowing clients to list all files. Public buckets don''t need this for object URL access and it may expose more data than intended.',
        bucket_name,
        policy_count,
        case
            when policy_count = 1 then 'policy'
            else 'policies'
        end,
        array_to_string(policy_names, ', ')
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0025_public_bucket_allows_listing' as remediation,
    jsonb_build_object(
        'schema', 'storage',
        'name', bucket_name,
        'type', 'bucket',
        'bucket_id', bucket_id,
        'bucket_name', bucket_name,
        'policy_names', policy_names,
        'policy_count', policy_count
    ) as metadata,
    format('public_bucket_allows_listing_%s', bucket_id) as cache_key
from
    affected_buckets
order by
    bucket_id;
