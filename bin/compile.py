import re
from pathlib import Path
from typing import Dict

LINTS_DIR = "./lints"
HEADER = """set local search_path = '';

-- Used for 0025_public_bucket_allows_listing
do $$
declare
    buckets text;
begin
    if pg_catalog.to_regclass('storage.buckets') is not null then
        select coalesce(
            pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object('bucket_id', id::text, 'bucket_name', name::text)
                order by id
            ),
            '[]'::pg_catalog.jsonb
        )::text
        from storage.buckets
        where public = true
        into buckets;
    else
        buckets := '[]';
    end if;
    perform pg_catalog.set_config('splinter.public_buckets', buckets, true);
end $$;
"""


def load_sql_files(directory_path) -> Dict[str, str]:
    # Convert the directory path to a Path object
    directory = Path(directory_path)

    # Initialize an empty dict to store the concatenated SQL
    queries: Dict[str, str] = {}

    # Check if directory exists
    if not directory.exists():
        raise Exception(f"The directory {directory} does not exist.")

    # Loop through each file in the specified directory
    for file_path in sorted(directory.glob("*.sql")):
        # Open and read the SQL file
        with file_path.open("r") as file:
            # Read the file's content and add it to the concatenated SQL string
            contents = file.read()
            lines = contents.strip().split("\n")

            # Query without semicolons and "create view" statement
            adjusted_contents = "\n".join(
                [line.replace(";", "") for line in lines if "create view" not in line]
            )
            # wrap each query in "(" ")" so queries with CTEs can be unioned
            # without syntax errors
            adjusted_contents = f"({adjusted_contents})"

            queries[file_path.stem] = adjusted_contents
    return queries


# A CTE that several lints compute identically, between these markers. Each lint
# keeps its own copy so it still runs on its own (tests, splinter.json); splinter.sql
# lifts one materialized copy above the union so the work is done once.
SHARED_CTE_RE = re.compile(
    r"[ \t]*-- shared-cte-start: (\w+)\n(.*?)\n[ \t]*-- shared-cte-end\n", re.S
)


def hoist_shared_ctes(sql_map: Dict[str, str]) -> tuple[Dict[str, str], Dict[str, str]]:
    shared: Dict[str, str] = {}
    hoisted: Dict[str, str] = {}
    for stem, query in sql_map.items():
        for name, body in SHARED_CTE_RE.findall(query):
            body = body.strip().rstrip(",")
            if shared.setdefault(name, body) != body:
                raise Exception(
                    f"{stem}: shared CTE {name} differs from another lint's copy"
                )
        hoisted[stem] = SHARED_CTE_RE.sub("", query)
    return shared, hoisted


def compile_sql(sql_map: Dict[str, str]) -> str:
    shared, sql_map = hoist_shared_ctes(sql_map)
    with_clause = ""
    if shared:
        ctes = [
            body.replace(f"{name} as (", f"{name} as materialized (", 1)
            for name, body in shared.items()
        ]
        with_clause = "with\n" + ",\n".join(ctes) + "\n"
    return HEADER + "\n" + with_clause + "\nunion all\n".join(sql_map.values())


def main() -> None:
    sql_map = load_sql_files(LINTS_DIR)
    with open("splinter.sql", "w") as f:
        f.write(compile_sql(sql_map))


if __name__ == "__main__":
    main()
