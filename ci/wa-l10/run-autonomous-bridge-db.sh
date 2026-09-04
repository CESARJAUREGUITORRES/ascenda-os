#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB='postgresql://postgres:postgres@127.0.0.1:60202/postgres'
cleanup(){ set +e; cd "$ROOT/ci/wa4c-full-local" && supabase stop --no-backup >/dev/null 2>&1 || true; }
trap cleanup EXIT
cd "$ROOT"
test "${ASCENDA_FULL_LOCAL:-}" = '1'
python3 scripts/ci/enforce-zero-cost-policy.py
bash ci/wa4c-full-local/bootstrap.sh

psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260902235500_wa_l4_autonomous_authority_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260902235600_wa_l4_authority_hardening_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260904014500_wa_l10_canary_observability_v1.sql

# New bridge migration is reversible while dormant/no evidence.
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260904204500_wa_l10_autonomous_bridge_v1.sql
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_l10_bridge_jobs_v1")" = '0'
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/rollbacks/20260904204500_wa_l10_autonomous_bridge_v1.rollback.sql
test "$(psql "$DB" -X -qAt -c "select to_regclass('public.aos_wa_l10_bridge_jobs_v1') is null")" = 't'

# Reapply and exercise exact CANARY return/queue/idempotency/human-boundary behavior.
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260904204500_wa_l10_autonomous_bridge_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa-l10/tests/002_autonomous_bridge.sql 2>&1 | tee /tmp/l10-bridge-db.txt
grep -q 'WA_L10_AUTONOMOUS_BRIDGE_DB_CONTRACT_PASS' /tmp/l10-bridge-db.txt

psql "$DB" -X -v ON_ERROR_STOP=1 -c "set statement_timeout='3000ms'; select public.aos_wa_l10_bridge_status_v1('CI-L10-BRIDGE-RUN-0001');" >/tmp/l10-bridge-status.txt

test "$(psql "$DB" -X -qAt -c "select mode||':'||kill_switch_engaged from public.aos_wa_auto_authority_v1 where id=1")" = 'AUTO_OFF:true'
test "$(psql "$DB" -X -qAt -c "select auto_reply_enabled::text||':'||ai_send_enabled::text||':'||auto_routing_enabled::text||':'||human_send_enabled::text from public.aos_wa_ai_control_v1 cross join public.aos_wa_routing_control_v1 where aos_wa_ai_control_v1.id=1 and aos_wa_routing_control_v1.id=1")" = 'false:false:false:true'
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_auto_allowlist_v1 where active is true")" = '0'

test "$(psql "$DB" -X -qAt -c "select count(*) from information_schema.columns where table_schema='public' and table_name in ('aos_wa_l10_bridge_jobs_v1','aos_wa_l10_bridge_attempts_v1','aos_wa_l10_bridge_events_v1') and column_name in ('message_body','raw_webhook','recipient_address','contact_address','access_token')")" = '0'

# Immutable evidence prevents destructive recovery after live-shaped bridge use.
set +e
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/rollbacks/20260904204500_wa_l10_autonomous_bridge_v1.rollback.sql >/tmp/l10-bridge-recovery.txt 2>&1
rc=$?
set -e
test "$rc" -ne 0
grep -q 'WA_L10_BRIDGE_RECOVERY_BLOCKED_AUDIT_HISTORY' /tmp/l10-bridge-recovery.txt

test "$(psql "$DB" -X -qAt -c "select has_table_privilege('anon','public.aos_wa_l10_bridge_jobs_v1','SELECT')")" = 'f'
test "$(psql "$DB" -X -qAt -c "select has_function_privilege('anon','public.aos_wa_l10_bridge_claim_v1(text)','EXECUTE')")" = 'f'

(cd ci/wa4c-full-local && supabase db lint --local --schema public --level error 2>&1 | tee /tmp/l10-bridge-lint.txt)
! grep -q '\[ERROR\]' /tmp/l10-bridge-lint.txt

echo 'WA_L10_AUTONOMOUS_BRIDGE_FULL_LOCAL_PASS'
