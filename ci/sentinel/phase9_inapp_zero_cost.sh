#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE required}"
SUPABASE_CLI_VERSION="${SUPABASE_CLI_VERSION:-2.72.8}"; NODE_CLI_IMAGE="${NODE_CLI_IMAGE:-node:22-bookworm-slim}"; PSQL_IMAGE="${PSQL_IMAGE:-postgres:17-alpine}"; WORKSPACE_FIX_IMAGE="${WORKSPACE_FIX_IMAGE:-alpine:3.20}"
F8="supabase/migrations/20260816233500_sentinel_f8_incident_engine.sql"; F9="supabase/migrations/20260817010000_sentinel_f9_alert_outbox.sql"; PERF="supabase/migrations/20260817015500_sentinel_f9_digest_incident_fk_index.sql"; F9C="supabase/migrations/20260817043000_sentinel_f9_inapp_owner_alerts.sql"; ROLLBACK="supabase/rollbacks/20260817043000_sentinel_f9_inapp_owner_alerts_rollback.sql"; PRELUDE="ci/sentinel/phase9_inapp_zero_cost_prelude.sql"; FIXTURE="ci/sentinel/phase9_inapp_zero_cost.sql"
DOCKER_BIN="$(command -v docker)"; PROJECT_DIR="$GITHUB_WORKSPACE/ci/zero-cost-staging"; NPM_CACHE="sentinel-f9c-npm-cache"; HOST_UID="$(id -u)"; HOST_GID="$(id -g)"; DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
for f in "$F8" "$F9" "$PERF" "$F9C" "$ROLLBACK" "$PRELUDE" "$FIXTURE"; do test -f "$GITHUB_WORKSPACE/$f"; done
! grep -Eq '(SUPABASE_SERVICE_ROLE_KEY|Bearer [A-Za-z0-9._-]{20,}|sb_secret_|sk-proj-)' "$GITHUB_WORKSPACE/$F9C" "$GITHUB_WORKSPACE/$ROLLBACK" "$GITHUB_WORKSPACE/$PRELUDE" "$GITHUB_WORKSPACE/$FIXTURE"
supa(){ docker run --rm --network host -v /var/run/docker.sock:/var/run/docker.sock -v "$DOCKER_BIN:/usr/local/bin/docker:ro" -v "$GITHUB_WORKSPACE:$GITHUB_WORKSPACE" -v "$NPM_CACHE:/root/.npm" -w "$PROJECT_DIR" "$NODE_CLI_IMAGE" sh -lc "npx --yes supabase@${SUPABASE_CLI_VERSION} $*"; }
repair(){ docker run --rm -v "$GITHUB_WORKSPACE:/work" "$WORKSPACE_FIX_IMAGE" sh -lc "rm -rf /work/ci/zero-cost-staging/supabase/.branches; chown -R ${HOST_UID}:${HOST_GID} /work 2>/dev/null || true" >/dev/null 2>&1 || true; }
cleanup(){ supa "stop --no-backup >/dev/null 2>&1 || true" >/dev/null 2>&1 || true; docker volume rm -f "$NPM_CACHE" >/dev/null 2>&1 || true; rm -f /tmp/f9c-db-lint.txt; repair; }
trap cleanup EXIT; repair; supa "stop --no-backup >/dev/null 2>&1 || true" >/dev/null; supa "db start >/dev/null"
psql_file(){ docker run --rm --network host -v "$GITHUB_WORKSPACE:/work:ro" "$PSQL_IMAGE" psql "$DB_URL" -v ON_ERROR_STOP=1 -f "/work/$1"; }
psql_cmd(){ docker run --rm --network host "$PSQL_IMAGE" psql "$DB_URL" -v ON_ERROR_STOP=1 "$@"; }
psql_file "$PRELUDE" >/dev/null; psql_file "$F8" >/dev/null; psql_file "$F9" >/dev/null; psql_file "$PERF" >/dev/null; psql_file "$F9C" >/dev/null
echo 'SENTINEL_F9_INAPP_LOCAL_MIGRATION=PASS'
psql_file "$FIXTURE" | grep -E 'SENTINEL_F9_INAPP_.*=PASS'
psql_cmd -Atqc "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'aos_sentinel_%inapp%_v1' and p.prosecdef and coalesce(array_to_string(p.proconfig,','),'') like '%search_path=%'" | grep -Eq '^[4-9][0-9]*$'
supa "db lint --local --level warning" >/tmp/f9c-db-lint.txt
! grep -Eqi '(security definer.*mutable search_path|aos_sentinel_.*rls.*disabled)' /tmp/f9c-db-lint.txt
echo 'SENTINEL_F9_INAPP_DB_LINT=PASS'
psql_file "$ROLLBACK" >/dev/null
psql_cmd -Atqc "select case when to_regclass('public.aos_sentinel_owner_notification_reads_v1') is null then 'gone' else 'present' end" | grep -qx gone
psql_cmd -Atqc "select case when to_regclass('public.aos_sentinel_alert_dispatches_v1') is not null then 'f9-present' else 'f9-missing' end" | grep -qx f9-present
psql_cmd -Atqc "select case when to_regclass('public.aos_sentinel_incidents_v1') is not null then 'f8-present' else 'f8-missing' end" | grep -qx f8-present
echo 'SENTINEL_F9_INAPP_ROLLBACK=PASS'
psql_cmd -qc "delete from public.aos_sentinel_incidents_v1 where incident_id like 'SEN-2099-9%'; delete from public.aos_sentinel_alert_dispatches_v1 where channel='ascenda-in-app';"
psql_cmd -qc "alter table public.aos_sentinel_alert_dispatches_v1 drop constraint if exists aos_sentinel_alert_dispatches_v1_channel_check; alter table public.aos_sentinel_alert_dispatches_v1 add constraint aos_sentinel_alert_dispatches_v1_channel_check check(channel='telegram-owner');"
psql_file "$F9C" >/dev/null
psql_file "$FIXTURE" >/dev/null
echo 'SENTINEL_F9_INAPP_REAPPLY=PASS'
echo 'SENTINEL_F9_INAPP_ZERO_COST=PASS'
