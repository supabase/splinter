create schema auth;
create view auth.users as select 1;

create role anon;
create role authenticated;
grant usage on schema public to anon, authenticated;
alter default privileges in schema public grant select on tables to public;
