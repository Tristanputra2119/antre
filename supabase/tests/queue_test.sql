-- Business-rule tests for the RPCs. Runs in one transaction and rolls back,
-- so it is safe on a dev database (Supabase SQL editor or psql).
-- Any failed check raises an exception; success ends with "ALL QUEUE TESTS PASSED".

begin;

-- ---------------------------------------------------------------- helpers

create function pg_temp.login(p_uid uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_uid)::text, true);
$$;

create function pg_temp.check(p_ok boolean, p_label text) returns void
language plpgsql as $$
begin
  if p_ok is not true then
    raise exception 'FAILED: %', p_label;
  end if;
  raise notice 'ok - %', p_label;
end;
$$;

create function pg_temp.expect_error(p_sql text, p_code text) returns void
language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlerrm = p_code then
      raise notice 'ok - % raises %', p_sql, p_code;
      return;
    end if;
    raise exception 'FAILED: % expected %, got %', p_sql, p_code, sqlerrm;
  end;
  raise exception 'FAILED: % expected %, but succeeded', p_sql, p_code;
end;
$$;

-- Fixed ids: a = customer A, b = customer B, c = customer C, d = admin.
insert into auth.users (id) values
  ('aaaaaaaa-0000-0000-0000-000000000000'),
  ('bbbbbbbb-0000-0000-0000-000000000000'),
  ('cccccccc-0000-0000-0000-000000000000'),
  ('dddddddd-0000-0000-0000-000000000000');
insert into admins (user_id) values ('dddddddd-0000-0000-0000-000000000000');

create temp view v_active as select * from queue_sessions where is_active;
grant select on v_active to authenticated;

set local role authenticated;

-- ---------------------------------------------------------------- F-P1 take_ticket

select pg_temp.login('aaaaaaaa-0000-0000-0000-000000000000');
select pg_temp.expect_error($$select take_ticket('   ')$$, 'invalid_name');
select pg_temp.expect_error($$select take_ticket(repeat('x', 51))$$, 'invalid_name');
select pg_temp.check((take_ticket('  Andi  ')).number = 1, 'first ticket is number 1');
select pg_temp.check(
  (select customer_name from tickets where number = 1) = 'Andi', 'name is trimmed');
select pg_temp.expect_error($$select take_ticket('Andi lagi')$$, 'already_has_ticket');

select pg_temp.login('bbbbbbbb-0000-0000-0000-000000000000');
select pg_temp.check((take_ticket('Budi')).number = 2, 'second ticket is number 2');
select pg_temp.login('cccccccc-0000-0000-0000-000000000000');
select pg_temp.check((take_ticket('Citra')).number = 3, 'third ticket is number 3');

select pg_temp.check(
  (select waiting_count = 3 and last_number = 3 from v_active), 'trigger keeps waiting_count');

-- ---------------------------------------------------------------- RLS (kriteria 7)

select pg_temp.check((select count(*) from tickets) = 1, 'customer sees only own ticket');
select pg_temp.check((select count(*) from v_active) = 1, 'customer can read queue_sessions');
select pg_temp.check((select count(*) from admins) = 0, 'customer cannot read admins');
select pg_temp.expect_error(
  $$update tickets set status = 'done'$$, 'permission denied for table tickets');

-- ---------------------------------------------------------------- admin guard (kriteria 5)

select pg_temp.expect_error($$select call_next()$$, 'not_admin');
select pg_temp.expect_error($$select reset_queue()$$, 'not_admin');
select pg_temp.expect_error($$select get_queue_stats()$$, 'not_admin');
select pg_temp.expect_error(
  $$select set_ticket_status(gen_random_uuid(), 'done')$$, 'not_admin');
select pg_temp.check(not is_admin(), 'is_admin() false for customer');

-- ---------------------------------------------------------------- F-P4 estimate, no history (kriteria 9)

-- C has A and B ahead, nobody called, no done tickets: 2 × 10 min.
select pg_temp.check(
  (select (s ->> 'ahead_count')::int = 2
      and (s ->> 'est_wait_minutes')::int = 20
      and s ->> 'estimate_basis' = 'default'
      and (s ->> 'avg_service_seconds')::int = 600
   from get_my_status() s),
  'default estimate = ahead × 10 min');

-- ---------------------------------------------------------------- F-A3 call_next

select pg_temp.login('dddddddd-0000-0000-0000-000000000000');
select pg_temp.check(is_admin(), 'is_admin() true for admin');
select pg_temp.check((select count(*) from tickets) = 3, 'admin sees all tickets');
select pg_temp.check((call_next()).number = 1, 'call_next calls the lowest waiting number');
select pg_temp.expect_error($$select call_next()$$, 'call_in_progress');
select pg_temp.check(
  (select current_number = 1 and last_called_number = 1 and waiting_count = 2 from v_active),
  'session summary follows the called ticket');

