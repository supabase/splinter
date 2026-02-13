Level: ERROR

## Impact

Foreign key blocks Auth upgrades

### Why it matters

A foreign key references a constraint in the auth schema that is scheduled for removal, which will prevent future Auth updates and security patches.

### Rationale

Supabase Auth does not support user-defined foreign keys that reference non-primary key unique constraints in the `auth` schema. These unique constraints are scheduled for removal, and any foreign keys referencing them will block Supabase Auth's database migrations from completing successfully. If Supabase Auth is unable to upgrade, it prevents the rollout of new features and critical security updates.

### How to Resolve

To ensure successful migrations and continued updates:

1. Drop Foreign Keys: Remove any foreign key constraints that reference unique constraints in the `auth` schema.

```sql
alter table public.some_tablee
drop constraint some_foreign_key;
```

2. Reference Primary Keys Instead: If applicable, replace references to unique constraints with references to the corresponding table's primary key.
