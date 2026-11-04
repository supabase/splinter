-- Tables that Supabase services create on a real project but the bare postgres image lacks:
-- storage-api's storage schema, GoTrue's MFA and SSO tables, realtime's messages. Enough for
-- project migrations that reference them.
create table if not exists storage.buckets (
    id text primary key,
    name text not null unique,
    owner uuid,
    owner_id text,
    public boolean default false,
    avif_autodetection boolean default false,
    file_size_limit bigint,
    allowed_mime_types text[],
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);
create table if not exists storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets(id),
    name text,
    owner uuid,
    owner_id text,
    metadata jsonb,
    user_metadata jsonb,
    path_tokens text[] generated always as (string_to_array(name, '/')) stored,
    version text,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    last_accessed_at timestamptz default now()
);
create unique index if not exists bucketid_objname on storage.objects (bucket_id, name);
alter table storage.buckets enable row level security;
alter table storage.objects enable row level security;
create or replace function storage.foldername(name text) returns text[] language plpgsql immutable as $f$
declare _parts text[];
begin
    select string_to_array(name, '/') into _parts;
    return _parts[1:array_length(_parts, 1) - 1];
end
$f$;
create or replace function storage.filename(name text) returns text language plpgsql immutable as $f$
declare _parts text[];
begin
    select string_to_array(name, '/') into _parts;
    return _parts[array_length(_parts, 1)];
end
$f$;
create or replace function storage.extension(name text) returns text language plpgsql immutable as $f$
declare _parts text[]; _filename text;
begin
    select string_to_array(name, '/') into _parts;
    select _parts[array_length(_parts, 1)] into _filename;
    return reverse(split_part(reverse(_filename), '.', 1));
end
$f$;
grant usage on schema storage to anon, authenticated, service_role;
grant all on storage.buckets, storage.objects to anon, authenticated, service_role;

create table if not exists auth.mfa_factors (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    friendly_name text,
    factor_type text not null,
    status text not null,
    secret text,
    phone text,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    last_challenged_at timestamptz
);
create table if not exists auth.sso_providers (
    id uuid primary key,
    resource_id text,
    created_at timestamptz,
    updated_at timestamptz
);
create table if not exists auth.sso_domains (
    id uuid primary key,
    sso_provider_id uuid not null references auth.sso_providers(id) on delete cascade,
    domain text not null,
    created_at timestamptz,
    updated_at timestamptz
);
create table if not exists realtime.messages (
    id uuid default gen_random_uuid(),
    topic text not null,
    extension text not null,
    payload jsonb,
    event text,
    private boolean default false,
    inserted_at timestamp not null default now(),
    updated_at timestamp not null default now(),
    primary key (id, inserted_at)
);
alter table realtime.messages enable row level security;
grant usage on schema realtime to anon, authenticated, service_role;
grant select, insert on realtime.messages to anon, authenticated, service_role;
create or replace function realtime.topic() returns text language sql stable as $f$
    select nullif(current_setting('realtime.topic', true), '')::text
$f$;
create or replace function realtime.send(payload jsonb, event text, topic text, private boolean default true)
returns void language plpgsql as $f$
begin
    insert into realtime.messages (payload, event, topic, private, extension)
    values (payload, event, topic, private, 'broadcast');
end
$f$;
-- On a real project postgres may add triggers and policies on these GoTrue tables.
grant all on auth.mfa_factors, auth.sso_providers, auth.sso_domains to postgres;
