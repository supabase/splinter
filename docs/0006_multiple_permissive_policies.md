
Level: WARNING

### Rationale

In Postgres, Row Level Security (RLS) policies control access to rows in a table based on the executing user. When multiple permissive policies are applied to the same tablequeries against the table, the user may have access to a selected row through any of the policies. This means that, in the worst case, all of the relevant RLS policies must be applied/tested before Postgres can determine if a row should be visible. At scale, these checks add significant overhead to SQL queries and can be a performance bottleneck.


### Row Level Security Policies

RLS policies in Postgres are rules applied to tables that determine whether rows can be selected, inserted, updated, or deleted. These policies can be set to `PERMISSIVE` or `RESTRICTIVE`. Permissive policies allow actions unless explicitly restricted by a restrictive policy. When multiple permissive policies are defined for a table, they act in a cumulative manner — if any policy allows access, the access is granted. In other words, the policies compose with `OR` semantics.

### Risks with Multiple Permissive Policies

#### Access Control

Multiple permissive policies on a table can make it challenging to accurately predict and control which rows are accessible to different users. This complexity can inadvertently lead to overly permissive access configurations, undermining data security and integrity.

#### Performance

Since any one of N permissive policies can provide a user access to a given table's row, in the worst case Postgres must execute all N policies to determine if a row should be visible. These multiple checks raise the probability of a query falling off an index and broadly increase the resource consumption of every query on the impacted table.


### How to Resolve

Consider a table `employee_data` with two permissive policies:

Policy A allows access to employees in the same department.
Policy B allows access to employees at or above a certain grade level.

Our intention is for users to be able to see employee data for employees within their own department who are below the querying user's grade level.

```sql
-- Policy A
create policy department_access on employee_data
    for select
    using (department = current_user_department());

-- Policy B
create policy grade_level_access on employee_data
    for select
    using (grade_level <= current_user_grade_level());
```

The implementation contains a logic error. As written, every employee can see `employee_data` for every other employee within their departemnt. Similarly, every employee can see every other employee's data at or below their own grade level.

To address this issue, we can combine the two policies.

```sql
drop policy department_access on employee_data;
drop policy grade_level_access on employee_data;

create policy consolidated_access on employee_data
    for select
    using (
        department = current_user_department()
        or grade_level >= current_user_grade_level()
    );
```

In addition to addressing the logic bug, we have also improved the Postgres query planner's ability to inline the policy to check access to rows, which reduces the chance of the query falling off index.

While consolidating RLS policies for a given role/action combination is a best practices, it is not a hard rule. If consolidating policies leads to unreadable SQL then you may opt to have multiple policies for maintainability.
