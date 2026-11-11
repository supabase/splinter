begin;
  set local search_path = '';
  set local pgrst.db_schemas = 'public';

  -- BASELINE: 0 issues on an empty schema
  select * from lint."0034_definer_function_uses_current_user";

  create table public.items(id int primary key, owner_name text);

  savepoint a;

  -- NEGATIVE EXAMPLE: SECURITY INVOKER function. current_user really is the
  -- caller here, so the check is meaningful. Must not fire.
  create function public.invoker_check() returns boolean
  language sql security invoker as $$ select current_user = 'authenticated' $$;

  -- NEGATIVE EXAMPLE: definer function that identifies the caller correctly
  create function public.uses_uid() returns boolean
  language sql security definer set search_path = '' as $$ select auth.uid() is not null $$;

  -- NEGATIVE EXAMPLE: the identifiers only appear inside a comment, a string
  -- literal, a quoted identifier or a longer name. None is the keyword.
  create function public.lookalikes(user_id int) returns text
  language plpgsql security definer set search_path = '' as $$
  declare
    current_user_label text := 'current_user = admin';
  begin
    -- current_user = 'postgres' would be wrong here
    return current_user_label || user_id::text;
  end
  $$;

  -- NEGATIVE EXAMPLE: current_user is only recorded, never compared
  create function public.audit_insert() returns void
  language sql security definer set search_path = '' as $$
    insert into public.items(id, owner_name) values (1, current_user)
  $$;

  -- NEGATIVE EXAMPLE: current_user assigned to an audit column
  create function public.audit_update() returns void
  language sql security definer set search_path = '' as $$
    update public.items set owner_name = current_user where id = 1
  $$;

  -- NEGATIVE EXAMPLE: identity is switched before the check
  create function public.switches_role() returns boolean
  language plpgsql security definer set search_path = '' as $$
  begin
    set local role authenticated;
    return current_user = 'authenticated';
  end
  $$;

  select * from lint."0034_definer_function_uses_current_user";  -- expect 0 rows

  rollback to savepoint a;

  -- POSITIVE EXAMPLE: comparison with a literal. Always the function owner.
  create function public.is_admin() returns boolean
  language sql security definer set search_path = '' as $$ select current_user = 'admin_role' $$;

  -- POSITIVE EXAMPLE: current_user on the right of a comparison in a row filter
  create function public.my_items() returns setof public.items
  language sql security definer set search_path = '' as $$
    select * from public.items where owner_name = current_user
  $$;

  -- POSITIVE EXAMPLE: membership check, in plpgsql
  create function public.require_member() returns void
  language plpgsql security definer set search_path = '' as $$
  begin
    if not pg_catalog.pg_has_role(current_user, 'staff', 'member') then
      raise exception 'not allowed';
    end if;
  end
  $$;

  select name, detail, cache_key from lint."0034_definer_function_uses_current_user";  -- expect 3 rows

  -- RESOLUTION: identify the caller from the JWT instead
  create or replace function public.is_admin() returns boolean
  language sql security definer set search_path = '' as $$ select auth.role() = 'service_role' $$;
  create or replace function public.my_items() returns setof public.items
  language sql security definer set search_path = '' as $$
    select * from public.items where owner_name = auth.uid()::text
  $$;
  create or replace function public.require_member() returns void
  language plpgsql security definer set search_path = '' as $$
  begin
    if auth.uid() is null then
      raise exception 'not allowed';
    end if;
  end
  $$;

  select * from lint."0034_definer_function_uses_current_user";  -- expect 0 rows

rollback;
