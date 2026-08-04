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
    6. `mkdocs.yaml` links that doc page

It also checks that no two lints share a number, and that every doc page is in
the nav. Run via pre-commit, or directly:

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


def find_by_number(directory: Path, number: str, suffix: str) -> list[Path]:
    return sorted(directory.glob(f"{number}_*{suffix}"))


def check() -> list[str]:
    errors: list[str] = []

    installcheck = INSTALLCHECK.read_text()
    unionable = UNIONABLE.read_text()
    mkdocs = MKDOCS.read_text()

    seen_numbers = {}

    for lint_path in sorted(LINTS_DIR.glob("*.sql")):
        stem = lint_path.stem
        match = STEM_RE.match(stem)
        if not match:
            errors.append(
                f"{lint_path}: name must be NNNN_snake_case (four digits, "
                f"underscore, lowercase)"
            )
            continue
        number = match.group(1)

        if number in seen_numbers:
            errors.append(
                f"{lint_path}: lint number {number} is already used by "
                f"{seen_numbers[number]}; renumber one of them"
            )
        seen_numbers[number] = lint_path

        # 1. view name matches the file stem
        if f'create view lint."{stem}"' not in lint_path.read_text().lower():
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
        docs = find_by_number(DOCS_DIR, number, ".md")
        if not docs:
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

    # Step 6: every doc page is reachable from the nav. Covers docs for lints
    # that are not SQL views too (e.g. 0012, an auth config check).
    for doc in sorted(DOCS_DIR.glob("[0-9]*.md")):
        if doc.name not in mkdocs:
            errors.append(
                f"{doc}: not listed in {MKDOCS}; add it under `nav:` -> `Lints:`"
            )

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
