#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE required}"
SUPABASE_CLI_VERSION="${SUPABASE_CLI_VERSION:-2.72.8}"
NODE_CLI_IMAGE="${NODE_CLI_IMAGE:-node:22-bookworm-slim}"
PSQL_IMAGE="${PSQL_IMAGE:-postgres:17-alpine}"
WORKSPACE_FIX_IMAGE="${WORKSPACE_FIX_IMAGE:-alpine:3.20}"
F8_MIGRATION="supabase/migrations/20260816233500_sentinel_f8_incident_engine.sql"
F9_MIGRATION="supabase/migrations/20260817010000_sentinel_f9_alert_outbox.sql"
F9_ROLLBACK="supabase/rollbacks/20260817010000_sentinel_f9_alert_outbox_rollback.sql"
F9_PERF_MIGRATION="supabase/migrations/20260817015500_sentinel_f9_digest_incident_fk_index.sql"
F9_PERF_ROLLBACK="supabase/rollbacks/20260817015500_sentinel_f9_digest_incident_fk_index_rollback.sql"
FIXTURE="ci/sentinel/phase9_alert_outbox_zero_cost.sql"
DOCKER_BIN="$(command -v docker)"
PROJECT_DIR="$GITHUB_WORKSPACE/ci/zero-cost-staging"
NPM_CACHE="sentinel-f9-npm-cache"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

for f in "$F8_MIGRATION" "$F9_MIGRATION" "$F9_ROLLBACK" "$F9_PERF_MIGRATION" "$F9_PERF_ROLLBACK" "$FIXTURE"; do test -f "$GITHUB_WORKSPACE/$f"; done
docker version >/dev/null
python3 --version >/dev/null
! grep -Eq '(SUPABASE_SERVICE_ROLE_KEY|Bearer [A-Za-z0-9._-]{20,}|sb_secret_|sk-proj-)' "$GITHUB_WORKSPACE/$F9_MIGRATION" "$GITHUB_WORKSPACE/$F9_ROLLBACK" "$GITHUB_WORKSPACE/$F9_PERF_MIGRATION" "$GITHUB_WORKSPACE/$F9_PERF_ROLLBACK" "$GITHUB_WORKSPACE/$FIXTURE"

supa(){
  docker run --rm --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$DOCKER_BIN:/usr/local/bin/docker:ro" \
    -v "$GITHUB_WORKSPACE:$GITHUB_WORKSPACE" \
    -v "$NPM_CACHE:/root/.npm" \
    -w "$PROJECT_DIR" \
    "$NODE_CLI_IMAGE" sh -lc "npx --yes supabase@${SUPABASE_CLI_VERSION} $*"
}
repair(){
  docker run --rm -v "$GITHUB_WORKSPACE:/work" "$WORKSPACE_FIX_IMAGE" \
    sh -lc "rm -rf /work/ci/zero-cost-staging/supabase/.branches; chown -R ${HOST_UID}:${HOST_GID} /work 2>/dev/null || true" >/dev/null 2>&1 || true
}
cleanup(){
  supa "stop --no-backup >/dev/null 2>&1 || true" >/dev/null 2>&1 || true
  docker volume rm -f "$NPM_CACHE" >/dev/null 2>&1 || true
  rm -f /tmp/f9-concurrent-a.txt /tmp/f9-concurrent-b.txt /tmp/f9-db-lint.txt
  repair
}
trap cleanup EXIT
repair
supa "stop --no-backup >/dev/null 2>&1 || true" >/dev/null
supa "db start >/dev/null"

psql_file(){ docker run --rm --network host -v "$GITHUB_WORKSPACE:/work:ro" "$PSQL_IMAGE" psql "$DB_URL" -v ON_ERROR_STOP=1 -f "/work/$1"; }
psql_cmd(){ docker run --rm --network host "$PSQL_IMAGE" psql "$DB_URL" -v ON_ERROR_STOP=1 "$@"; }

psql_cmd -Atqc "select current_database()" | grep -qx postgres
psql_file "$F8_MIGRATION" >/dev/null
psql_file "$F9_MIGRATION" >/dev/null
psql_file "$F9_PERF_MIGRATION" >/dev/null
psql_cmd -Atqc "select count(*) from pg_indexes where schemaname='public' and tablename='aos_sentinel_alert_digest_items_v1' and indexname='aos_sentinel_alert_digest_items_v1_incident_idx'" | grep -qx 1
echo 'SENTINEL_F9_LOCAL_MIGRATION=PASS'
echo 'SENTINEL_F9_DIGEST_FK_INDEX=PASS'
psql_file "$FIXTURE"

# Same attempt in two concurrent transactions must produce exactly one ledger row.
SQL="select public.aos_sentinel_alert_reserve_dispatch_v1(jsonb_build_object('attempt_key','f9-concurrent-attempt','decision_key','SEN-2026-0001:INCIDENT:P0:OPEN','incident_id','SEN-2026-0001','action','IMMEDIATE','severity','P0','status','OPEN','environment','zero-cost','domain','SENTINEL','decided_at','2026-08-17T00:50:00Z','cooldown_seconds',60));"
psql_cmd -Atqc "$SQL" >/tmp/f9-concurrent-a.txt & A=$!
psql_cmd -Atqc "$SQL" >/tmp/f9-concurrent-b.txt & B=$!
wait "$A"; wait "$B"
psql_cmd -Atqc "select count(*) from public.aos_sentinel_alert_dispatches_v1 where attempt_key='f9-concurrent-attempt'" | grep -qx 1
echo 'SENTINEL_F9_CONCURRENT_ATTEMPT=PASS'

# Fixed search_path / lint.
psql_cmd -Atqc "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'aos_sentinel_alert_%_v1' and p.prosecdef and coalesce(array_to_string(p.proconfig,','),'') like '%search_path=%'" | grep -Eq '^[4-9][0-9]*$'
supa "db lint --local --level warning" >/tmp/f9-db-lint.txt
! grep -Eqi '(security definer.*mutable search_path|aos_sentinel_alert_.*rls.*disabled)' /tmp/f9-db-lint.txt
echo 'SENTINEL_F9_DB_LINT=PASS'

# Hotfix rollback/reapply must be reversible without touching F9 tables.
psql_file "$F9_PERF_ROLLBACK" >/dev/null
psql_cmd -Atqc "select count(*) from pg_indexes where schemaname='public' and indexname='aos_sentinel_alert_digest_items_v1_incident_idx'" | grep -qx 0
psql_file "$F9_PERF_MIGRATION" >/dev/null
psql_cmd -Atqc "select count(*) from pg_indexes where schemaname='public' and indexname='aos_sentinel_alert_digest_items_v1_incident_idx'" | grep -qx 1
echo 'SENTINEL_F9_PERF_ROLLBACK_REAPPLY=PASS'

# Rollback F9 only; F8 must remain intact. Then reapply and replay fixtures.
psql_file "$F9_ROLLBACK" >/dev/null
psql_cmd -Atqc "select case when to_regclass('public.aos_sentinel_alert_dispatches_v1') is null then 'gone' else 'present' end" | grep -qx gone
psql_cmd -Atqc "select case when to_regclass('public.aos_sentinel_incidents_v1') is not null then 'f8-present' else 'f8-missing' end" | grep -qx f8-present
psql_file "$F9_MIGRATION" >/dev/null
psql_file "$F9_PERF_MIGRATION" >/dev/null
psql_file "$FIXTURE" >/dev/null
echo 'SENTINEL_F9_ROLLBACK_REAPPLY=PASS'
echo 'SENTINEL_F9_ALERT_OUTBOX_ZERO_COST=PASS'