
Level: WARN

### Rationale

In PostgreSQL, the `search_path` determines the order in which schemas are searched to find unqualified objects (like tables, functions, etc.). Setting `search_path` explicitly for a function is a best practice that ensures its behavior is consistent and secure, regardless of the executing user's default `search_path` settings. We recommend pinning functions' `search_path` to an empty string, `search_path = ''`, which forces all references within the function's body to be fully qualified. This helps prevent unexpected behavior due to changes in the `search_path` and mitigates potential security vulnerabilities.

### What is the Search Path?

The search path in PostgreSQL is a list of schema names that PostgreSQL checks when trying to resolve unqualified object names like `profiles`. In contrast, a fully qualified name includes the schema like `public.profiles`, and always resolves the same way, regardless of the user's `search_path`. By default, `search_path` includes the user's schema and the `public` schema. However, this can lead to unexpected behavior if different users have different `search_path` settings. Specifically, unqualified references will be resolved differently depending on who is executing the function.

### The Issue with Not Setting the Search Path in Functions

When a function does not have its `search_path` explicitly set, it inherits the `search_path` of the current session when it is invoked. This behavior can lead to several problems:

- **Inconsistency**: The function may behave differently depending on the user's `search_path` settings.
- **Security Risks**: Malicious users could potentially exploit the `search_path` to direct the function to use unexpected objects, such as tables or other functions, that the malicious user controls.

### How to Resolve

To ensure that your functions are secure and behave consistently, set the search path explicitly to an empty string within the function's definition.

Given a function like:

```sql
create function example_function()
  returns void
  language sql
as $$
  -- Your SQL code here
$$;
```

You can `create or replace` the function and add the `search_path` setting.

```sql
create or replace function example_function()
  returns void
  language sql
  set search_path = '' -- LOOK HERE
as $$
  -- Your SQL code here.
$$;
```

Remember that once you set the `search_path = ''` all references to tables/functions/views/etc in your function's body must be qualified with a schema name.
