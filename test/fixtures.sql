-- Important for source SQL to be schema qualified.
set search_path = '';

-- Dummy schema to hold views during testing
create schema lint;

create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql as $$select gen_random_uuid()$$;
create function auth.jwt() returns jsonb language sql as $$select jsonb_build_object()$$;
create function auth.role() returns text language sql as $$select ''$$;
create function auth.email() returns text language sql as $$select ''$$;

create role anon;
create role authenticated;
grant usage on schema public to anon, authenticated;
alter default privileges in schema public grant select on tables to public;
