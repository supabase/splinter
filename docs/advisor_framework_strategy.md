# Advisor framework strategy (multi-source; push-first as a working hypothesis)

This doc is **product/architecture oriented** and intended as a jumping-off point for engineering investigation. It’s written to be OSS-friendly (conceptual, not a binding implementation spec).

It does *not* propose adding non-SQL “advisor engines” into Splinter. Instead, Splinter remains a **SQL-only** producer of Postgres findings, while other sources (logs/traces/metrics/edge/humans) can create Advisor issues via an ingestion API.

References:
- Splinter docs: `https://supabase.github.io/splinter/`
- Supabase Database Advisors docs: `https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins`

## Key design choice: push vs pull

### Push (often a good fit)
Producers evaluate signals “close to the data” and **push** Advisor issues:
- Logs/traces: Logflare/ClickHouse queries + thresholding in a job or alerting layer
- Metrics: **VictoriaMetrics + vmalert** (or Alertmanager) → webhook to the ingestion API
- Product services: plan/usage thresholds, resource exhaustion, quota events
- Edge Functions: detect misconfigurations and push issues
- Humans / Assistant: manual issues (“broadcasting important updates”)

Pros:
- Uses each system’s native evaluation semantics (PromQL + alert windows, etc.)
- Avoids Supabase embedding every query engine + auth model
- Reduces load on Postgres/telemetry backends from “always-on polling”

### Pull (fallback / managed checks)
Supabase periodically queries sources (ClickHouse, PromQL, etc.) and synthesizes issues.

Pros:
- Great for onboarding (“turnkey checks”)
- Works even if users haven’t wired alerting/webhooks

Cons:
- Forces Supabase to own connectors, auth, safe query execution, and alert semantics

**Working hypothesis:** provide a **push-first ingestion API** and optionally layer **managed pull-based checks** behind the same ingestion + issue model.

## Advisor API surface (conceptual capabilities)

Minimum viable operations (regardless of URL shape):
- **Upsert** an issue (create or update, typically setting state to `open`)
- **Resolve** an issue (set state to `resolved`)
- **Dismiss** an issue (set state to `dismissed`)
- **Snooze** an issue (set state to `snoozed` until a timestamp)

You can also unify create/resolve as a single “upsert current state” operation if the payload includes `state`.

## Webhooks as first-class plumbing

If Supabase is investing in “more webhooks” functionality, it fits the Advisor strategy in **two** complementary ways:

### 1) Inbound webhooks (create/update Advisor issues)
Treat a webhook delivery as a **producer** of Advisor issues. Examples:
- VictoriaMetrics/vmalert/Alertmanager firing events → create/update/resolve Advisor issues
- log-based alerting (Logflare/ClickHouse) → create/update/resolve Advisor issues
- internal platform events (resource exhaustion, quota events, deploy events) → create/update/resolve Advisor issues
- schema change events (e.g. “policy changed”, “RLS disabled”) → create Advisor issues or prompt re-run of Splinter

This aligns with your goal: “Advisor as a flexible issue creation and triggers framework”.

### 2) Outbound webhooks (broadcast Advisor issues)
When an Advisor issue is created/updated/resolved/dismissed, Supabase can emit **outbound** events to user-configured destinations:
- Slack, email, PagerDuty, generic webhooks, etc.

This is separate from issue *creation* but part of the end-to-end “alerting/notifications + advisor” experience:
- Advisor issue = the durable, discussable, dismissable record
- Outbound webhooks = delivery/routing based on user preferences

Practical implementation detail:
- model outbound delivery rules separately from issue types
- support per-project routing and per-type routing (e.g. only `ERROR` to PagerDuty)

## Issue identity: generalize Splinter’s `cache_key`

Splinter already encodes the correct idea:
- each finding has a stable `cache_key` that can be used for suppression/dedupe

Generalize this for *all* sources:
- **type** (aka check id): e.g. `splinter/unindexed_foreign_keys`, `logs/http_5xx_spike`, `metrics/cpu_hot`
- **fingerprint**: stable instance key within a type

Store uniqueness as:
- `(project_ref, type, fingerprint)`

### Lifecycle state
- **open**: currently firing / present
- **resolved**: no longer firing / no longer present
- **dismissed**: user doesn’t want to see it (until explicitly reopened)
- **snoozed**: suppressed until a timestamp

## Suggested ingestion payload (conceptual)

