begin;
  set local search_path = '';
  set local pgrst.db_schemas = 'public';

  create extension postgres_fdw schema extensions;

  -- 0 issues
  select * from lint."0018_unsupported_reg_types";

  -- Setup
  create server foreign_server
    foreign data wrapper postgres_fdw
    options (host 'foreignhost', port '5432', dbname 'foreign_db');

  create user mapping for current_user
    server foreign_server
    options (user 'foreign_user', password 'foreign_password');

  create foreign table public.fdw_table (
    id integer,
    data text
  )
    server foreign_server
    options (table_name 'foreign_table');


  -- 1 issue
  select * from lint."0018_unsupported_reg_types";

  savepoint a;

  -- When not on API path, no problem reported
  -- 0 issues
  set local pgrst.db_schemas = '';
  select * from lint."0018_unsupported_reg_types";

  rollback to savepoint a;

  -- Resolve the issue with permissions
  revoke select on public.fdw_table from anon, authenticated, public;

  -- 0 issues
  select * from lint."0018_unsupported_reg_types";

rollback;
