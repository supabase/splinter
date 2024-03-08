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
    for file_path in directory.glob("*.sql"):
        # Open and read the SQL file
        with file_path.open("r") as file:
            # Read the file's content and add it to the concatenated SQL string
            contents = file.read()
            lines = contents.split("\n")

            queries.append(
                "\n".join([line for line in lines if "create view" not in line])
            )

    return "\nunion all\n".join(queries)


# Example usage
directory_path = "./lints"
concatenated_sql = join_sql_files(directory_path)

with open("lints.sql", "w") as f:
    f.write(concatenated_sql)
