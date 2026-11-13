-- Newer Supabase projects no longer grant table privileges to API roles by
-- default. Reads are allowed (and filtered by RLS); writes stay RPC-only.
-- Realtime postgres_changes also needs SELECT to deliver events.
grant select on queue_sessions, tickets, admins to authenticated;
