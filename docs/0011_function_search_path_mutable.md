
**Level:** WARN

**Summary:** Unsecured function search path

**Ramification:** Without a fixed search path, this function could behave unpredictably or be exploited to reference unintended database objects.

---

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

### Effect on SQL Function Inlining

Pinning the search path has a cost that is worth knowing about before applying it everywhere: PostgreSQL will not inline a `language sql` function that carries a `SET` clause. Inlining is what lets the planner fold a simple SQL function into the calling query and push the caller's `where` clause down into it. Once the function is pinned, the call becomes a `Function Scan`, the function runs to completion, and the caller filters the result afterwards.

Given a table with 200,000 rows and an index on `tenant`, and two functions whose bodies are identical and fully qualified:

```sql
create function inline_test.all_items()
  returns setof inline_test.items
  language sql
  stable
as $$
  select * from inline_test.items;
$$;

create function inline_test.all_items_pinned()
  returns setof inline_test.items
  language sql
  stable
  set search_path = ''
as $$
  select * from inline_test.items;
$$;
```

Calling the unpinned function, the filter reaches the index:

```
Bitmap Heap Scan on items  (actual time=0.060..0.423 rows=200 loops=1)
  Recheck Cond: (tenant = 'tenant_42'::text)
  Buffers: shared hit=203
  ->  Bitmap Index Scan on items_tenant_idx  (actual time=0.049..0.049 rows=200 loops=1)
        Index Cond: (tenant = 'tenant_42'::text)
```

Calling the pinned one, it does not:

```
Function Scan on all_items_pinned  (actual time=23.577..32.990 rows=200 loops=1)
  Filter: (tenant = 'tenant_42'::text)
  Rows Removed by Filter: 199800
  Buffers: shared hit=1748, temp read=1219 written=1219
```

The pinned call reads roughly eight times as many shared buffers and spills 1,219 temporary blocks that the inlined plan never touches, and the gap widens as the table grows.

This is caused by the presence of a `SET` clause, not by the empty value, so `set search_path = 'some_schema'` loses inlining in exactly the same way. There is no formulation of this fix that keeps it.

### When This Matters

For most functions it does not:

- **`language plpgsql` functions are unaffected.** PostgreSQL never inlines them, so pinning the search path costs nothing. If your function is written in PL/pgSQL, apply the fix and move on.
- **`language sql` functions that are not on a hot path** pay a cost nobody will notice.

It matters for a `language sql` function that is called inside a larger query and relies on the planner pushing predicates into it.

If that function takes no arguments, a view is usually the better shape. It produces the same plan as the inlined function, and because a view stores resolved references rather than names, it does not depend on the caller's search path at all:

```sql
create view inline_test.all_items_view as
  select * from inline_test.items;
```

```
Bitmap Heap Scan on items  (actual time=0.047..2.137 rows=200 loops=1)
  Recheck Cond: (tenant = 'tenant_42'::text)
  Buffers: shared hit=203
  ->  Bitmap Index Scan on items_tenant_idx
        Index Cond: (tenant = 'tenant_42'::text)
```

Two things to check before swapping a function for a view. A view is not a drop-in replacement for a function that takes arguments; if you need parameters, either keep the function and accept the cost, or expose a view and let callers supply their own `where` clause. And a view runs with the privileges of its owner unless it is created with `security_invoker = true`, so confirm that matches what the function was doing before you make the change (see [security_definer_view](0010_security_definer_view.md)).

Measure before rewriting anything. The plan is the thing to check: if the call shows up as a `Function Scan` with a large `Rows Removed by Filter`, inlining was lost and the function is a candidate for becoming a view.
