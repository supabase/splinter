begin;
  set local search_path = '';
  set local pgrst.db_schemas = 'public';

  -- BASELINE: no functions, no rows
  select * from lint."0032_authenticated_dynamic_sql_function_executable";

  savepoint a;

  ----------------------------------------
  -- NEGATIVE: dynamic SQL, but the text parameter is only passed via
  -- EXECUTE ... USING (bound value) and the SQL text is static.
  ----------------------------------------
  create function public.find_user(p_name text) returns int
    language plpgsql
    security definer
    as $$
    declare r int;
    begin
      execute 'select count(*)::int from auth.users where email = $1' into r using p_name;
      return r;
    end $$;
  select * from lint."0032_authenticated_dynamic_sql_function_executable";

  -- NEGATIVE: parameter only used through quote_literal/quote_ident
  create function public.quoted(tbl text) returns int
    language plpgsql
    security definer
    as $$
    declare r int;
    begin
      execute 'select count(*)::int from ' || quote_ident(tbl) into r;
      return r;
    end $$;
  select * from lint."0032_authenticated_dynamic_sql_function_executable";

  -- NEGATIVE: no EXECUTE at all, even with a SQL-shaped parameter name
  create function public.search(query text) returns int
    language plpgsql
    security definer
    as $$
    begin
      return length(query);
    end $$;
  select * from lint."0032_authenticated_dynamic_sql_function_executable";

  -- NEGATIVE: EXECUTE only mentioned in a comment
  create function public.commented(query text) returns int
    language plpgsql
    as $$
    begin
      -- we used to execute query here
      return length(query);
    end $$;
  select * from lint."0032_authenticated_dynamic_sql_function_executable";

  rollback to savepoint a;

  savepoint case_definer;

  ----------------------------------------
  -- POSITIVE (ERROR): the exec_sql shape. SECURITY DEFINER, the
  -- caller-supplied string is concatenated into an EXECUTE.
  ----------------------------------------
  create function public.exec_sql(query text) returns json
    language plpgsql
    security definer
    as $$
    declare r json;
    begin
      execute 'select json_agg(t) from (' || query || ') t' into r;
      return r;
    end $$;

  select
    name,
    level,
    detail,
    metadata->>'security_definer' as security_definer,
    metadata->'sql_parameters' as sql_parameters,
    cache_key
  from lint."0032_authenticated_dynamic_sql_function_executable";

  ----------------------------------------
  -- RESOLUTION: revoke EXECUTE from authenticated and PUBLIC
  ----------------------------------------
  revoke execute on function public.exec_sql(text) from authenticated, public;
  select * from lint."0032_authenticated_dynamic_sql_function_executable";

  rollback to savepoint case_definer;

  savepoint case_invoker;

  ----------------------------------------
  -- POSITIVE (WARN): same shape but SECURITY INVOKER, the function runs
  -- as authenticated. Not covered by lint 0029.
  ----------------------------------------
  create function public.run_query(sql text) returns void
    language plpgsql
    security invoker
    as $$
    begin
      execute sql;
    end $$;

  select name, level, metadata->>'security_definer' as security_definer, cache_key
  from lint."0032_authenticated_dynamic_sql_function_executable";

  rollback to savepoint case_invoker;

  savepoint case_renamed;

  ----------------------------------------
  -- POSITIVE (WARN): renamed wrapper that copies the SQL parameter into a
  -- local variable before EXECUTE, so it is not referenced directly.
  ----------------------------------------
  create function public.insert_entries(sql text) returns void
    language plpgsql
    security definer
    as $$
    declare stmt text;
    begin
      stmt := sql;
      execute stmt;
    end $$;

  select name, level, metadata->'sql_parameters' as sql_parameters, cache_key
  from lint."0032_authenticated_dynamic_sql_function_executable";

  rollback to savepoint case_renamed;

  savepoint case_unnamed;

  ----------------------------------------
  -- POSITIVE (ERROR): unnamed parameter used as `EXECUTE $1`
  ----------------------------------------
  create function public.exec_unnamed(text) returns void
    language plpgsql
    security definer
    as $$
    begin
      execute $1;
    end $$;

  select name, level, metadata->'sql_parameters' as sql_parameters, cache_key
  from lint."0032_authenticated_dynamic_sql_function_executable";

  rollback to savepoint case_unnamed;

  savepoint case_variadic;

  ----------------------------------------
  -- POSITIVE (ERROR): VARIADIC text[] parameter used in an EXECUTE
  ----------------------------------------
  create function public.exec_many(variadic queries text[]) returns void
    language plpgsql
    security definer
    as $$
    begin
      execute queries[1];
    end $$;

  select name, level, metadata->'sql_parameters' as sql_parameters, cache_key
  from lint."0032_authenticated_dynamic_sql_function_executable";

  rollback to savepoint case_variadic;

  savepoint case_system_schema;

  ----------------------------------------
  -- NEGATIVE: function in a system schema is excluded
  ----------------------------------------
  create function auth.exec_sql(query text) returns void
    language plpgsql
    security definer
    as $$
    begin
      execute query;
    end $$;
  select * from lint."0032_authenticated_dynamic_sql_function_executable";

  rollback to savepoint case_system_schema;

rollback;
