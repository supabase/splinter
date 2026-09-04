# CLAUDE.md

Guidance for Claude Code sessions working in this repo.

## What this is

`splinter` (Supabase Postgres LINTER) maintains a set of SQL-based lints for
Supabase Postgres projects. `bin/check_lints.py` checks every lint is fully
registered, and `bin/compile.py` compiles all lint views into the tracked,
generated `splinter.sql` (`UNION ALL` of every `lints/*.sql` view) - don't
hand-edit `splinter.sql` directly, it's overwritten by `bin/compile.py`.

## Build / test / lint

```
pre-commit run --all-files
```

Runs the full local gate, matching `.github/workflows/pre-commit_hooks.yaml`:
`black` (pinned to `24.2.0` in `.pre-commit-config.yaml`, needs a `python3.12`
interpreter on PATH for its hook env - pre-commit installs `black` itself, no
manual install needed), `bin/compile.py` (regenerates `splinter.sql`),
`bin/check_lints.py` (checks every lint is fully registered), plus standard
hygiene hooks (trailing-whitespace, excluding `test/expected` since those
`.out` files are whitespace-exact pg_regress golden files; check-added-large-files;
check-yaml; mixed-line-ending; remove-tabs).

```
docker rmi -f dockerfiles-test
SUPABASE_VERSION=15.1.1.13 docker-compose -f dockerfiles/docker-compose.yml run --rm test
```

Runs the real pg_regress test suite against a live Postgres, matching
`.github/workflows/test.yml`'s effective behavior (which sets `PG_VERSION`,
not `SUPABASE_VERSION` - a repo-side no-op both there and here, since
`dockerfiles/docker-compose.yml` only reads `SUPABASE_VERSION` for its build
arg). The `docker rmi -f` first is required, not optional: `docker compose
run` reuses the last built image, so a lint/test/expected-file change without
it can report a stale pass.
