begin;

  -- 0 issues initially
  select * from lint."0025_pg17_deprecated_extensions";

  create extension adminpack;

  -- 1 issue
  select * from lint."0025_pg17_deprecated_extensions";

rollback;