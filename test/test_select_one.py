import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
)


def test_select_one(sess) -> None:
    res = sess.execute(text("select 1;")).scalar()
    assert res == 1
