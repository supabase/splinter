
Level: ERROR

## Impact

View bypasses row-level security

### Why it matters

A view in the public schema runs with elevated privileges and ignores Row-Level Security, which could expose more data through the API than intended.

### Rationale

Postgres' default setting for views is SECURITY DEFINER which means they use the permissions of the view's creator, rather than the permissions of the querying user when executing the view's underlying query. That is an unintuitive default, chosen for backwards compatibility with older Postgres versions, which makes it easy to accidentally expose more data in views than was intended.

### Understanding SECURITY DEFINER and SECURITY INVOKER

In PostgreSQL, a view can be defined with either the SECURITY DEFINER or SECURITY INVOKER option.

- **SECURITY DEFINER**: This setting causes the view or function to run with the privileges of the user who created it, regardless of the user who invokes it. This can be useful for allowing a less-privileged user to perform specific tasks that require higher privileges but poses a significant security risk if not handled carefully. It is common for views to be created by highly privileged users with the ability to bypass row level security which further exacerbates the risk.

- **SECURITY INVOKER**: Conversely, with SECURITY INVOKER, the view or function executes with the privileges of the user calling it, respecting the principle of least privilege and significantly reducing the risk of unintentional privilege escalation.

### The Risk of SECURITY DEFINER Views in Public Schema

Creating a view in the public schema makes that view accessible via your project's APIs. If the view is created through Supabase Studio or using the Supabase CLI in SECURITY DEFINER mode, the view will bypass row level security rules and could expose more data publically over the project's APIs than the developer intended.

### How to Resolve

To mitigate the risk, always set `with (security_invoker=on)` when a view should respect RLS policies.

Given the view:

```sql
create view public.order_items
    as
select
    id,
    ...
from
    app.order_items;
```

Enable SECURITY INVOKER mode using:

```sql
create view public.order_items
    with (security_invoker=on)
    as
select
    id,
    ...
from
    app.order_items;
```
