#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE required}"
SUPABASE_CLI_VERSION="${SUPABASE_CLI_VERSION:-2.72.8}"
NODE_CLI_IMAGE="${NODE_CLI_IMAGE:-node:22-bookworm-slim}"
PSQL_IMAGE="${PSQL_IMAGE:-postgres:17-alpine}"
WORKSPACE_FIX_IMAGE="${WORKSPACE_FIX_IMAGE:-alpine:3.20}"
MIGRATION="supabase/migrations/20260816233500_sentinel_f8_incident_engine.sql"
ROLLBACK="supabase/rollbacks/20260816233500_sentinel_f8_incident_engine_rollback.sql"
FIXTURE="ci/sentinel/phase8_persistence_zero_cost.sql"
DOCKER_BIN="$(command -v docker)"
PROJECT_DIR="$GITHUB_WORKSPACE/ci/zero-cost-staging"
NPM_CACHE="sentinel-f8-npm-cache"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
F8_DB_URL="${F8_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
export F8_DB_URL

for f in "$MIGRATION" "$ROLLBACK" "$FIXTURE"; do test -f "$GITHUB_WORKSPACE/$f"; done
python3 --version >/dev/null
docker version >/dev/null
case "$F8_DB_URL" in
  *127.0.0.1*|*localhost*) ;;
  *) echo 'F8_ZERO_COST_DB_URL_NOT_LOCAL' >&2; exit 1;;
esac
! grep -Eq '(SUPABASE_SERVICE_ROLE_KEY|Bearer [A-Za-z0-9._-]{20,}|sb_secret_|sk-proj-)' "$GITHUB_WORKSPACE/$MIGRATION" "$GITHUB_WORKSPACE/$ROLLBACK" "$GITHUB_WORKSPACE/$FIXTURE"

supa(){
  docker run --rm --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$DOCKER_BIN:/usr/local/bin/docker:ro" \
    -v "$GITHUB_WORKSPACE:$GITHUB_WORKSPACE" \
    -v "$NPM_CACHE:/root/.npm" \
    -w "$PROJECT_DIR" \
    "$NODE_CLI_IMAGE" \
    sh -lc "npx --yes supabase@${SUPABASE_CLI_VERSION} $*"
}

repair_workspace(){
  docker run --rm \
    -v "$GITHUB_WORKSPACE:/work" \
    "$WORKSPACE_FIX_IMAGE" \
    sh -lc "rm -rf /work/ci/zero-cost-staging/supabase/.branches; chown -R ${HOST_UID}:${HOST_GID} /work 2>/dev/null || true" \
    >/dev/null 2>&1 || true
}

cleanup(){
  supa "stop --no-backup >/dev/null 2>&1 || true" >/dev/null 2>&1 || true
  docker volume rm -f "$NPM_CACHE" >/dev/null 2>&1 || true
  rm -f /tmp/f8-replay-a.txt /tmp/f8-replay-b.txt /tmp/f8-fp-a.txt /tmp/f8-fp-b.txt /tmp/sentinel-f8-db-lint.txt
  repair_workspace
}
trap cleanup EXIT

# Only PostgreSQL is required for F8. Starting the full Supabase stack adds unrelated
# Analytics/Auth/Storage health dependencies and can create false negatives.
repair_workspace
supa "stop --no-backup >/dev/null 2>&1 || true" >/dev/null
supa "db start >/dev/null"
printf '%s\n' 'SENTINEL_F8_LOCAL_DB=READY'

psql_file(){
  docker run --rm --network host -v "$GITHUB_WORKSPACE:/work:ro" "$PSQL_IMAGE" \
    psql "$F8_DB_URL" -v ON_ERROR_STOP=1 -f "/work/$1"
}
psql_cmd(){
  docker run --rm --network host "$PSQL_IMAGE" psql "$F8_DB_URL" -v ON_ERROR_STOP=1 "$@"
}

# Confirm the local database is reachable before applying any F8 DDL.
psql_cmd -Atqc "select case when current_database()='postgres' then 'F8_DB_LOCAL_OK' else 'F8_DB_WRONG_DATABASE' end" | grep -qx 'F8_DB_LOCAL_OK'

psql_file "$MIGRATION"
printf '%s\n' 'SENTINEL_F8_LOCAL_MIGRATION=PASS'
psql_file "$FIXTURE"

