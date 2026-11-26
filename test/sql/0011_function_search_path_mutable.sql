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


  -- An aggregate is not reported: CREATE AGGREGATE has no SET clause, so its
  -- pg_proc entry can never carry a search_path
  create function public.uuid_min(uuid, uuid)
    returns uuid
    set search_path = ''
    language sql
    immutable strict
  as $$
    select least($1, $2);
  $$;

  create aggregate public.min_uuid(uuid) (
    sfunc = public.uuid_min,
    stype = uuid,
    combinefunc = public.uuid_min,
    parallel = safe
  );

  -- 0 issues
  select * from lint."0011_function_search_path_mutable";

  -- The support function is still linted on its own
  create or replace function public.uuid_min(uuid, uuid)
    returns uuid
    language sql
    immutable strict
  as $$
    select least($1, $2);
  $$;

  -- 1 issue, for public.uuid_min and not for the aggregate
  select * from lint."0011_function_search_path_mutable";


rollback;