An ingestion payload should be able to carry:

- `type` (string)
- `fingerprint` (string)
- `severity` (`ERROR|WARN|INFO`)
- `title` (string)
- `detail` (string)
- `categories` (string[])
- `remediation` (url/string, optional)
- `metadata` (object, optional)
- `source` (object, optional): `{ kind: "splinter|clickhouse|vmalert|edge|manual", ref?: string }`
- `state` (optional): if absent, default to `open`
- `observed_at` (timestamp, optional)

On the backend, this becomes a durable issue record with timestamps (`first_seen`, `last_seen`, etc.).

## How sources map to the ingestion model

### Splinter (Postgres schema advisors)
Splinter stays SQL-only:
- lints in `lints/` emit rows with `cache_key`
- `splinter.sql` unions all lints

Producer job options:
- UI job (on-demand “rerun advisors”)
- backend cron (e.g. daily) to keep issues warm

Flow:
1) run `splinter.sql`
2) convert each row to `type = "splinter/{name}"` and `fingerprint = cache_key`
3) upsert issues
4) resolve issues for that `type` that were not returned (or use an explicit `resolve` call)

### Logs/traces (Logflare → ClickHouse)
Push-first options:
- a scheduled job queries ClickHouse for the last N minutes and pushes issues
- a logs alerting layer (if present) calls the ingestion endpoint directly

Example types:
- `logs/http_5xx_spike` (fingerprint: `service=X,route=Y`)
- `traces/p95_latency_regression` (fingerprint: `service=X,operation=Y`)

### Metrics (VictoriaMetrics)
Preferred path: **vmalert → webhook**.

Why:
- vmalert already encodes windowing, alert state, de-dupe, and silence/inhibition concepts
- Supabase only needs to map alert events into Advisor issues

Fallback path: managed pull checks.
- Supabase runs curated PromQL on a schedule
- returns series above a threshold → upsert issues
- no longer returned → resolve issues

### VictoriaMetrics SaaS alerting (managed alert rules)
If you’re using VictoriaMetrics’ SaaS/managed offerings for alerting (rule management UI, managed alert evaluation, etc.), treat it the same as vmalert conceptually:
- alert evaluation happens in VictoriaMetrics’ alerting system
- alerts deliver to a webhook receiver
- the Advisor ingestion API is one such receiver

The key mapping is still:
- `type`: stable alert name (namespaced, e.g. `metrics/cpu_hot`)
- `fingerprint`: stable label-set identity (e.g. `instance=db-01` or `cluster=X:instance=Y`)
- `state`: open when firing, resolved when cleared

What we likely need to confirm (since SaaS feature sets vary):
- what webhook payload shape is emitted (Alertmanager-compatible vs custom)
- whether “resolved” notifications are delivered
- how de-dupe/inhibition/silences are represented

## Standardized Advisor types (registry) vs custom

You likely want both:
- **Curated registry** of known types for UI, docs, and consistent severity/category semantics
- **Custom types** for user-defined rules and internal experimentation

Practical compromise:
- accept any `type` string
- Studio treats known prefixes (e.g. `splinter/`, `logs/`, `traces/`, `metrics/`, `billing/`) as first-class
- optionally expose `GET /advisor/types` for metadata (title, docs link, default severity)

## What belongs in Splinter (and what doesn’t)

Splinter should remain focused on what it’s good at:
- deterministic Postgres catalog/state checks
- SQL queries that return structured findings
- stable fingerprints (`cache_key`)

It should *not* embed:
- alerting engines
- time-windowed evaluation for logs/traces/metrics
- notification routing logic

## Open questions (for an engineering spike)

These are intentionally left open to avoid over-prescribing implementation:

- **Inbound webhook shape**: will inbound alerts be Alertmanager-compatible, vendor-specific, or both?
- **Resolved semantics**: do upstream systems send “resolved” events (or do we infer resolution)?
- **Auth**: how do producers authenticate to the ingestion API (per-project secrets, signed webhooks, service tokens)?
- **Multi-tenancy**: how does a producer target the correct `project_ref` (explicit routing vs token-bound project)?
- **Dedupe**: what’s the recommended fingerprint scheme per source (labelset hashing, stable IDs, etc.)?
- **Type registry**: do we want a curated set of “known types” (for UI/UX), plus custom types (for extensibility)?
- **Outbound routing**: how should outbound webhooks/notifications relate to issues (per type, per severity, per project)?