# Same event_id, simultaneous ingest: exactly one ledger row / one incident / signal_count=1.
SQL="select public.aos_sentinel_ingest_signal_v1(jsonb_build_object('event_id','concurrent-replay-001','signal_class','ERROR','environment','zero-cost','domain','EMAIL','component','resend-gateway','capability','send-and-webhook-progression','failure_family','provider-stall','signal_fingerprint','error:email:provider-stall','incident_fingerprint','zero-cost:email:resend-gateway:send-and-webhook-progression:provider-stall','severity','P2','observed_at','2026-08-16T23:40:00Z'));"
psql_cmd -Atqc "$SQL" >/tmp/f8-replay-a.txt & A=$!
psql_cmd -Atqc "$SQL" >/tmp/f8-replay-b.txt & B=$!
wait "$A"; wait "$B"
CHECK="do \$\$ begin if (select count(*) from public.aos_sentinel_incident_signals_v1 where event_id='concurrent-replay-001')<>1 then raise exception 'F8_CONCURRENT_REPLAY_SIGNAL_DUP'; end if; if (select count(*) from public.aos_sentinel_incidents_v1 where incident_fingerprint='zero-cost:email:resend-gateway:send-and-webhook-progression:provider-stall')<>1 then raise exception 'F8_CONCURRENT_REPLAY_INCIDENT_DUP'; end if; if (select signal_count from public.aos_sentinel_incidents_v1 where incident_fingerprint='zero-cost:email:resend-gateway:send-and-webhook-progression:provider-stall')<>1 then raise exception 'F8_CONCURRENT_REPLAY_COUNT_DRIFT'; end if; end \$\$;"
psql_cmd -c "$CHECK" >/dev/null
printf '%s\n' 'SENTINEL_F8_CONCURRENT_REPLAY=PASS'

# Two different event_ids, same incident fingerprint, simultaneous ingest: one incident, two signals, severity escalates.
COMMON="'environment','zero-cost','domain','SALES','component','sales-intelligence','capability','aggregate-sales-read','failure_family','gateway-divergence','incident_fingerprint','zero-cost:sales:sales-intelligence:aggregate-sales-read:gateway-divergence','observed_at','2026-08-16T23:45:00Z'"
SQL_A="select public.aos_sentinel_ingest_signal_v1(jsonb_build_object('event_id','concurrent-fp-a','signal_class','ERROR','signal_fingerprint','error:sales:gateway-divergence','severity','P2',${COMMON}));"
SQL_B="select public.aos_sentinel_ingest_signal_v1(jsonb_build_object('event_id','concurrent-fp-b','signal_class','BUSINESS_HEALTH','signal_fingerprint','business-health:sales:gateway-divergence','severity','P1',${COMMON}));"
psql_cmd -Atqc "$SQL_A" >/tmp/f8-fp-a.txt & A=$!
psql_cmd -Atqc "$SQL_B" >/tmp/f8-fp-b.txt & B=$!
wait "$A"; wait "$B"
CHECK="do \$\$ begin if (select count(*) from public.aos_sentinel_incidents_v1 where incident_fingerprint='zero-cost:sales:sales-intelligence:aggregate-sales-read:gateway-divergence')<>1 then raise exception 'F8_CONCURRENT_FP_INCIDENT_DUP'; end if; if (select signal_count from public.aos_sentinel_incidents_v1 where incident_fingerprint='zero-cost:sales:sales-intelligence:aggregate-sales-read:gateway-divergence')<>2 then raise exception 'F8_CONCURRENT_FP_SIGNAL_COUNT'; end if; if (select severity from public.aos_sentinel_incidents_v1 where incident_fingerprint='zero-cost:sales:sales-intelligence:aggregate-sales-read:gateway-divergence')<>'P1' then raise exception 'F8_CONCURRENT_FP_SEVERITY'; end if; end \$\$;"
psql_cmd -c "$CHECK" >/dev/null
printf '%s\n' 'SENTINEL_F8_CONCURRENT_FINGERPRINT=PASS'

# SECURITY DEFINER functions must have a fixed search_path.
CHECK="do \$\$ begin if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('aos_sentinel_ingest_signal_v1','aos_sentinel_transition_incident_v1','aos_sentinel_get_incident_v1') and (p.prosecdef is not true or coalesce(array_to_string(p.proconfig,','),'') not like '%search_path=%')) then raise exception 'F8_SECURITY_DEFINER_SEARCH_PATH'; end if; end \$\$;"
psql_cmd -c "$CHECK" >/dev/null
supa "db lint --local --level warning" >/tmp/sentinel-f8-db-lint.txt
! grep -Eqi '(security definer.*mutable search_path|rls.*disabled)' /tmp/sentinel-f8-db-lint.txt
printf '%s\n' 'SENTINEL_F8_SECURITY_DB_LINT=PASS'

# Rollback must remove all F8 objects, then the migration must reapply cleanly and fixtures must still pass.
psql_file "$ROLLBACK" >/dev/null
CHECK="do \$\$ begin if to_regclass('public.aos_sentinel_incidents_v1') is not null then raise exception 'F8_ROLLBACK_TABLE_REMAINS'; end if; if to_regprocedure('public.aos_sentinel_ingest_signal_v1(jsonb)') is not null then raise exception 'F8_ROLLBACK_RPC_REMAINS'; end if; end \$\$;"
psql_cmd -c "$CHECK" >/dev/null
psql_file "$MIGRATION" >/dev/null
psql_file "$FIXTURE" >/dev/null
printf '%s\n' 'SENTINEL_F8_ROLLBACK_REAPPLY=PASS'
printf '%s\n' 'SENTINEL_F8_PERSISTENCE_ZERO_COST=PASS'
