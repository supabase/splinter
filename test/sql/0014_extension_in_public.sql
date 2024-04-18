begin;
  set local search_path = '';

  -- 0 issues
  select * from lint."0014_extension_in_public";

  create extension ltree schema public;

  -- 1 issues
  select * from lint."0014_extension_in_public";

  -- resolve the problem
  alter extension ltree set schema extensions;
  
  -- 0 issues
  select * from lint."0014_extension_in_public";

rollback;
