# splinter (Supabase Postgres LINTER)

<img src="https://github.com/supabase/splinter/assets/12958657/3683c310-c9f6-4b05-ae3a-c51c03d3ff0f" height="250">

<p>
<a href=""><img src="https://img.shields.io/badge/postgresql-15+-blue.svg" alt="PostgreSQL version" height="18"></a>
<a href="https://github.com/supabase/splinter/blob/master/LICENSE"><img src="https://img.shields.io/pypi/l/markdown-subtemplate.svg" alt="License" height="18"></a>
<a href="https://github.com/supabase/splinter/actions"><img src="https://github.com/supabase/splinter/actions/workflows/test.yml/badge.svg" alt="tests" height="18"></a>
</p>

---

**Documentation**: <a href="https://supabase.github.io/splinter" target="_blank">https://supabase.github.io/splinter</a>

**Source Code**: <a href="https://github.com/supabase/splinter" target="_blank">https://github.com/supabase/splinter</a>

---

Splinter maintains a set of lints for Supabase projects. It uses SQL queries to identify common database schema issues. Some lints are general purpose for Postgres projects while others are specific to Supabase features storing their data in Postgres e.g. auth and storage.

## Usage

If you are only interested in linting a project, a single query containing the latest version of all lints is availble in splinter.sql in the repo root.

## Lint Interface

Each lint creates a view that returns a common interface. The interface is:

- name (text) not null -- Name of the lint
- title (text) not null -- Human readable title of the lint
- level (text) not null -- The level of issue. One of ERROR/WARN/INFO
- facing (text) not null -- Is it an internal (to supabase) or an external (user centric)  lint. One of INTERNAL/EXTERNAL
- categories (text[]) not null -- Relevant tags for the issue. Any/All of SECURITY/PERFORMANCE (list may grow)
- description (text) not null -- This is a description of the lint and why its an issue
- detail (text) not null -- A text description of the issue that includes references to the specific table/column/constraint/whatever that fails the lint
- remediation (text) optional -- A reference to documentation to describe the issue and how to resolve it
- metadata (jsonb) optional -- Lint specific information, for example referenced entities, or entity types
- cache_key (text) not null -- A short, uniquely identifiable string that users can add to an exclusion list to avoid repeatedly seeing the same lint failures. It should identify the releavnt table/column/constraint. The string should be prefixed with the lint name. For example a lint named "unindexed_foreign_key" might have a unique key "unindexed_foreign_key_public_user_created_by_id"

## Deploying to supabase/supabase

To deploy lints to Supabase prod, open a PR against `supabase/supabase` updating [the lint query](https://github.com/supabase/supabase/blob/76d10d789fcd1b3e02a62d67d2d8edce78f81903/apps/studio/data/lint/lint-query.ts#L6)

If the update includes a new lint, update [getHumanReadableTitle](https://github.com/supabase/supabase/blob/76d10d789fcd1b3e02a62d67d2d8edce78f81903/apps/studio/components/interfaces/Reports/ReportLints.utils.tsx#L9) and [LINT_TYPES](https://github.com/supabase/supabase/blob/76d10d789fcd1b3e02a62d67d2d8edce78f81903/apps/studio/data/lint/lint-query.ts#L694).

[Example PR](https://github.com/supabase/supabase/pull/22682)


## Development

Supabase PostgreSQL 15+

Setup:

```sh
git clone https://github.com/supabase/splinter.git
cd splinter
```

## Tests

All lints tests with a true positive example.

To run the test suite:

```sh
docker rmi -f dockerfiles-test && SUPABASE_VERSION=15.1.1.13 docker-compose -f dockerfiles/docker-compose.yml run --rm test
```
