# Lint benchmark

Times every lint, and the full `splinter.sql` union, on Supabase schemas, comparing a base checkout with a head checkout. CI runs it on every PR that touches `lints/`, `bin/compile.py` or `bench/`. Each target runs as its own job on `supabase/postgres`, and one PR comment collects the results and is updated on every run.

## Targets

- **synthetic**: `fixture/` built at 2,000 tables, a scaling stress test that surfaces lints whose cost grows faster than the catalog. Every lint has findings. `--sizes small=20,large=2000` builds several sizes cumulatively on one database.
- **Real projects**: the open-source apps from the dogfooding corpus, fetched from GitHub at the commits pinned in `projects/projects.json`. Their `supabase/migrations` are applied in order on the bare image, after `projects/services-stub.sql` stands in for the tables storage-api, GoTrue and realtime would create. Each migration runs in one transaction; one that still fails is rolled back, skipped and listed in the report.

| target | tables | policies | `pg_depend` rows | migrations applied |
| -- | --: | --: | --: | --: |
| synthetic / large | 2,197 | 2,736 | 64k | – |
| carbon | 520 | 1,501 | 41k | 1,230 / 1,230 |
| deskcomm | 283 | 669 | 17k | 520 / 530 (baseline dump + migrations) |
| grida | 174 | 89 | 7k | 76 / 87 (timescaledb is not in the image) |
| wacrm | 113 | 114 | 5k | 54 / 54 |
| atomic-crm | 88 | 36 | 3k | 28 / 28 |
| basejump | 82 | 13 | 2k | 4 / 4 |

Table counts include the image's own schemas.

Only the large targets are timed. The small projects run with `--rounds 0`: their full run takes 50–100 ms, mostly fixed overhead, and per-lint differences stay inside runner noise, so they only check that every lint returns the same rows as base. Their real-world SQL still catches rewrites that break on patterns the fixture lacks.

## What fails the check

| Guard | Rule | Waiver label |
| -- | -- | -- |
| Lint errors on head | Any error | none |
| Results | Row count and md5 of the sorted rows (as `jsonb`, so column names count) differ from base | `lint-results-changed` |
| Plan | Head's plan gains a catalog scan that runs once per outer row and reads more than 50 blocks per loop, i.e. a whole catalog or index instead of an index probe | `perf-accepted` |
| Buffers | `EXPLAIN (ANALYZE, BUFFERS)` reads at least 10% and 100 blocks more than base | `perf-accepted` |
| Wall time | The median is at least 15% and 3 ms slower, and every head round is slower than every base round | `perf-accepted` |
| Base errors | The lint errors on base, so there is nothing to compare | `perf-accepted` |

Buffer counts are deterministic, so they catch plan regressions that are too small to see in wall time on a noisy runner. The plan pass runs twice and keeps the second, so catalog-cache warm-up does not count. Wall time runs base and head in interleaved rounds on the same database, alternating which goes first, and is measured server-side around the query.

## When you change the benchmark

- When you add a lint, extend `fixture/` so it has findings.
- A project whose initial schema is a dump outside its migrations sets `baseline` (applied first) and, for the extensions the dump assumes, `setup` in `projects/projects.json`.
- When you add a project, pin a commit in `projects/projects.json` and add it to the matrix in `.github/workflows/bench.yml`, timed (`rounds: 5`) only if it is large enough for lint timings to move beyond noise.

## Run locally

```bash
docker run -d --name splinter-bench -e POSTGRES_PASSWORD=postgres -p 54329:5432 supabase/postgres:17.6.1.169
git worktree add /tmp/splinter-base origin/main
export PGHOST=localhost PGPORT=54329 PGPASSWORD=postgres
python3 bench/bench.py measure --base /tmp/splinter-base --out synthetic.json
python3 bench/bench.py compare synthetic.json
```

For a project, use a fresh container and:

```bash
python3 bench/bench.py measure --base /tmp/splinter-base --project "carbon=$(python3 bench/bench.py fetch carbon --dest /tmp/carbon)" --out carbon.json
```

Without `--base` you get absolute numbers: only lint errors fail, and repeated catalog scans are listed. `compare` takes several result files. The schema load is not idempotent, so every `measure` needs a fresh container.
