# splinter (Supabase Postgres LINTER)

This project maintains a set of lints for Supabase projects. It uses SQL queries to identify common database schema issues. Some lints are general purpose for Postgres projects while others are specific to Supabase features storing their data in Postgres e.g. auth and storage.

Currently `splinter` is intended to house the SQL for the lints but it not opinionated about how they will be executed against user projects. See [Project Linting RFC](https://www.notion.so/supabase/Project-Lints-f34e7b24bb5846c188c8096ad10eb045) for options under consideration.

## Interface

Each lint creates a view that returns a common interface. The interface is:

- name (text) not null -- Name of the lint
- level (text) not null -- The level of issue. One of ERROR/WARN/INFO
- facing (text) not null -- Is it an internal (to supabase) or an external (user centric)  lint. One of INTERNAL/EXTERNAL
- description (text) not null -- This is a description of the lint and why its an issue
- detail (text) not null -- A text description of the issue that includes references to the specific table/column/constraint/whatever that fails the lint
- remediation (text) optional -- The SQL to resolve the issue
- metadata (jsonb) optional -- Any additional information that 
- cache_key (text) not null -- A short, uniquely identifiable string that users can add to an exclusion list to avoid repeatedly seeing the same lint failures. It should identify the releavnt table/column/constraint. The string should be prefixed with the lint name. For example a lint named "unindexed_foreign_key" might have a unique key "unindexed_foreign_key_public_user_created_by_id"


## Lints

### 0001_unindexed_foreign_keys

- Level: INFO
- Facing: EXTERNAL

Identifies foreign key constraints without a covering index, which can impact query performance. Supports multi-colum foreign keys

### 0002_auth_users_exposed

Detects if auth.users is exposed to anon or authenticated roles via a view or materialized view in the public schema, potentially compromising user data security.

- Level: WARN
- Facing: EXTERNAL

### 0003_auth_rls_initplan

Detects if calls to auth.function() in RLS policies are being unnecessarily re-evaluated for each row

- Level: WARN
- Facing: EXTERNAL

### 0004_no_primary_key

Detect tables without a primary key.

- Level: INFO
- Facing: EXTERNAL

## TODO Lints

The following are lints on the TODO list with a WIP associated query showing how to get at "some" of the data.

### unused_indexes

Detects indexes that have never been used to service a query.

- Level: INFO
- Facing: EXTERNAL

```sql
SELECT schemaname, relname, indexrelname
FROM pg_stat_user_indexes
JOIN pg_index USING (indexrelid)
WHERE idx_scan = 0
  AND indisunique IS FALSE;
```


### duplicate_indexes

Detects duplicate/redundant indexes.

- Level: WARN 
- Facing: EXTERNAL

```sql
SELECT indrelid::regclass, array_agg(indexrelid::regclass), array_agg(indexrelid) AS index_ids
FROM pg_index
GROUP BY indrelid, indkey
HAVING COUNT(*) > 1;
```

### rls_multiple_permissive_policies

Detects if multiple permissive policies are present on a table for the same `role` and `action` (e.g. insert).

- Level: WARN 
- Facing: EXTERNAL

```sql
SELECT polrelid::regclass AS table, COUNT(*) AS permissive_policies
FROM pg_policy
WHERE polcmd = 'ALL' AND polpermissive
GROUP BY polrelid
HAVING COUNT(*) > 1;
```

### rls_policy_with_rls_disabled

Detects if RLS policies exist for a table but RLS has not been enabled for the table.

- Level: WARN 
- Facing: EXTERNAL

```sql
SELECT n.nspname AS schema_name,
       c.relname AS table_name,
       EXISTS (SELECT 1 
               FROM pg_catalog.pg_policy p 
               WHERE p.polrelid = c.oid) AS has_policy,
       c.relrowsecurity AS rls_enabled
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' -- restrict to tables
      AND n.nspname NOT IN ('pg_catalog', 'information_schema') -- exclude system tables
      AND EXISTS (SELECT 1 
                  FROM pg_catalog.pg_policy p 
                  WHERE p.polrelid = c.oid)
      AND c.relrowsecurity = false; -- RLS is not enabled

```

## Requirements

Supabase PostgreSQL 14+

Setup:

```sh
git clone https://github.com/supabase/splinter.git
cd splinter
```

## Tests

All lints must have positive and negative tests.

To run the test suite, 

Run test
```sh
docker rmi -f dockerfiles-db && SUPABASE_VERSION=15.1.1.13 docker-compose -f dockerfiles/docker-compose.yml run --rm test
```
