# pylint: disable=redefined-outer-name,no-member

import json
import os
import subprocess
import time
from typing import Generator

import pytest
from parse import parse
from sqlalchemy import create_engine
from sqlalchemy.engine import Connection
from sqlalchemy.orm import Session


PYTEST_DB = "postgresql+psycopg://postgres:password@localhost:5615/postgres"


@pytest.fixture(scope="session")
def maybe_start_pg() -> Generator[None, None, None]:
    """Creates a local Supabase instance that can be connected
    to using the PYTEST_DB connection string"""

    container_name = "splinter_pg"
    image = "supabase/postgres"

    connection_template = "postgresql+psycopg://{user}:{pw}@{host}:{port:d}/{db}"
    conn_args = parse(connection_template, PYTEST_DB)

    port: int = conn_args["port"]  # type: ignore
    db: str = conn_args["db"]  # type: ignore
    pw: str = conn_args["pw"]  # type: ignore
    user: str = conn_args["user"]  # type: ignore

    # Don't attempt to instantiate a container if
    # we're on CI
    if "GITHUB_SHA" in os.environ:
        yield
        return

    try:
        is_running = (
            subprocess.check_output(
                ["docker", "inspect", "-f", "{{.State.Running}}", container_name]
            )
            .decode()
            .strip()
            == "true"
        )
    except subprocess.CalledProcessError:
        # Can't inspect container if it isn't running
        is_running = False

    if is_running:
        yield
        return

    subprocess.call(
        [
            "docker",
            "run",
            "--rm",
            "--name",
            container_name,
            "-p",
            f"{port}:5432",
            "-d",
            "-e",
            f"POSTGRES_DB={db}",
            "-e",
            f"POSTGRES_PASSWORD={pw}",
            "-e",
            f"POSTGRES_USER={user}",
            "--health-cmd",
            "pg_isready",
            "--health-interval",
            "3s",
            "--health-timeout",
            "3s",
            "--health-retries",
            "15",
            image,
        ]
    )
    # Wait for postgres to become healthy
    for _ in range(10):
        out = subprocess.check_output(["docker", "inspect", container_name])
        inspect_info = json.loads(out)[0]
        health_status = inspect_info["State"]["Health"]["Status"]
        if health_status == "healthy":
            break
        else:
            time.sleep(1)
    else:
        raise Exception("Could not reach postgres comtainer. Check docker installation")
    yield
    # subprocess.call(["docker", "stop", container_name])
    return


@pytest.fixture(scope="session")
def connection(maybe_start_pg: None) -> Generator[Connection, None, None]:
    """sqlalchemy engine fixture"""
    eng = create_engine(PYTEST_DB)
    with eng.begin() as con:
        yield con
    eng.dispose()


@pytest.fixture()
def sess(connection) -> Generator[Session, None, None]:
    with Session(connection) as sess:
        yield sess
        sess.rollback()
