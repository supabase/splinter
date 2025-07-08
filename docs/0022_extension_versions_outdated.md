Level: WARN

### Rationale

Keeping PostgreSQL extensions up to date is important for maintaining database security and stability. Extension developers regularly release updates that include:

- **Security patches** that fix known vulnerabilities
- **Bug fixes** that resolve functional issues
- **Performance improvements** that optimize database operations

Using outdated extension versions can expose your database to security risks and prevent you from benefiting from the latest improvements. Additionally, Supabase's Service Level Agreement (SLA) for issues resulting from extensions only applies to the default (recommended) version of each extension.

### Why Keep Extensions Updated?

**Security**: Outdated extensions may contain known security vulnerabilities that have been patched in newer versions. These vulnerabilities could potentially be exploited by malicious actors.

**Support**: Supabase provides support and SLA coverage only for the default (recommended) versions of extensions. Running outdated versions may result in limited support options if issues arise.

**Consistency**: Maintaining consistent extension versions across all projects helps ensure predictable behavior and reduces compatibility issues.

**Performance**: Newer versions frequently include performance optimizations and improvements that can benefit your database operations.

### Warning

- Always test extension updates in a development environment before applying them to production
- Some extension updates may include breaking changes, so review the extension's changelog before updating
- Back up your database before performing extension updates

### How to Resolve

To update an extension to its default (recommended) version, use the `ALTER EXTENSION` command:

```sql
ALTER EXTENSION extension_name UPDATE;
```

For example, to update the `uuid-ossp` extension:

First, check the version of the extension that is installed:

```sql
-- Check current extension version
SELECT name, installed_version, default_version
FROM pg_catalog.pg_available_extensions
WHERE name = 'uuid-ossp';
```

This could return:
```
    name     | installed_version | default_version
-------------+-------------------+-----------------
 uuid-ossp   | 1.0               | 1.1
```

To update to the installed version:

```sql
ALTER EXTENSION "uuid-ossp" UPDATE;
```

After updating, verify the installed version matches default:

```sql
SELECT name, installed_version, default_version
FROM pg_catalog.pg_available_extensions
WHERE name = 'uuid-ossp';
```

Should now return:
```
    name     | installed_version | default_version
-------------+-------------------+-----------------
 uuid-ossp   | 1.1               | 1.1
```
