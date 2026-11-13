-- Business logic. Errors are raised with a stable snake_case message that the
-- app maps to Indonesian text in lib/core/errors.dart.

-- ---------------------------------------------------------------- internal

create function assert_admin() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'not_admin';
  end if;
end;
$$;

create function ensure_active_session() returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  insert into queue_sessions default values
  on conflict (is_active) where is_active do nothing;

  select id into v_id from queue_sessions where is_active;
  return v_id;
end;
$$;

-- Average service time over the last 10 finished tickets, each clamped to 1–60 minutes.
create function service_estimate(p_session_id uuid, out avg_seconds int, out basis text)
language sql stable security definer set search_path = public as $$
  with recent as (
    select least(greatest(extract(epoch from finished_at - called_at), 60), 3600) as secs
    from tickets
    where session_id = p_session_id
      and status = 'done'
      and called_at is not null
      and finished_at is not null
    order by finished_at desc
    limit 10
  )
  select
    coalesce(
      round(avg(secs))::int,
      (select default_service_minutes * 60 from queue_sessions where id = p_session_id),
      600),
    case when count(*) > 0 then 'history' else 'default' end
  from recent;
$$;

-- ---------------------------------------------------------------- customer

create function take_ticket(p_name text) returns tickets
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_name    text := btrim(coalesce(p_name, ''));
  v_session queue_sessions;
  v_ticket  tickets;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if char_length(v_name) not between 1 and 50 then
    raise exception 'invalid_name';
  end if;

  perform ensure_active_session();
  select * into v_session from queue_sessions where is_active for update;

  if exists (
    select 1 from tickets
    where session_id = v_session.id and user_id = v_uid and status in ('waiting', 'called')
  ) then
    raise exception 'already_has_ticket';
  end if;

  update queue_sessions set last_number = last_number + 1
  where id = v_session.id
  returning * into v_session;

  insert into tickets (session_id, number, customer_name, user_id)
  values (v_session.id, v_session.last_number, v_name, v_uid)
  returning * into v_ticket;

  return v_ticket;
end;
$$;

create function cancel_ticket(p_ticket_id uuid) returns tickets
language plpgsql security definer set search_path = public as $$
declare
  v_ticket tickets;
begin
  select * into v_ticket from tickets
  where id = p_ticket_id and user_id = auth.uid()
  for update;

  if not found then
    raise exception 'ticket_not_found';
  end if;
  if v_ticket.status <> 'waiting' then
    raise exception 'invalid_transition';
  end if;

  update tickets set status = 'cancelled', finished_at = now()
  where id = p_ticket_id
  returning * into v_ticket;

  return v_ticket;
end;
$$;

create function get_my_status() returns json
language plpgsql stable security definer set search_path = public as $$
declare
  v_ticket       tickets;
  v_session      queue_sessions;
  v_estimate     record;
  v_ahead        int := 0;
  v_called_at    timestamptz;
  v_remaining    numeric := 0;
  v_raw_minutes  numeric;
  v_est_minutes  int;
begin
  select * into v_ticket from tickets
  where user_id = auth.uid()
  order by created_at desc
  limit 1;

  if not found then
    return json_build_object('ticket', null);
  end if;

  select * into v_session from queue_sessions where id = v_ticket.session_id;
  select * into v_estimate from service_estimate(v_session.id);

  select count(*) into v_ahead from tickets
  where session_id = v_session.id and status = 'waiting' and number < v_ticket.number;

  if v_ticket.status = 'waiting' and v_session.is_active then
    select called_at into v_called_at from tickets
    where session_id = v_session.id and status = 'called';

    if v_called_at is not null then
      v_remaining := greatest(v_estimate.avg_seconds - extract(epoch from now() - v_called_at), 0);
    end if;

    v_raw_minutes := (v_ahead * v_estimate.avg_seconds + v_remaining) / 60.0;
    -- Under 5 minutes keep the raw value so the app can show "Kurang dari 5 menit".
    v_est_minutes := case
      when v_raw_minutes < 5 then ceil(v_raw_minutes)
      else ceil(v_raw_minutes / 5) * 5
    end;
  end if;

  return json_build_object(
    'ticket', row_to_json(v_ticket),
    'ahead_count', v_ahead,
    'current_number', v_session.current_number,
    'last_called_number', v_session.last_called_number,
    'session_active', v_session.is_active,
    'est_wait_minutes', v_est_minutes,
    'avg_service_seconds', v_estimate.avg_seconds,
    'estimate_basis', v_estimate.basis
  );
