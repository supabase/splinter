
Level: WARN

### Rationale

Entities like tables and functions in the `public` schema are exposed through Supabase APIs by default. When extensions are installed in the `public` schema, the functions, tables, views, etc that they contain appear to be part of your project's API.


### How to Resolve

To relocate an extension from the `public` schema to another schema, execute:

```sql
alter extension <some_extension> set schema <some_schema>;
```

### Example

If the `ltree` extension was initially created in thh `public` schema with

```sql
create extension ltree;
```
or
```sql
create extension ltree schema public;
```

You can relocate its components to the `extensions` schema by running

```sql
alter extension ltree set schema extensions;
```
