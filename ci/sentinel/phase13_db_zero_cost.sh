#!/usr/bin/env bash
set -euo pipefail
DB="sentinel-f13-${GITHUB_RUN_ID:-local}-$$"
cleanup(){ docker rm -f "$DB" >/dev/null 2>&1 || true; }
trap cleanup EXIT

check_sql(){
  local label="$1" sql="$2" expected="${3:-t}" out
  out="$(docker exec "$DB" psql -At -v ON_ERROR_STOP=1 -U postgres -c "$sql" | tr -d '\r')"
  echo "${label}=${out}"
  test "$out" = "$expected"
}

docker run -d --name "$DB" -e POSTGRES_PASSWORD=postgres postgres:17-alpine >/dev/null
for _ in $(seq 1 40); do docker exec "$DB" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 1; done
docker exec "$DB" pg_isready -U postgres >/dev/null

docker exec -i "$DB" psql -v ON_ERROR_STOP=1 -U postgres <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;
create table public.aos_sentinel_incidents_v1(
  incident_id text primary key,severity text not null,status text not null,environment text not null,domain text not null,component text not null,capability text not null,failure_family text not null,
  opened_at timestamptz not null,updated_at timestamptz not null,last_signal_at timestamptz not null,resolved_at timestamptz,signal_count bigint not null,reopened_count integer not null,evidence_refs jsonb not null,correlation jsonb
);
create table public.aos_sentinel_incident_timeline_v1(timeline_id bigint generated always as identity primary key,incident_id text not null,event_type text not null,occurred_at timestamptz not null,details jsonb not null default '{}'::jsonb);
create or replace function public.aos_sentinel_owner_actor_v1(p_token text) returns uuid language sql stable security definer set search_path='' as $$ select case when p_token='owner-token' then '11111111-1111-1111-1111-111111111111'::uuid else null::uuid end $$;
insert into public.aos_sentinel_incidents_v1 values('SEN-2099-9401','P1','OPEN','production','WHATSAPP','messaging','human-outbound','provider-timeout',now()-interval '4 minutes',now()-interval '1 minute',now()-interval '1 minute',null,2,0,'[{"kind":"ci-run","id":"f13-db-fixture"}]'::jsonb,'{"release":"ascenda-os@abcdef1","commit_sha":"abcdef1","confidence":"EXACT"}'::jsonb);
insert into public.aos_sentinel_incident_timeline_v1(incident_id,event_type,occurred_at) values('SEN-2099-9401','INCIDENT_OPENED',now()-interval '4 minutes'),('SEN-2099-9401','SIGNAL_ATTACHED',now()-interval '1 minute');
SQL

docker exec -i "$DB" psql -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/20260817203504_sentinel_f13_owner_hub.sql

check_sql F13_ANON_TABLE_SELECT "select has_table_privilege('anon','public.aos_sentinel_incidents_v1','select')" f
check_sql F13_ANON_RPC_EXECUTE "select has_function_privilege('anon','public.aos_sentinel_owner_hub_v1(text,integer)','execute')" t
check_sql F13_SECURITY_DEFINER "select p.prosecdef and p.proconfig is not null and p.proconfig[1] like 'search_path=%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='aos_sentinel_owner_hub_v1'" t
check_sql F13_NEGATIVE_2FA "select public.aos_sentinel_owner_hub_v1('bad-token',50)->>'error'='SENTINEL_OWNER_2FA_REQUIRED'" t
check_sql F13_CANARY "select (j->>'ok')::boolean and (j->>'active_incidents')::integer=1 and j->'items'->0->>'incident_id'='SEN-2099-9401' and jsonb_array_length(j->'items'->0->'timeline')=2 from (select public.aos_sentinel_owner_hub_v1('owner-token',50) j) x" t

docker exec -i "$DB" psql -v ON_ERROR_STOP=1 -U postgres < ci/sentinel/sql/phase13_owner_hub_rollback.sql
check_sql F13_ROLLBACK_ABSENT "select to_regprocedure('public.aos_sentinel_owner_hub_v1(text,integer)') is null" t

docker exec -i "$DB" psql -v ON_ERROR_STOP=1 -U postgres < supabase/migrations/20260817203504_sentinel_f13_owner_hub.sql
check_sql F13_REAPPLY_PRESENT "select to_regprocedure('public.aos_sentinel_owner_hub_v1(text,integer)') is not null" t

echo 'SENTINEL_F13_DB_COMPILE=PASS'
echo 'SENTINEL_F13_DB_ACL=PASS'
echo 'SENTINEL_F13_DB_NEGATIVE_2FA=PASS'
echo 'SENTINEL_F13_DB_CANARY=PASS'
echo 'SENTINEL_F13_DB_ROLLBACK_REAPPLY=PASS'
