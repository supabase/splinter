begin;

  -- 0 issues
  select * from lint."0011_function_search_path_mutable";

  create or replace function abc()
    returns int
	language sql
  as $$
	select 1;
  $$;

  -- 1 issue
  select * from lint."0011_function_search_path_mutable";

  -- Replace function and set search_path
  create or replace function abc()
    returns int
	set search_path=''
	language sql
  as $$
	select 1;
  $$;

  -- 1 issue
  select * from lint."0011_function_search_path_mutable";

rollback;
