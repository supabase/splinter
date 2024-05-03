begin;
  set local search_path = '';

  -- 0 issues
  select * from lint."0016_materialized_view_in_api";

  create materialized view public.my_view as select 1;

  -- 1 issue
  select * from lint."0016_materialized_view_in_api";

  -- Resolve the issue with permissions
  revoke select on public.my_view from anon, authenticated, public;

  -- 0 issues
  select * from lint."0016_materialized_view_in_api";


rollback;
