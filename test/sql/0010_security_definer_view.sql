begin;

  -- 0 issues
  select * from lint."0010_security_definer_view";

  create view public.my_view as select 1;

  -- 1 issue
  select * from lint."0010_security_definer_view";

  -- Apply security_invoker
  create or replace view public.my_view with (security_invoker=on) as select 1;

  -- 0 issues
  select * from lint."0010_security_definer_view";


rollback;
