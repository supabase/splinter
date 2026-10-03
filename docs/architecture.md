# Architecture: Splinter and Supabase Database Advisors

This document explains how this repository works today (Splinter), how it maps to Supabase’s “Database Advisors” UI, and why the current approach is inherently **SQL/Postgres-only**.

For end-user facing documentation of individual lints, see the lint pages on the Splinter docs site (`https://supabase.github.io/splinter/`) and Supabase docs ([Database Advisors](https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins)).

## What Splinter is (and is not)

Splinter is a **collection of SQL lints** intended to be run against a Supabase Postgres database. Each lint is implemented as a view that returns a standardized “issue row” shape.

Splinter is **not** a generic alerting/advisory system. It does not:
- schedule periodic evaluations
- store issue lifecycle state (open/resolved/dismissed)
- evaluate non-Postgres sources (logs, traces, metrics, client errors, billing/usage)

## The lint interface (the contract)

Each lint view returns the same columns (see `README.md`):
- `name` (text) — stable check id (e.g. `unindexed_foreign_keys`)
- `title` (text) — human title
- `level` (text) — `ERROR` / `WARN` / `INFO`
- `facing` (text) — `INTERNAL` / `EXTERNAL`
- `categories` (text[]) — e.g. `{SECURITY}` or `{PERFORMANCE}`
- `description` (text) — why this matters
- `detail` (text) — specific instance detail (table/view/function etc.)
- `remediation` (text, optional) — documentation URL or guidance
- `metadata` (jsonb, optional) — structured data for UI rendering or deep links
- `cache_key` (text) — **stable fingerprint** used for de-dupe/suppression

**Key point:** `cache_key` is the only stable identifier for “the same finding” across runs. It’s the hook needed for an issue lifecycle system.

## How lints are authored

Lints live in `lints/` as one `.sql` file per lint, each creating a view under the `lint` schema:

- Example: `lints/0001_unindexed_foreign_keys.sql` creates `lint."0001_unindexed_foreign_keys"`.
- Tests read from these views directly (see `test/sql/`).

## How Splinter is “compiled” into one query

Some consumers (like a UI) want to run a single query and receive a single result set containing all findings.

Splinter ships that as `splinter.sql`, produced by `bin/compile.py`:
- reads `lints/*.sql`
- strips the `create view` line and semicolons
- wraps each lint query in parentheses
- concatenates them with `UNION ALL`
- prefixes `set local search_path = '';` to enforce schema qualification

Net: **`splinter.sql` is “all lints as one unionable query”.**

## How Splinter is tested

Tests are Postgres regression tests that validate each lint has at least a true-positive case:
- `test/fixtures.sql` provisions minimal schemas/roles/functions needed for lint execution.
- `test/sql/*.sql` sets up example schema states and selects from `lint."00xx_*"`.
- `test/expected/*.out` captures expected output.
- `bin/installcheck` runs pg_regress and also validates that `splinter.sql` runs.

## How this maps to Supabase “Database Advisors”

Supabase’s “Performance and Security Advisors” are a set of checks surfaced in the dashboard UI ([Database Advisors docs](https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins)).

The “DB schema / security / performance” subset of those checks can be implemented as Splinter lints because they are answerable by querying Postgres system catalogs and Supabase schemas.

Operationally, a consumer (such as Supabase Studio) can:
- run `splinter.sql` (or an equivalent union query)
- render each row as an “advisor finding”
- allow users to dismiss/suppress findings via `cache_key`

## When are lints run (triggering) and where do results live?

Splinter itself does **not** define scheduling, triggers, or persistence. It only defines the SQL that produces findings.

In Supabase’s product, there are typically two different “execution contexts” to be aware of:

### 1) Interactive / on-demand (e.g. Supabase Studio)
In Supabase Studio (in the `supabase/supabase` repo), the current “lints/advisors” flow is implemented as an **on-demand SQL query** executed against the project’s Postgres database when the UI needs it (for example, when you open the Advisors page or click a re-run action).

Concretely, Studio sends the lint SQL to a platform endpoint that proxies to `pg-meta`, executing the query against the project database (see `executeSql` in Studio which posts to `/platform/pg-meta/{ref}/query` in `supabase/supabase`).

This is why Splinter focuses on:
- deterministic SQL
- predictable output shape
- stable `cache_key` values (so consumers can de-dupe and suppress repeated findings)

### 2) Scheduled / aggregated (analytics, fleet-level views)
Separately from the UI, Supabase may run similar checks on a schedule and/or export results for analytics. For example, you mentioned querying a BigQuery table named `supabase-etl-prod-eu.dbt.project_lints`.

That table name is a good example of historical terminology: the underlying concept is “advisor findings/issues”, but earlier naming often used “lints”. It’s worth calling out explicitly as Supabase’s long-term direction expands Advisors beyond SQL lints.

Because this repo is OSS and Splinter-only, the precise scheduling/ETL details live outside this repo (Studio/backend/data pipelines). A reasonable mental model is:
- Splinter provides the *finding generator* (SQL)
- Supabase systems decide *when to run it* and *whether/how to store it* (UI state, issue lifecycle, analytics exports)

## A concrete limitation example (docs vs SQL)

This repo contains documentation for check `0012_auth_allow_anonymous_sign_ins` (`docs/0012_auth_allow_anonymous_sign_ins.md`), but there is no corresponding SQL lint in `lints/`.

That’s a useful reminder: some “advisor” checks depend on **non-Postgres state** (e.g., auth configuration) or **time-windowed telemetry** (logs/traces/metrics), which can’t be expressed as a static Postgres catalog query.

## Why this matters for “multi-source Advisors”

If you want Advisors that can come from logs/traces/metrics/UI errors/etc., you need something beyond “run a SQL union query against Postgres”.

Splinter’s lint rows are a good *finding format* for DB checks, but a full Advisor system also needs:
- source-specific evaluation (ClickHouse, PromQL, etc.)
- scheduling and/or event triggers
- a stable issue model + dedupe
- lifecycle storage (open/resolved/dismissed/snoozed)
- routing/notification integrations



