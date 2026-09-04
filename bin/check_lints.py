"""Check that every lint is fully registered.

Adding a lint means touching more than `lints/`: the view has to be loaded by the
test harness, unioned in the compatibility test, documented, and linked in the
docs nav. Each of those is easy to forget, and forgetting most of them fails
quietly -- the suite still goes green, the docs page just never appears.

This script fails loudly instead. For every `lints/NNNN_<name>.sql` it asserts:

    1. the view is named `lint."NNNN_<name>"` (matches the file stem)
    2. `bin/installcheck` loads it
    3. `test/sql/queries_are_unionable.sql` unions it
    4. `docs/NNNN_*.md` exists
    5. `test/sql/NNNN_*.sql` and `test/expected/NNNN_*.out` exist

It also checks that no two lints share a number, and, for every doc page
(including one with no matching SQL view, e.g. 0012, an auth config check):

    6. it is linked from `mkdocs.yaml`'s nav
    7. its `**Level:**` line names exactly the level(s) the lint's own SQL emits

Run via pre-commit, or directly:

    python bin/check_lints.py
"""

import re
import sys
from pathlib import Path

LINTS_DIR = Path("lints")
DOCS_DIR = Path("docs")
TEST_SQL_DIR = Path("test/sql")
TEST_EXPECTED_DIR = Path("test/expected")
INSTALLCHECK = Path("bin/installcheck")
UNIONABLE = TEST_SQL_DIR / "queries_are_unionable.sql"
MKDOCS = Path("mkdocs.yaml")

NO_REGRESS_TEST = {
    # bloat stats are not stable under pg_regress
    "0020_table_bloat"
}

STEM_RE = re.compile(r"^(\d{4})_[a-z0-9_]+$")
LEVEL_LINE_RE = re.compile(r"^\*\*Level:\*\*[ \t]*(.+)$", re.MULTILINE)
LEVEL_WORD_RE = re.compile(r"\b(?:warn|error|info)\b", re.IGNORECASE)
# Line-anchored on purpose: an unrelated `case`/`end` elsewhere in the query (a CTE, a nested case branch) never enters the extracted set.
LEVEL_COL_RE = re.compile(
    r"^\s*(.+?)\s+as\s+level\s*,?\s*$", re.MULTILINE | re.IGNORECASE
)


def _levels_in_lint_sql(sql: str) -> set[str]:
    """The level(s) a lint's `... as level` column emits, or an empty set if no single matching column line is found: zero matches, more than one match (e.g. a CTE's own level column shadowing the view's real one), or a `case` expression split across multiple physical lines. A genuine single-line `case`, however nested, always has as many `end`s as `case`s; a truncated tail line left behind by a split expression has more `end`s than `case`s, however deep the leftover nesting -- either way this line-anchored check treats it as unparseable rather than risk silently extracting an incomplete level set from just that tail line."""
    matches = LEVEL_COL_RE.findall(sql)
    if len(matches) != 1:
        return set()
    column = matches[0]
    if len(re.findall(r"\bend\b", column, re.IGNORECASE)) > len(
        re.findall(r"\bcase\b", column, re.IGNORECASE)
    ):
        return set()
    return {w.upper() for w in LEVEL_WORD_RE.findall(column)}


def _level_line_error(value: str, sql_levels: set[str]) -> str | None:
    doc_levels = {w.upper() for w in LEVEL_WORD_RE.findall(value)}
    if not doc_levels:
        return "does not mention WARN, ERROR, or INFO"
    if sql_levels and doc_levels != sql_levels:
        return f"says {sorted(doc_levels)} but the lint's own SQL emits {sorted(sql_levels)}"
    return None


def find_by_number(directory: Path, number: str, suffix: str) -> list[Path]:
    return sorted(directory.glob(f"{number}_*{suffix}"))


