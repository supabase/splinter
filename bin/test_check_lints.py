"""Pinning tests for check_lints.py's level-column extractor.

Run directly: python3 bin/test_check_lints.py

No test framework in this repo (test/ is pg_regress only) -- assert-based,
so a future edit that re-breaks the multi-line-case guard fails loudly here
instead of only in a mutation test someone has to remember to write by hand.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from check_lints import _level_line_error, _levels_in_lint_sql  # noqa: E402

CASES = {
    "bare literal": ("'INFO' as level,", {"INFO"}),
    "single-line case (0030's own shape)": (
        "case when prs.wal_status = 'lost' then 'ERROR' else 'WARN' end as level,",
        {"ERROR", "WARN"},
    ),
    "single-line nested case": (
        "case when a then 'ERROR' else case when b then 'WARN' else 'INFO' end end as level,",
        {"ERROR", "WARN", "INFO"},
    ),
    "multi-line case, bare end tail": (
        "case\n    when a then 'ERROR'\n    else 'WARN'\nend as level,",
        set(),
    ),
    "multi-line case, value inlined on tail": (
        "case when a then 'ERROR'\n     else 'WARN' end as level,",
        set(),
    ),
    "multi-line case, nested case on tail": (
        "case when a then 'ERROR'\n     else case when b then 'INFO' else 'WARN' end end as level,",
        set(),
    ),
    "trailing comment": ("'WARN' as level, -- always warn", set()),
}

failures = []
for name, (column_line, expected) in CASES.items():
    sql = f"select\n    {column_line}\n    y\nfrom z;"
    actual = _levels_in_lint_sql(sql)
    if actual != expected:
        failures.append(f"{name}: expected {expected!r}, got {actual!r}")

# _level_line_error: an empty sql_levels set means "nothing to compare against", never a
# silent pass, and a doc mentioning no level word is always an error regardless.
if _level_line_error("WARN", set()) is not None:
    failures.append(
        "_level_line_error('WARN', set()) should skip comparison, not error"
    )
if _level_line_error("nothing here", set()) is None:
    failures.append("_level_line_error with no level word should always error")
if _level_line_error("WARN", {"ERROR"}) is None:
    failures.append("_level_line_error should error on a real mismatch")

if failures:
    print(f"{len(failures)} pinning test(s) failed:\n")
    for failure in failures:
        print(f"  - {failure}")
    raise SystemExit(1)
print(f"all {len(CASES)} level-extraction pinning tests passed")
