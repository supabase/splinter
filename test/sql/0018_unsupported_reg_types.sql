begin;
  set local search_path = '';
  set local pgrst.db_schemas = 'public';

  create table public.bad_table(
    id int primary key,
    -- Allowed
    good1 regclass,
    good2 regrole,
    good3 regtype,
    -- Not Allowed
    bad1 regcollation,
    bad2 regconfig,
    bad3 regdictionary,
    bad4 regnamespace,
    bad5 regoper,
    bad6 regproc,
    bad7 regprocedure
  );

  -- 7 issues
  select * from lint."0018_unsupported_reg_types";

rollback;
