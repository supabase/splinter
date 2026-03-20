begin;

  set local search_path = '';
  set local pgrst.db_schemas = 'public';

  -- 0 issues
  select * from lint."0019_insecure_queue_exposed_in_api";

  -- Satisfy all failure conditions
  create schema pgmq;
  create schema pgmq_public;
  create table pgmq.q_foo(id int);
  create table pgmq.q_bar(id int);
  set local pgrst.db_schemas = 'public,pgmq_public';

  grant usage on schema pgmq to anon, authenticated;
  grant usage on schema pgmq_public to anon, authenticated;
  grant select on pgmq.q_foo to anon, authenticated;
  grant select on pgmq.q_bar to anon, authenticated;


  -- 2 issue - because not in schema
  select * from lint."0019_insecure_queue_exposed_in_api";

  savepoint a;

  -- dropping select permission resolves issue
  revoke select on pgmq.q_foo from anon, authenticated;
  revoke select on pgmq.q_bar from anon, authenticated;

  -- 0 issue - because not in schema
  select * from lint."0019_insecure_queue_exposed_in_api";

  -- restore to failure mode
  rollback to savepoint a;
  select count(*) from lint."0019_insecure_queue_exposed_in_api";

  set local pgrst.db_schemas = 'public,pgmq_public';

  -- 0 issue - because not in schema
  select * from lint."0019_insecure_queue_exposed_in_api";

  -- restore to failure mode
  rollback to savepoint a;
  select count(*) from lint."0019_insecure_queue_exposed_in_api";

  alter table pgmq.q_foo enable row level security;
  alter table pgmq.q_bar enable row level security;

  -- 0 issue - because RLS is active
  select * from lint."0019_insecure_queue_exposed_in_api";


rollback;
