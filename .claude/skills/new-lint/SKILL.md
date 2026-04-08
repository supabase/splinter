---
name: new-lint
description: Create a new splinter lint — a SQL view that checks for a database anti-pattern. Use this skill when the user asks to add a lint, create a new check, implement a linting rule, or extend splinter with a new detection.
argument-hint: <lint_name> <brief description of what it detects>
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

# Create a New Splinter Lint

You are implementing a new lint for the splinter PostgreSQL linting tool. Follow every step in order. Do not skip steps.

## Step 1 — Determine the next lint number

Glob `lints/*.sql` and find the highest numeric prefix. Increment by 1 to get the new lint ID (zero-padded to 4 digits, e.g. `0025`). Use this as `XXXX` throughout.

The lint's machine name (the `name` column) is derived from the argument: lowercase, underscores, no leading digits.

## Step 2 — Create `lints/XXXX_<name>.sql`

Create a SQL view in the `lint` schema. The view **must** return exactly these 10 columns in this order:

| Column | Type | Notes |
|--------|------|-------|
| `name` | text | snake_case identifier, e.g. `'my_lint_name'` |
| `title` | text | Human-readable title |
| `level` | text | `'ERROR'`, `'WARN'`, or `'INFO'` |
| `facing` | text | `'EXTERNAL'` or `'INTERNAL'` |
| `categories` | text[] | e.g. `array['SECURITY']` or `array['PERFORMANCE']` |
| `description` | text | What the lint checks and why it matters |
| `detail` | text | `format()`-interpolated message naming the specific object |
| `remediation` | text | `'https://supabase.com/docs/guides/database/database-linter?lint=XXXX_<name>'` |
| `metadata` | jsonb | `jsonb_build_object('schema', ..., 'name', ..., 'type', ...)` |
| `cache_key` | text | `format('<name>_%s_%s', schema, object)` — unique per violation |

**Required conventions:**
- Always prefix all catalog references: `pg_catalog.pg_class`, `pg_catalog.pg_namespace`, etc.
- Always exclude system schemas using this exact list:
  ```sql
  nsp.nspname not in (
      '_timescaledb_cache', '_timescaledb_catalog', '_timescaledb_config',
      '_timescaledb_internal', 'auth', 'cron', 'extensions', 'graphql',
      'graphql_public', 'information_schema', 'net', 'pgmq', 'pgroonga',
      'pgsodium', 'pgsodium_masks', 'pgtle', 'pgbouncer', 'pg_catalog',
      'pgtle', 'realtime', 'repack', 'storage', 'supabase_functions',
      'supabase_migrations', 'tiger', 'topology', 'vault'
  )
  ```
- End with a deterministic `ORDER BY` (e.g. `ORDER BY schema_name, table_name`) — required for stable pg_regress output
- **Never** select raw OIDs, ctids, timestamps, or sequences in output columns — they vary between runs
- If using `array_agg`, always specify `ORDER BY` inside the aggregate for deterministic element order
- Use CTEs for complex logic

**Template:**
```sql
create view lint."XXXX_<name>" as
select
    '<name>' as name,
    '<Title>' as title,
    'WARN' as level,
    'EXTERNAL' as facing,
    array['SECURITY'] as categories,
    '<Description of what is checked>' as description,
    format(
        '<detail message with `%s`.`%s` references>',
        schema_name,
        table_name
    ) as detail,
    'https://supabase.com/docs/guides/database/database-linter?lint=XXXX_<name>' as remediation,
    jsonb_build_object(
        'schema', schema_name,
        'name', table_name,
        'type', 'table'
    ) as metadata,
    format('<name>_%s_%s', schema_name, table_name) as cache_key
from
    -- your query here
order by
    schema_name,
    table_name;
```

## Step 3 — Update `bin/installcheck`

Read `bin/installcheck`. Find line 55 — the long `psql` command that loads all lint files. It currently ends with something like:
```
-f lints/0024*.sql -d contrib_regression
```

Insert the new lint **before** `-d contrib_regression`, maintaining numeric order:
```
-f lints/0024*.sql -f lints/XXXX*.sql -d contrib_regression
```

## Step 4 — Create `docs/XXXX_<name>.md`

```markdown
**Level:** WARN|ERROR|INFO

**Summary:** One-line summary of what is detected.

**Ramification:** What goes wrong in production if this is ignored.

---

### Rationale

Why this pattern is problematic. Include context about the Supabase platform where relevant.

### How to Resolve

**Option 1: [Preferred fix]**

```sql
-- Example SQL showing the fix
```

**Option 2: [Alternative]**

```sql
-- Alternative fix
```

### Example

Given this problematic configuration:

```sql
-- The bad pattern
```

Fix:

```sql
-- The corrected version
```

### False Positives

Cases where this lint may fire when the pattern is intentional, and how to handle them.
```

