/*
auth.jwt() -> 'user_metadata' should not be referenced in a security context.

End users have control over the contents of `user_metadata` via
`updateUser({ data: { role: 'admin' } })` in the client libraries.

If a project creator is not aware that end users have control over the value, they
may have a security check like:

```
    auth.jwt() -> 'user_metadata' ->> 'role' = 'admin' 
```
which would be insecure.

NOTE:
    This lint requires search_path = '' or 'auth' not in search_path;
    because qual and with_check are dependent on search_path to determine if function calls include the "auth" schema
*/


create view lint."0015_rls_references_user_metadata" as

with policies as (
    select
        nsp.nspname as schema_,
        polrelid::regclass table_,
        polname as policy_name,
        qual,
        with_check
    from
        pg_catalog.pg_policy pa
        join pg_catalog.pg_class pc
            on pa.polrelid = pc.oid
        join pg_catalog.pg_namespace nsp
            on pc.relnamespace = nsp.oid
        join pg_catalog.pg_policies pb
            on pc.relname = pb.tablename
            and nsp.nspname = pb.schemaname
            and pa.polname = pb.policyname
)
select
    'rls_references_user_metadata' as name,
    'ERROR' as level,
    'EXTERNAL' as facing,
    'Detects when Supabase Auth user_metadata is referenced insecurely in a row level security (RLS) policy.' as description,
    format(
        'Table \`%s\` has a row level security policy \`%s\` that references Supabase Auth \`user_metadata\`. \`user_metadata\` is editable by end users and should never be used in a security context.',
        table_,
        policy_name
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=0015_rls_references_user_metadata' as remediation,
    jsonb_build_object(
        'schema', schema_,
        'name', table_,
        'type', 'table'
    ) as metadata,
    format('rls_references_user_metadata_%s_%s_%s', schema_, table_, policy_name) as cache_key,
	with_check,
	qual
from
    policies
where
    schema_::text not in (
        '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql', 'graphql_public', 'information_schema', 'net', 'pgroonga', 'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog', 'pgtle', 'realtime', 'repack', 'storage', 'supabase_functions', 'supabase_migrations', 'tiger', 'topology', 'vault'
    )
    and (
            -- Example: auth.jwt() -> 'user_metadata'
			-- False positives are possible, but it isn't practical to string match
			-- If false positive rate is too high, this expression can iterate
            qual like '%auth.jwt()%user_metadata%'
			or qual like '%current_setting(%request.jwt.claims%)%user_metadata%'
			or with_check like '%auth.jwt()%user_metadata%'
			or with_check like '%current_setting(%request.jwt.claims%)%user_metadata%'
    );
