begin;
  set local search_path = '';
  set local pgrst.db_schemas = 'public';

  -- 0 issues - no tables yet
  select * from lint."0023_sensitive_columns_exposed";

  -- Create a table with sensitive columns (password, ssn)
  create table public.users(
    id int primary key,
    username text not null,
    password text not null,
    ssn text
  );

  -- 1 issue - table has sensitive columns without RLS
  select * from lint."0023_sensitive_columns_exposed";

  -- Create another table with financial data
  create table public.payments(
    id int primary key,
    user_id int references public.users(id),
    credit_card text,
    cvv text,
    amount numeric
  );

  -- 2 issues - both tables have sensitive columns
  select count(*) from lint."0023_sensitive_columns_exposed";

  -- Resolve the issue by enabling RLS on users table
  alter table public.users enable row level security;

  -- 1 issue - only payments table now
  select count(*) from lint."0023_sensitive_columns_exposed";

  -- Enable RLS on payments table
  alter table public.payments enable row level security;

  -- 0 issues - all tables protected
  select * from lint."0023_sensitive_columns_exposed";

  -- Create a table without sensitive columns
  create table public.posts(
    id int primary key,
    title text,
    content text,
    created_at timestamptz default now()
  );

  -- 0 issues - posts table has no sensitive columns
  select * from lint."0023_sensitive_columns_exposed";

  -- Confirm that the lint only applies to `public` tables
  create schema private_schema;
  create table private_schema.secrets(
    id int primary key,
    api_key text,
    secret_token text
  );

  -- 0 issues - private_schema is not exposed via API
  select * from lint."0023_sensitive_columns_exposed";

rollback;
