-- Row Level Security. No write policies: all writes go through security definer RPCs.

create function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;

alter table queue_sessions enable row level security;
alter table tickets enable row level security;
alter table admins enable row level security;

-- Supabase grants table writes to API roles by default; reject them outright
-- instead of letting RLS silently match zero rows.
revoke insert, update, delete, truncate on queue_sessions, tickets, admins from anon, authenticated;

create policy "sessions readable by signed-in users"
  on queue_sessions for select to authenticated using (true);

create policy "tickets readable by owner or admin"
  on tickets for select to authenticated using (user_id = auth.uid() or is_admin());

create policy "admins can see own row"
  on admins for select to authenticated using (user_id = auth.uid());
