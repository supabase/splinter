-- Synthetic Supabase-like schema for benchmarking the lints (see bench/README.md).
-- Run as supabase_admin on a fresh image, after projects/services-stub.sql.

-- Schema-wide objects that exercise lints a per-table loop cannot reach.
create or replace function auth.jwt() returns jsonb language sql stable as $f$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $f$;
create schema if not exists app;
create schema if not exists billing;
create schema if not exists private;
grant usage on schema app, billing to anon, authenticated;
do $$ begin for i in 1..20 loop execute format('create type app.enum_%s as enum (''a'',''b'',''c'')', i); end loop; end $$;

-- 0002 auth_users_exposed
create view public.exposed_users as select id, email from auth.users;
grant select on public.exposed_users to anon, authenticated;

-- 0014 extension_in_public, 0022 extension_versions_outdated
create extension if not exists ltree schema public;
create extension if not exists pg_graphql;

-- 0017 foreign_table_in_api
create extension if not exists postgres_fdw schema extensions;
create server bench_fdw foreign data wrapper postgres_fdw options (host 'localhost', dbname 'postgres');
create foreign table public.fdw_events (id int) server bench_fdw;
create foreign table app.fdw_audit (id int) server bench_fdw;

-- 0019 insecure_queue_exposed_in_api (stubbed like test/sql/0019)
create schema if not exists pgmq;
create schema if not exists pgmq_public;
create table pgmq.q_jobs (id int);
create table pgmq.q_mail (id int);
grant usage on schema pgmq to anon, authenticated;
grant select on pgmq.q_jobs, pgmq.q_mail to anon, authenticated;

-- 0025 public_bucket_allows_listing
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true), ('docs', 'docs', false) on conflict do nothing;
create policy "public read avatars" on storage.objects for select to anon using (bucket_id = 'avatars');

-- 0021 fkey_to_auth_unique
create table public.email_contacts (email varchar(255) references auth.users(email));

-- 0022 extension_versions_outdated
create extension if not exists amcheck version '1.0';

-- 0020 table_bloat: ~50 MB of dead tuples. Autovacuum is off so the pages stay until analyze.
create table public.bloated (id bigint generated always as identity primary key, pad text) with (autovacuum_enabled = false);
insert into public.bloated (pad) select repeat('x', 100) from generate_series(1, 400000);
delete from public.bloated where id > 100;
