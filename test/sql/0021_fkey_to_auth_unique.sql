begin;

  -- 0 issues
  select * from lint."0021_fkey_to_auth_unique";

  -- Satisfy all failure conditions
  create table public.foo(
    id uuid primary key,
    un text not null references auth.users(username)
  );

  -- 1 issue - fkey ref to unique constraint
  select * from lint."0021_fkey_to_auth_unique";

  -- Alter the table adding another fkey based on id
  -- this is the primary key, so it is allowed and should not show up
  -- in the lint
  alter table public.foo
  add constraint fk_foo_user_id
  foreign key (id)
  references auth.users(id);

  -- 1 issue - still only 1 issue because the pkey constraint is okay
  select * from lint."0021_fkey_to_auth_unique";

  drop table public.foo;

  -- 0 issue - still only 1 issue because the pkey constraint is okay
  select * from lint."0021_fkey_to_auth_unique";

rollback;
