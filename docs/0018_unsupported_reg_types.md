**Level:** WARN

**Summary:** Column type blocks Postgres upgrades

**Ramification:** A table uses a Postgres internal type that is not supported by pg_upgrade, which will prevent you from upgrading to future Postgres versions.

---

### Rationale

Referencing `reg*` types that describe Postgres internals like types, namespaces, procedures, etc is a risk as these types are not supported by [pg_upgrade](https://www.postgresql.org/docs/current/pgupgrade.html), the standard tool for upgrading between Postgres versions.

### How to Resolve

If a reference to an disallowed `reg*` type is needed:

```sql
create table public.bad_table(
  id int primary key,
  -- Not Allowed
  my_collation regcollation
);
```

Store the test representation of the object instead so that it will be compatible with upgrade.

```sql
create table public.good_table(
  id int primary key,
  -- Not Allowed
  my_collation_name text
);
```
