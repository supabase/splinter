import sys
from pathlib import Path


def join_sql_files(directory_path) -> str:
    # Convert the directory path to a Path object
    directory = Path(directory_path)

    # Initialize an empty string to store the concatenated SQL
    queries = []

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

            queries.append(adjusted_contents)
    return "\nunion all\n".join(queries)


# Example usage
directory_path = "./lints"
concatenated_sql = join_sql_files(directory_path)

with open("splinter.sql", "w") as f:
    f.write(concatenated_sql)
