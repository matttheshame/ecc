#!/usr/bin/env bash
# Runs the migrations and the pgTAP suite on a throwaway database.
# Needs: PostgreSQL 15+ with PostGIS 3.1+ and pgTAP, plus pg_prove.
#
#   supabase/tests/run_local.sh            # uses $PGHOST/$PGUSER or local socket
#
# On a Supabase project use `supabase db reset && supabase test db` instead.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
db="${BRUSK_TEST_DB:-brusk_test}"

psql -v ON_ERROR_STOP=1 -q -d postgres -c "drop database if exists $db" -c "create database $db"
psql -v ON_ERROR_STOP=1 -q -d "$db" -f "$here/harness/supabase_stub.sql"
# Like Supabase: extensions (pgTAP included) live in their own schema on the search path.
psql -v ON_ERROR_STOP=1 -q -d "$db" -c "create extension if not exists pgtap with schema extensions" \
  -c "alter database $db set search_path = public, extensions"
for migration in "$root"/supabase/migrations/*.sql; do
  psql -v ON_ERROR_STOP=1 -q -d "$db" -f "$migration"
done
psql -v ON_ERROR_STOP=1 -q -d "$db" -f "$here/harness/helpers.sql"
pg_prove -d "$db" "$here"/database/*.test.sql
