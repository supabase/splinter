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


sql_map = load_sql_files(LINTS_DIR)

with open("splinter.sql", "w") as f:
    f.write(HEADER + "\n" + "\nunion all\n".join(sql_map.values()))
