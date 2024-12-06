
Level: ERROR

### Rationale

Queues exposed over Data APIs must be secured by Postgres permissions or row level security (RLS). Without this protection, anyone with a project's URL can manipulate queue data. That is a critically unsafe configuration.

### How to Resolve

To secure a queue, enable RLS on the queue's underlying table `pgmq.q_<queue_name>`:

```sql
alter table pgmq.q_<queue_name> enable row level security;
```

Note that after enabling RLS you will not be able to access data in the queue over APIs until you create [row level security policies](https://supabase.com/docs/guides/auth/row-level-security) to control access.

### Example

Given a queue named `foo` and underlying table `pgmq.q_foo`:

```sql
create table pgmq.q_foo(
    msg_id bigint generated always as identity,
    read_ct int default 0 not null,
    enqueued_at timestamp with timezone default now() not null,
    vt timestamp with time zone not null,
    message jsonb
);
```

If Data APIs are enabled, and `anon` or `authenticated` have permissions on the table, any user with access to the project's URL and public API key will be able to manipulate messages in that Queue. To restrict access to users specified in row level security policies, enable RLS with:

```sql
alter table pgmq.q_foo enable row level security;
```

If queues are not being accessed through data APIs, an alternative is to remove the `pgmq_public` schema from the [Exposed schemas in API settings](https://supabase.com/dashboard/project/_/settings/api). That change secures your project by making all queues inaccessible over APIs.