-- ---------------------------------------------------------------- F-P2 / F-P4 with a called ticket

reset role;
-- Ticket 1 was called 4 minutes ago: 6 min left of a 10 min default.
update tickets set called_at = now() - interval '4 minutes' where number = 1;
set local role authenticated;

select pg_temp.login('bbbbbbbb-0000-0000-0000-000000000000');
select pg_temp.check(
  (select (s ->> 'ahead_count')::int = 0
      and (s ->> 'current_number')::int = 1
      and (s ->> 'est_wait_minutes')::int = 10
   from get_my_status() s),
  'remaining service time is rounded up to 5 minutes');

reset role;
update tickets set called_at = now() - interval '7 minutes' where number = 1;
set local role authenticated;
select pg_temp.check(
  (select (s ->> 'est_wait_minutes')::int = 3 from get_my_status() s),
  'under 5 minutes is returned unrounded');

-- ---------------------------------------------------------------- F-A4 transitions

select pg_temp.login('dddddddd-0000-0000-0000-000000000000');
select pg_temp.check(
  (select (set_ticket_status(id, 'done')).status = 'done' from tickets where number = 1),
  'called -> done');
select pg_temp.expect_error(
  format($$select set_ticket_status(%L, 'called')$$,
    (select id from tickets where number = 1)),
  'invalid_transition');
select pg_temp.check(
  (select (set_ticket_status(id, 'skipped')).status = 'skipped' from tickets where number = 2),
  'waiting -> skipped');
select pg_temp.check(
  (select (set_ticket_status(id, 'called')).status = 'called' from tickets where number = 2),
  'skipped -> called (panggil ulang)');
select pg_temp.check(
  (select (set_ticket_status(id, 'done')).finished_at is not null from tickets where number = 2),
  'done sets finished_at');

-- ---------------------------------------------------------------- F-P4 history, clamped durations

reset role;
-- 3 hours clamps to 60 min, 10 seconds clamps to 1 min -> avg (3600 + 60) / 2 = 1830 s.
update tickets set called_at = now() - interval '3 hours', finished_at = now() where number = 1;
update tickets set called_at = now() - interval '10 seconds', finished_at = now() where number = 2;
set local role authenticated;

select pg_temp.check(
  (select (s ->> 'avg_service_seconds')::int = 1830 and s ->> 'estimate_basis' = 'history'
   from get_queue_stats() s),
  'average uses clamped durations of done tickets');
select pg_temp.check(
  (select (s -> 'counts' ->> 'done')::int = 2 and (s ->> 'total')::int = 3
   from get_queue_stats() s),
  'stats count per status');

-- ---------------------------------------------------------------- F-P3 cancel_ticket

select pg_temp.login('aaaaaaaa-0000-0000-0000-000000000000');
select pg_temp.expect_error(
  format($$select cancel_ticket(%L)$$, (select id from tickets where number = 1)),
  'invalid_transition');

select pg_temp.login('bbbbbbbb-0000-0000-0000-000000000000');
reset role;
create temp table c_ticket as select id from tickets where number = 3;
grant select on c_ticket to authenticated;
set local role authenticated;
select pg_temp.expect_error(
  format($$select cancel_ticket(%L)$$, (select id from c_ticket)),
  'ticket_not_found');

select pg_temp.login('cccccccc-0000-0000-0000-000000000000');
select pg_temp.check(
  (select (cancel_ticket(id)).status = 'cancelled' from c_ticket),
  'owner cancels own waiting ticket');
select pg_temp.check((take_ticket('Citra')).number = 4, 'can take again after cancelling');

-- ---------------------------------------------------------------- F-A5 reset (kriteria 6)

select pg_temp.login('dddddddd-0000-0000-0000-000000000000');
select pg_temp.check((reset_queue()).last_number = 0, 'reset opens a fresh session');
select pg_temp.check(
  (select count(*) = 1 from queue_sessions where is_active), 'exactly one active session');

select pg_temp.login('cccccccc-0000-0000-0000-000000000000');
select pg_temp.check(
  (select (s ->> 'session_active')::boolean = false
      and s -> 'ticket' ->> 'status' = 'cancelled'
   from get_my_status() s),
  'old waiting ticket is cancelled and marked as reset');
select pg_temp.check((take_ticket('Citra')).number = 1, 'numbering restarts at 1 after reset');

do $$ begin raise notice 'ALL QUEUE TESTS PASSED'; end $$;

rollback;
