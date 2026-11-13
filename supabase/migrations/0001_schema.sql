-- Core schema: sessions, tickets, admins.

create type ticket_status as enum ('waiting', 'called', 'done', 'skipped', 'cancelled');

create table queue_sessions (
  id                      uuid primary key default gen_random_uuid(),
  started_at              timestamptz not null default now(),
  ended_at                timestamptz,
  is_active               boolean not null default true,
  last_number             int not null default 0,
  current_number          int,
  last_called_number      int,
  waiting_count           int not null default 0,
  default_service_minutes int not null default 10 check (default_service_minutes between 1 and 120),
  updated_at              timestamptz not null default now()
);
create unique index one_active_session on queue_sessions (is_active) where is_active;

create table tickets (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid not null references queue_sessions (id),
  number        int not null,
  customer_name text not null check (char_length(btrim(customer_name)) between 1 and 50),
  user_id       uuid not null references auth.users (id),
  status        ticket_status not null default 'waiting',
  created_at    timestamptz not null default now(),
  called_at     timestamptz,
  finished_at   timestamptz,
  unique (session_id, number)
);
create unique index one_active_ticket_per_user
  on tickets (session_id, user_id) where status in ('waiting', 'called');
create unique index one_called_per_session
  on tickets (session_id) where status = 'called';
create index tickets_user_created on tickets (user_id, created_at desc);

create table admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

-- Keeps the name-free summary on queue_sessions in sync; customers subscribe to it.
create function sync_session_summary() returns trigger
language plpgsql as $$
begin
  update queue_sessions s set
    waiting_count = (select count(*) from tickets t where t.session_id = s.id and t.status = 'waiting'),
    current_number = (select t.number from tickets t where t.session_id = s.id and t.status = 'called'),
    last_called_number = coalesce(
      (select t.number from tickets t
        where t.session_id = s.id and t.called_at is not null
        order by t.called_at desc limit 1),
      s.last_called_number),
    updated_at = now()
  where s.id = new.session_id;
  return null;
end;
$$;

create trigger tickets_sync_session_summary
  after insert or update on tickets
  for each row execute function sync_session_summary();
