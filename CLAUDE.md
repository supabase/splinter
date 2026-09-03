# CLAUDE.md

Guidance for Claude Code sessions working in this repo.

## What this is

`splinter` (Supabase Postgres LINTER) maintains a set of SQL-based lints for
Supabase Postgres projects, checked via `bin/check_lints.py` and compiled
via `bin/compile.py`.

## Build / test / lint

```
pre-commit run --all-files
```

Runs the full local gate, matching `.github/workflows/pre-commit_hooks.yaml`:
`black` (pinned to `24.2.0` in `.pre-commit-config.yaml` - install that exact
version in a venv, since a newer `black`'s reformatting can differ),
`bin/compile.py` (compiles the SQL lint files), `bin/check_lints.py` (checks
every lint is fully registered), plus standard hygiene hooks
(trailing-whitespace, check-yaml, mixed-line-ending, remove-tabs).

```
PG_VERSION=<version> docker compose -f dockerfiles/docker-compose.yml build
PG_VERSION=<version> docker compose -f dockerfiles/docker-compose.yml run test
```

Runs the real pg_regress test suite against a live Postgres, matching
`.github/workflows/test.yml`. Rebuild with `--no-cache` after any
dependency/lockfile change - a bare `docker compose run` reuses the last
built image and can report a stale pass.

A CI failure right after a commit that looks unrelated to your own change
can be drift on `main` picked up by a merge, not a regression in your own
work - diff `origin/main` fresh before assuming it's self-inflicted.
