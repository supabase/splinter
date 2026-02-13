
Level: ERROR

## Impact

Sensitive data publicly accessible

### Why it matters

A table with columns that likely contain sensitive data (like passwords or personal identifiers) is accessible through the API without any access restrictions.

### Rationale

Tables exposed via the Supabase Data APIs that contain columns with potentially sensitive data (such as passwords, SSNs, credit card numbers, API keys, or other PII) pose a significant security risk when Row Level Security (RLS) is not enabled. Without RLS, anyone with access to the project's URL and an anonymous or authenticated role can read all data in these tables, potentially exposing sensitive user information.

This lint identifies tables that:
1. Are accessible via the Data API (in exposed schemas like `public`)
2. Have RLS disabled
3. Contain columns with names matching common sensitive data patterns

### Sensitive Column Patterns Detected

The following categories of sensitive data are detected:

**Authentication & Credentials:**
- `password`, `passwd`, `pwd`, `secret`, `api_key`, `token`, `jwt`, `access_token`, `refresh_token`, `session_token`, `auth_code`, `otp`, `2fa_secret`

**Personal Identifiers:**
- `ssn`, `social_security`, `driver_license`, `passport_number`, `national_id`, `tax_id`

**Financial Information:**
- `credit_card`, `card_number`, `cvv`, `bank_account`, `account_number`, `routing_number`, `iban`, `swift_code`

**Health & Medical:**
- `health_record`, `medical_record`, `patient_id`, `insurance_number`, `diagnosis`

**Device & Digital Identifiers:**
- `mac_address`, `imei`, `device_uuid`, `ssh_key`, `pgp_key`, `certificate`

**Biometric Data:**
- `fingerprint`, `biometric`, `facial_recognition`

### How to Resolve

**Option 1: Enable Row Level Security (Recommended)**

Enable RLS on the table and create appropriate policies:

```sql
-- Enable RLS
alter table <schema>.<table> enable row level security;

-- Create a policy that restricts access
create policy "Users can only view their own data"
on <schema>.<table>
for select
using (auth.uid() = user_id);
```

**Option 2: Remove sensitive columns from the table**

If the data doesn't need to be stored, remove the sensitive columns:

```sql
alter table <schema>.<table> drop column <sensitive_column>;
```

**Option 3: Move sensitive data to a separate, protected table**

Store sensitive data in a separate table with proper RLS:

```sql
-- Create a protected table for sensitive data
create table <schema>.<table>_secure (
    id uuid primary key references <schema>.<table>(id),
    <sensitive_column> text
);

-- Enable RLS on the secure table
alter table <schema>.<table>_secure enable row level security;

-- Remove from the exposed table
alter table <schema>.<table> drop column <sensitive_column>;
```

**Option 4: Remove the schema from API exposure**

If the table should not be accessible via APIs at all, remove the schema from the [Exposed schemas in API settings](https://supabase.com/dashboard/project/_/settings/api).

### Example

Given the schema:

```sql
create table public.users(
    id uuid primary key,
    email text not null,
    password_hash text not null,
    ssn text,
    created_at timestamptz default now()
);

grant select on public.users to anon, authenticated;
```

This table is flagged because it contains sensitive columns (`password_hash`, `ssn`) and is accessible via the API without RLS protection. Any user with the project URL can query this table and retrieve all user passwords and social security numbers.

To fix, enable RLS and create appropriate policies:

```sql
alter table public.users enable row level security;

-- Allow users to only read their own data
create policy "Users can view own profile"
on public.users
for select
using (auth.uid() = id);
```
