begin;
  set local search_path = '';

  -- 0 issues
  select * from lint."0011_function_search_path_mutable";

  create or replace function public.abc()
    returns int
    language sql
  as $$
    select 1;
  $$;

  -- 1 issue
  select * from lint."0011_function_search_path_mutable";

  -- Replace function and set search_path to empty string
  create or replace function public.abc()
    returns int
    set search_path=''
    language sql
  as $$
    select 1;
  $$;

  -- 1 issue
  select * from lint."0011_function_search_path_mutable";

  -- Replace function and set search_path to non-empty string
  create or replace function public.abc()
    returns int
    set search_path='public'
    language sql
  as $$
    select 1;
  $$;

  -- 1 issue
  select * from lint."0011_function_search_path_mutable";

  -- Create an aggregate function (should not be flagged)
  create function public.mysum_state(state integer, val integer)
    returns integer
    language sql
    set search_path = ''
  as $$
    select state + val;
  $$;

  create aggregate public.mysum(integer) (
    sfunc = public.mysum_state,
    stype = integer,
    initcond = '0'
  );

  -- 0 issues: aggregate is excluded, state function has search_path set
  select * from lint."0011_function_search_path_mutable";

rollback;