end;
$$;

-- ---------------------------------------------------------------- admin

create function get_queue_stats() returns json
language plpgsql stable security definer set search_path = public as $$
declare
  v_session_id uuid;
  v_estimate   record;
begin
  perform assert_admin();

  select id into v_session_id from queue_sessions where is_active;
  if v_session_id is null then
    return json_build_object('session_id', null, 'counts', '{}'::json, 'total', 0,
      'avg_service_seconds', null, 'estimate_basis', 'default');
  end if;

  select * into v_estimate from service_estimate(v_session_id);

  return json_build_object(
    'session_id', v_session_id,
    'avg_service_seconds', v_estimate.avg_seconds,
    'estimate_basis', v_estimate.basis,
    'total', (select count(*) from tickets where session_id = v_session_id),
    'counts', coalesce(
      (select json_object_agg(status, n)
         from (select status, count(*) as n from tickets
               where session_id = v_session_id group by status) c),
      '{}'::json)
  );
end;
$$;

create function call_next() returns tickets
language plpgsql security definer set search_path = public as $$
declare
  v_session_id uuid;
  v_ticket     tickets;
begin
  perform assert_admin();

  -- Locking the session serializes call_next / take_ticket / reset_queue.
  select id into v_session_id from queue_sessions where is_active for update;

  if exists (select 1 from tickets where session_id = v_session_id and status = 'called') then
    raise exception 'call_in_progress';
  end if;

  select * into v_ticket from tickets
  where session_id = v_session_id and status = 'waiting'
  order by number
  limit 1
  for update skip locked;

  if not found then
    raise exception 'queue_empty';
  end if;

  update tickets set status = 'called', called_at = now()
  where id = v_ticket.id
  returning * into v_ticket;

  return v_ticket;
end;
$$;

create function set_ticket_status(p_ticket_id uuid, p_status ticket_status) returns tickets
language plpgsql security definer set search_path = public as $$
declare
  v_ticket tickets;
begin
  perform assert_admin();

  -- Lock the session first (same order as call_next) to avoid deadlocks.
  perform 1 from queue_sessions s
  join tickets t on t.session_id = s.id
  where t.id = p_ticket_id
  for update of s;

  select * into v_ticket from tickets where id = p_ticket_id for update;
  if not found then
    raise exception 'ticket_not_found';
  end if;
  if not (select is_active from queue_sessions where id = v_ticket.session_id) then
    raise exception 'session_closed';
  end if;

  case
    when v_ticket.status = 'called' and p_status in ('done', 'skipped')
      or v_ticket.status = 'waiting' and p_status = 'skipped' then
      update tickets set status = p_status, finished_at = now()
      where id = p_ticket_id
      returning * into v_ticket;

    when v_ticket.status = 'skipped' and p_status = 'called' then
      if exists (select 1 from tickets where session_id = v_ticket.session_id and status = 'called') then
        raise exception 'call_in_progress';
      end if;
      update tickets set status = 'called', called_at = now(), finished_at = null
      where id = p_ticket_id
      returning * into v_ticket;

    else
      raise exception 'invalid_transition';
  end case;

  return v_ticket;
end;
$$;

create function reset_queue() returns queue_sessions
language plpgsql security definer set search_path = public as $$
declare
  v_old queue_sessions;
  v_new queue_sessions;
begin
  perform assert_admin();

  select * into v_old from queue_sessions where is_active for update;

  if found then
    update tickets set status = 'cancelled', finished_at = now()
    where session_id = v_old.id and status in ('waiting', 'called');

    update queue_sessions set is_active = false, ended_at = now(), updated_at = now()
    where id = v_old.id;
  end if;

  insert into queue_sessions (default_service_minutes)
  values (coalesce(v_old.default_service_minutes, 10))
  returning * into v_new;

  return v_new;
end;
$$;

-- ---------------------------------------------------------------- grants

revoke execute on function
  assert_admin(), ensure_active_session(), service_estimate(uuid), sync_session_summary()
  from public, anon, authenticated;

revoke execute on function
  is_admin(), take_ticket(text), cancel_ticket(uuid), get_my_status(), get_queue_stats(),
  call_next(), set_ticket_status(uuid, ticket_status), reset_queue()
  from public, anon;

grant execute on function
  is_admin(), take_ticket(text), cancel_ticket(uuid), get_my_status(), get_queue_stats(),
  call_next(), set_ticket_status(uuid, ticket_status), reset_queue()
  to authenticated;
