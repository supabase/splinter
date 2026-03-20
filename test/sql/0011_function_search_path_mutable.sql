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



rollback;
