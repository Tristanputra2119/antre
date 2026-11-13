#!/usr/bin/env bash
# Applies the migrations to a throwaway local Postgres and runs the SQL tests,
# including a real concurrency check for numbering (kriteria 1).
# Needs initdb/pg_ctl/psql on PATH (e.g. `brew install postgresql`).
set -euo pipefail
cd "$(dirname "$0")/../.."

PORT=54329
DATA=$(mktemp -d)
trap 'pg_ctl -D "$DATA" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$DATA"' EXIT

initdb -D "$DATA" -U postgres -A trust >/dev/null
pg_ctl -D "$DATA" -o "-p $PORT -k $DATA -c listen_addresses=''" -l "$DATA/log" -w start >/dev/null
sql() { psql -h "$DATA" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -qAtX "$@"; }

sql -f supabase/tests/local_shim.sql
for f in supabase/migrations/*.sql; do sql -f "$f"; done
echo "migrations applied"

sql -f supabase/tests/queue_test.sql 2>&1 | grep -E 'ok -|PASSED|FAILED|ERROR' | sed 's/^psql:[^ ]* NOTICE:  //'

# Concurrency: N customers take a ticket at the same moment.
N=30
users=$(sql -c "insert into auth.users (id) select gen_random_uuid() from generate_series(1, $N) returning id")
for id in $users; do
  sql -c "set role authenticated;
          select set_config('request.jwt.claims', '{\"sub\":\"$id\"}', false);
          select take_ticket('Paralel');" >/dev/null &
done
wait
result=$(sql -c "select count(*) = $N and count(distinct number) = $N and max(number) = $N
                 from tickets t join queue_sessions s on s.id = t.session_id where s.is_active")
[[ "$result" == "t" ]] || { echo "FAILED: concurrent take_ticket produced duplicate/gapped numbers"; exit 1; }
echo "ok - $N concurrent take_ticket calls got unique numbers 1..$N"
