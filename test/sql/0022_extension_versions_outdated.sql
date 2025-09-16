begin;

  -- 0 issues initially (all extensions should be up to date)
  select * from lint."0022_extension_versions_outdated";

  create extension amcheck version '1.0';

  -- Verify the query structure and column names
  select
    count(*) as total_outdated_extensions
  from lint."0022_extension_versions_outdated";

  -- Test that the query returns proper column structure
  -- This will help ensure the lint is properly formed
  select
    name,
    title,
    level,
    facing,
    categories,
    description,
    detail,
    remediation,
    metadata,
    cache_key
  from lint."0022_extension_versions_outdated";

  drop extension amcheck;

  -- Versions that aren't in pg_available_extension_versions are ignored
  create extension amcheck;
  update pg_extension set extversion = 'foo' where extname = 'amcheck';

  select
    name,
    title,
    level,
    facing,
    categories,
    description,
    detail,
    remediation,
    metadata,
    cache_key
  from lint."0022_extension_versions_outdated";

  drop extension amcheck;
rollback;
