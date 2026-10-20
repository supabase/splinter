-- Objects for tables :lo..:hi, one transaction per chunk (stays under max_locks_per_transaction).
-- Every lint gets findings at every size: the modulo constants pick which tables carry which defect.
select set_config('bench.lo', :'lo', false), set_config('bench.hi', :'hi', false);
do $$
declare i int; s text; t text;
begin
  for i in current_setting('bench.lo')::int .. current_setting('bench.hi')::int loop
    s := (array['public','app','billing','private'])[1 + i % 4];
    t := format('%I.t_%s', s, i);
    execute format(
      'create table %s (id bigint generated always as identity primary key, owner uuid, status app.enum_%s, payload jsonb, created_at timestamptz default now(), parent_id bigint%s%s%s)',
      t, 1 + i % 20,
      case when i % 23 = 0 then ', ssn text, password text' else '' end,
      case when i % 29 = 0 then ', handler regproc' else '' end,
      case when i % 31 = 0 then ', user_id uuid references auth.users(id)' else '' end);
    if i > 4 then
      execute format('alter table %s add constraint fk_%s foreign key (parent_id) references %I.t_%s(id)', t, i, s, i - 4);
      if i % 2 = 0 then execute format('create index on %s (parent_id)', t); end if;
    end if;
    execute format('create index on %s (owner, created_at)', t);
    if i % 9 = 0 then execute format('create index on %s (owner, created_at)', t); end if;
    execute format('create index on %s using gin (payload)', t);
    if i % 7 <> 0 then execute format('alter table %s enable row level security', t); end if;
    if i % 3 <> 0 then execute format('create policy sel_%s on %s for select to authenticated using (owner = auth.uid())', i, t); end if;
    if i % 5 = 0 then execute format('create policy sel2_%s on %s for select to authenticated using (status = ''a'')', i, t); end if;
    if i % 3 = 1 then execute format('create policy ins_%s on %s for insert to authenticated with check (owner = (select auth.uid()))', i, t); end if;
    if i % 11 = 0 then execute format('create policy all_%s on %s for all to anon using (true) with check (true)', i, t); end if;
    if i % 13 = 0 then execute format('create policy meta_%s on %s for select using ((auth.jwt() -> ''user_metadata'' ->> ''role'') = ''admin'')', i, t); end if;
    if i % 19 = 0 then execute format('alter table %s set (autovacuum_enabled = false)', t); end if;
    if i % 17 = 0 then execute format('create table %I.nopk_%s (id bigint, note text)', s, i); end if;
    execute format('comment on table %s is ''table %s''', t, i);
    if i % 4 = 0 then execute format('create view %I.v_%s %s as select id, owner from %s', s, i, case when i % 8 = 0 then '' else 'with (security_invoker = true)' end, t); end if;
    if i % 10 = 0 then execute format('create materialized view %I.mv_%s as select id from %s', s, i, t); end if;
    if i % 2 = 0 then
      execute format('create function %I.f_%s(x int) returns int language sql %s %s as ''select x + 1''', s, i,
        case when i % 4 = 0 then '' else 'set search_path = ''''' end,
        case when i % 6 = 0 then 'security definer' else '' end);
    end if;
    if i % 4 = 0 then
      execute format('create function %I.trg_%s() returns trigger language plpgsql set search_path = '''' as $f$ begin new.created_at := now(); return new; end $f$', s, i);
      execute format('create trigger tr_%s before update on %s for each row execute function %I.trg_%s()', i, t, s, i);
    end if;
  end loop;
end $$;