## Step 5 — Create `test/sql/XXXX_<name>.sql`

Structure the test file exactly as follows:

```sql
begin;
  set local search_path = '';
  -- Add the following line only if your lint uses pgrst.db_schemas:
  -- set local pgrst.db_schemas = 'public';

  -- BASELINE: 0 issues on empty schema
  select * from lint."XXXX_<name>";

  savepoint a;

  -- NEGATIVE EXAMPLE: a similar-looking pattern that should NOT trigger
  -- Explain why this should not fire (comment required)
  -- ... DDL ...
  select * from lint."XXXX_<name>";  -- expect 0 rows

  rollback to savepoint a;

  -- POSITIVE EXAMPLE: the problematic pattern that SHOULD trigger
  -- Explain what makes this a violation (comment required)
  -- ... DDL ...
  select name, detail, cache_key from lint."XXXX_<name>";  -- expect 1+ rows

  -- RESOLUTION: apply one of the documented fixes
  -- ... DDL fix ...
  select * from lint."XXXX_<name>";  -- expect 0 rows

rollback;
```

**Stability rules — pg_regress does exact string comparison across every run:**
- Use fixed, explicit object names (never random/generated)
- Project only the columns needed to verify correctness — avoid `select *` for wide/variable output
- Prefer projecting `name`, `detail`, `cache_key` for positive cases rather than `select *`
- Never rely on row order that isn't guaranteed by the lint's `ORDER BY`
- Never reference OIDs, system-generated values, or version-specific catalog details
- Never use `count(*)` when a projected `select` of 0/1 rows is more informative and equally stable

## Step 6 — Run Docker tests and generate `test/expected/XXXX_<name>.out`

Always use Docker — local Postgres versions may produce subtly different output:

```bash
docker rmi -f dockerfiles-test && SUPABASE_VERSION=15.1.1.13 docker-compose -f dockerfiles/docker-compose.yml run --rm test
```

Results are written to `results/` (mounted volume). **Read and verify `results/XXXX_<name>.out` before promoting:**

- Baseline query → `(0 rows)` ✓
- Negative example → `(0 rows)` ✓
- Positive example → expected row(s) with correct `name`, `detail`, `cache_key` values ✓
- Resolution example → `(0 rows)` ✓
- No SQL errors anywhere in the file ✓

Only after verification:
```bash
cp results/XXXX_<name>.out test/expected/XXXX_<name>.out
```

## Step 7 — Update `test/sql/queries_are_unionable.sql`

Read the file. Before the final semicolon (on the last `select * from lint."0024_..."` line), append:
```sql
    union all
    select * from lint."XXXX_<name>"
```

The file ends with a semicolon after the last view reference, then `rollback;`. Add the new entry before that semicolon.

## Step 8 — Verify and promote `test/expected/queries_are_unionable.out`

The Docker run from Step 6 already produced `results/queries_are_unionable.out`. **Read and verify it:**

- The SQL echo must include the new `union all select * from lint."XXXX_<name>"` line ✓
- The result must be `(0 rows)` ✓
- No SQL errors ✓

Only after verification:
```bash
cp results/queries_are_unionable.out test/expected/queries_are_unionable.out
```

## Step 9 — Regenerate `splinter.sql`

```bash
python bin/compile.py
```

This rebuilds `splinter.sql` as a `UNION ALL` of all lint views. Verify the new lint appears in the output file.

## Step 10 — Install pre-commit hooks (if not already installed)

```bash
pre-commit install
```

This ensures `bin/compile.py` runs automatically on every commit to keep `splinter.sql` in sync.

---

## Verification Checklist

Run the full Docker suite one final time:
```bash
docker rmi -f dockerfiles-test && SUPABASE_VERSION=15.1.1.13 docker-compose -f dockerfiles/docker-compose.yml run --rm test
```

Then check:
- [ ] `results/regression.diffs` is empty (no unexpected diffs)
- [ ] `git diff test/expected/` shows only the new files you intentionally added/changed
- [ ] `splinter.sql` includes the new lint in the `UNION ALL`
- [ ] `lints/XXXX_<name>.sql` exists
- [ ] `docs/XXXX_<name>.md` exists
- [ ] `test/sql/XXXX_<name>.sql` exists
- [ ] `test/expected/XXXX_<name>.out` exists

---

## Key Reference Files

| What to copy | From |
|---|---|
| System-schema exclusion list | `lints/0024_rls_policy_always_true.sql` lines 38–40 |
| Extension-owned object filter (pg_depend) | `lints/0001_unindexed_foreign_keys.sql` |
| pgrst.db_schemas API exposure check | `lints/0023_sensitive_columns_exposed.sql` |
| begin/savepoint/rollback test structure | `test/sql/0024_rls_policy_always_true.sql` |
| Doc format | `docs/0024_permissive_rls_policy.md` |
