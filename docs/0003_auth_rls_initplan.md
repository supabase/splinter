
Level: WARN

### Impact

Slow security policy detected

#### Why it matters

A security policy is running its check on every single row instead of once per query, which slows down your database as your tables grow.

### Rationale

Row-Level Security (RLS) policies are the mechanism for controlling access to data based on user roles or attributes. These policies frequently use the built-in `current_setting` function and provided helper functions in the `auth` schema including `auth.uid()`, `auth.role()`, `auth.email()`, and `auth.jwt()` to retrieve information about the current querying user. Improperly written RLS policies can cause these functions to execute once-per-row, rather than once-per-query. While the `current_setting()` and `auth.<function_name>()` functions are efficient, if executed once-per-row they can lead to significant performance bottlenecks at scale.

### The Performance Issue

When an RLS policy is applied to a query, the conditions specified in the policy are evaluated for each row that the query touches. This means that if a policy condition calls a helper function like `auth.uid()`, this function is executed repeatedly for every row. In queries affecting thousands of rows, this behavior can drastically reduce query performance, as the overhead of executing these functions adds up quickly.

### How to Resolve

To optimize the performance of RLS policies using `auth` helper functions we aim to reduce the number of times the helper functions are called. This can be achieved by caching the result of the function call for the duration of the query. Instead of calling the function directly in the policy condition, you can wrap the function call in a subquery. This approach executes the function once, caches the result, and compares this cached value against the column values for all subsequent rows.

For example, consider the policy:

```sql
create policy "inefficient_document_access" on documents
to authenticated
using ( auth.uid() = creator_id );
```

In this policy, `auth.uid()` is called for every row in the `documents` table to check if the `creator_id` matches the current user's ID. If the number of rows in `documents` is 150,000 the `auth.uid()` function will be executed 150,000, potentially incurring over 3 seconds of overhead per query.

If we wrap the `auth.uid()` call in a subquery:

```sql
create policy "efficient_document_access" on user_data
to authenticated
using ( (select auth.uid()) = user_id );
```

Then auth.uid() is called only once at the beginning of the query execution, and its result is reused for each row comparison. That change reduces the overhead from a few seconds to a few microseconds with no impact on the result set.

Since the output values for the `auth` helper functions are set on a per-query basis there is no downside to aggressively applying this performance optimization.
