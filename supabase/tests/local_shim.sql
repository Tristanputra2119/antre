-- Local-only stand-in for what a Supabase project already provides, so the
-- migrations can run on plain Postgres. Never run this on Supabase.

create role anon nologin;
create role authenticated nologin;

create schema auth;
create table auth.users (
  id           uuid primary key,
  email        text,
  is_anonymous boolean not null default false
);

-- Same claim source Supabase uses.
create function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::json ->> 'sub', '')::uuid
$$;

grant usage on schema public, auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
-- Like current Supabase projects: no default table grants for API roles,
-- so the migrations must grant what the app needs explicitly.

create publication supabase_realtime;