def check() -> list[str]:
    errors: list[str] = []

    installcheck = INSTALLCHECK.read_text()
    unionable = UNIONABLE.read_text()
    mkdocs = MKDOCS.read_text()

    seen_numbers = {}
    levels_by_number: dict[str, set[str]] = {}

    for lint_path in sorted(LINTS_DIR.glob("*.sql")):
        stem = lint_path.stem
        stem_match = STEM_RE.match(stem)
        if not stem_match:
            errors.append(
                f"{lint_path}: name must be NNNN_snake_case (four digits, "
                f"underscore, lowercase)"
            )
            continue
        number = stem_match.group(1)

        if number in seen_numbers:
            errors.append(
                f"{lint_path}: lint number {number} is already used by "
                f"{seen_numbers[number]}; renumber one of them"
            )
        seen_numbers[number] = lint_path

        sql = lint_path.read_text()

        sql_levels = _levels_in_lint_sql(sql)
        if sql_levels:
            levels_by_number[number] = sql_levels
        else:
            errors.append(
                f"{lint_path}: could not determine the level(s) this lint "
                f"emits (expected `'X' as level` or `case ... end as level`, "
                f"on one physical line with no trailing comment)"
            )

        # 1. view name matches the file stem
        if f'create view lint."{stem}"' not in sql.lower():
            errors.append(
                f'{lint_path}: must declare `create view lint."{stem}"` '
                f"(view name has to match the file name)"
            )

        # 2. loaded by the test harness
        if f"-f lints/{number}*.sql" not in installcheck:
            errors.append(
                f"{lint_path}: not loaded by {INSTALLCHECK}; add "
                f"`-f lints/{number}*.sql` before `-d contrib_regression`"
            )

        # 3. unioned in the column-compatibility test
        if f'lint."{stem}"' not in unionable:
            errors.append(
                f"{lint_path}: not covered by {UNIONABLE}; add "
                f'`union all select * from lint."{stem}"`'
            )

        # 4. documented
        if not find_by_number(DOCS_DIR, number, ".md"):
            errors.append(f"{lint_path}: missing docs page {DOCS_DIR}/{number}_*.md")

        # 5. tested
        if stem in NO_REGRESS_TEST:
            continue
        if not find_by_number(TEST_SQL_DIR, number, ".sql"):
            errors.append(f"{lint_path}: missing test {TEST_SQL_DIR}/{number}_*.sql")
        if not find_by_number(TEST_EXPECTED_DIR, number, ".out"):
            errors.append(
                f"{lint_path}: missing expected output "
                f"{TEST_EXPECTED_DIR}/{number}_*.out"
            )

    # steps 6-7 cover every doc page, including docs with no matching SQL view (e.g. 0012, an auth config check)
    for doc in sorted(DOCS_DIR.glob("[0-9]*.md")):
        # 6. every doc page is reachable from the nav
        if doc.name not in mkdocs:
            errors.append(
                f"{doc}: not listed in {MKDOCS}; add it under `nav:` -> `Lints:`"
            )

        # 7. its Level line names exactly the level(s) the lint's own SQL emits
        level_match = LEVEL_LINE_RE.search(doc.read_text())
        if not level_match:
            errors.append(f"{doc}: missing a '**Level:**' line")
        else:
            # Empty set (no matching lint view, or its own level column already errored above) skips the comparison in _level_line_error rather than silently passing.
            doc_sql_levels = levels_by_number.get(doc.stem.split("_", 1)[0], set())
            level_error = _level_line_error(level_match.group(1), doc_sql_levels)
            if level_error:
                errors.append(f"{doc}: Level line {level_error}")

    return sorted(set(errors))


def main() -> None:
    errors = check()
    if errors:
        print(f"{len(errors)} problem(s) found:\n", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        print(
            "\nSee .claude/skills/new-lint/SKILL.md for the full checklist.",
            file=sys.stderr,
        )
        raise SystemExit(1)
    print(f"all {len(list(LINTS_DIR.glob('*.sql')))} lints are fully registered")


if __name__ == "__main__":
    main()
