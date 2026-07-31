"""Generate splinter.json, a structured manifest of the splinter lints.

Unlike splinter.sql (a single monolithic `union all` query), this emits each
lint as a discrete, self-describing entry so downstream consumers can select,
filter, and combine lints by reading fields instead of parsing SQL text.

Shape:
    {
      "version": "<CalVer YYYY.MM.Micro>",
      "setup": "<prelude run once, verbatim, before the lints>",
      "lints": [ { "name", "categories", "query" }, ... ]
    }

`query` is the same union-ready, parenthesized SQL that compile.py emits for
splinter.sql; consumers treat it as opaque. `name` and `categories` are lifted
out of each lint's SQL here, at build time, so a malformed lint fails CI loudly
rather than a consumer's regex failing silently against a live database.

This file is NOT committed; it is generated in CI and published as a release
artifact (see .github/workflows/release.yml).
"""

import argparse
import json
import os
import re
import sys
from typing import Dict, List

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import compile  # noqa: E402  (bin/compile.py; import after sys.path setup)

NAME_RE = re.compile(r"'([a-z0-9_]+)'\s+as\s+name", re.IGNORECASE)
CATEGORIES_RE = re.compile(
    r"array\[(.*?)\]\s+as\s+categories", re.IGNORECASE | re.DOTALL
)


def extract_name(stem: str, query: str) -> str:
    matches = NAME_RE.findall(query)
    if len(matches) != 1:
        raise SystemExit(
            f"lint {stem!r}: expected exactly one \"'<name>' as name\", "
            f"found {len(matches)}"
        )
    return matches[0]


def extract_categories(stem: str, query: str) -> List[str]:
    match = CATEGORIES_RE.search(query)
    if not match:
        raise SystemExit(f'lint {stem!r}: could not find "array[...] as categories"')
    categories = [
        part.strip().strip("'\"") for part in match.group(1).split(",") if part.strip()
    ]
    if not categories:
        raise SystemExit(f"lint {stem!r}: empty categories array")
    return categories


def build_manifest(version: str) -> Dict[str, object]:
    sql_map = compile.load_sql_files(compile.LINTS_DIR)
    lints = [
        {
            "name": extract_name(stem, query),
            "categories": extract_categories(stem, query),
            "query": query,
        }
        for stem, query in sql_map.items()
    ]
    return {
        "version": version,
        "setup": compile.HEADER.strip(),
        "lints": lints,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate splinter.json manifest")
    parser.add_argument(
        "--version",
        default="0.0.0-dev",
        help="Manifest version, CalVer YYYY.MM.Micro (defaults to a dev placeholder)",
    )
    parser.add_argument("--output", default="splinter.json")
    args = parser.parse_args()

    manifest = build_manifest(args.version)
    with open(args.output, "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

    print(
        f"wrote {args.output}: {len(manifest['lints'])} lints, version {args.version}"
    )


if __name__ == "__main__":
    main()
