#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB='postgresql://postgres:postgres@127.0.0.1:59842/postgres'
STAGING="$ROOT/ci/zero-cost-staging"

cleanup(){
  set +e
  (cd "$STAGING" && supabase stop --no-backup >/dev/null 2>&1) || true
  docker ps -aq --filter 'name=ascenda-wa-l10' | xargs -r docker rm -f >/dev/null 2>&1 || true
}
trap cleanup EXIT

cd "$ROOT"
test "${ASCENDA_FULL_LOCAL:-}" = '1'
python3 scripts/ci/enforce-zero-cost-policy.py

# Build an isolated Postgres using a unique L10 port namespace.
cd "$STAGING"
sed -i 's/project_id = "ascenda-zero-cost-staging"/project_id = "ascenda-wa-l10"/' supabase/config.toml
sed -i 's/port = 54321/port = 59841/' supabase/config.toml
sed -i 's/port = 54322/port = 59842/' supabase/config.toml
sed -i 's/shadow_port = 54320/shadow_port = 59840/' supabase/config.toml
supabase stop --no-backup || true
docker ps -aq --filter 'name=ascenda-wa-l10' | xargs -r docker rm -f || true
rm -rf supabase/.temp supabase/.branches
supabase db start
for i in $(seq 1 30); do
  if pg_isready -h 127.0.0.1 -p 59842 -U postgres >/dev/null 2>&1; then break; fi
  if [ "$i" -eq 30 ]; then exit 1; fi
  sleep 1
done
cd "$ROOT"

# Minimal certified L4 substrate. It contains synthetic level-1/level-2 admins,
# conversations, template registry, AI/routing controls, outbound and messages.
psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa-l4/schema_contract.sql
# Production messages already carry delivery status; the L4 synthetic substrate predates it.
psql "$DB" -X -v ON_ERROR_STOP=1 -c "alter table public.aos_wa_messages_v1 add column if not exists status text;"
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260902235500_wa_l4_autonomous_authority_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260902235600_wa_l4_authority_hardening_v1.sql
# Add the exact synthetic conversation used by the dedicated L10 test.
psql "$DB" -X -v ON_ERROR_STOP=1 -c "insert into public.aos_wa_conversations_v1(id,state,contact_address_type,contact_address,human_takeover_at) values('55555555-5555-4555-8555-555555555551','AI_ACTIVE','PHONE','51911111111',null) on conflict(id) do nothing;"

# Freeze the pre-L10 existing-ledger fingerprint. Only L10 objects may change.
psql "$DB" -X -qAt -c "select jsonb_build_object('authority',(select count(*) from public.aos_wa_auto_authority_v1),'allowlist',(select count(*) from public.aos_wa_auto_allowlist_v1),'decisions',(select count(*) from public.aos_wa_auto_decisions_v1),'control_events',(select count(*) from public.aos_wa_auto_control_events_v1),'messages',(select count(*) from public.aos_wa_messages_v1),'outbound_requests',(select count(*) from public.aos_wa_outbound_requests_v1),'conversations',(select count(*) from public.aos_wa_conversations_v1));" > /tmp/l10-pre-existing-ledgers.json

# Migration is reversible before immutable audit history exists.
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260904014500_wa_l10_canary_observability_v1.sql
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_l10_canary_runs_v1")" = '0'
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_l10_canary_scope_v1")" = '0'
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/rollbacks/20260904014500_wa_l10_canary_observability_v1.rollback.sql
test "$(psql "$DB" -X -qAt -c "select to_regclass('public.aos_wa_l10_canary_runs_v1') is null")" = 't'

# Reapply and exercise the exact SAFE-OFF behavior.
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260904014500_wa_l10_canary_observability_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa-l10/tests/001_safe_off_observability.sql 2>&1 | tee /tmp/l10-safe-off-contract.txt
grep -q 'WA_L10_SAFE_OFF_OBSERVABILITY_PASS' /tmp/l10-safe-off-contract.txt

# Bounded readback must stay under the P0 fail-fast boundary in the isolated fixture.
psql "$DB" -X -v ON_ERROR_STOP=1 -c "set statement_timeout='3000ms'; select public.aos_wa_l10_status_v1('CI-L10-SAFE-OFF-0001');" >/tmp/l10-status.txt

# L10 evidence did not mutate any pre-existing authority/provider ledger.
psql "$DB" -X -qAt -c "select jsonb_build_object('authority',(select count(*) from public.aos_wa_auto_authority_v1),'allowlist',(select count(*) from public.aos_wa_auto_allowlist_v1),'decisions',(select count(*) from public.aos_wa_auto_decisions_v1),'control_events',(select count(*) from public.aos_wa_auto_control_events_v1),'messages',(select count(*) from public.aos_wa_messages_v1),'outbound_requests',(select count(*) from public.aos_wa_outbound_requests_v1),'conversations',(select count(*) from public.aos_wa_conversations_v1));" > /tmp/l10-post-existing-ledgers.json
# The L10 DB contract briefly writes then deactivates one L4 allowlist row to prove
# prep blocks active lists. That row is governance-test history, so compare only
# values that L10 itself is forbidden to mutate and require active allowlist zero.
python3 - <<'PY'
import json
pre=json.load(open('/tmp/l10-pre-existing-ledgers.json'))
post=json.load(open('/tmp/l10-post-existing-ledgers.json'))
for k in ('authority','decisions','messages','outbound_requests','conversations'):
    if pre[k] != post[k]:
        raise SystemExit(f'L10 existing-ledger drift {k}: {pre[k]} -> {post[k]}')
PY
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_auto_allowlist_v1 where active is true")" = '0'
test "$(psql "$DB" -X -qAt -c "select mode||':'||kill_switch_engaged from public.aos_wa_auto_authority_v1 where id=1")" = 'AUTO_OFF:true'
test "$(psql "$DB" -X -qAt -c "select auto_reply_enabled::text||':'||ai_send_enabled::text||':'||auto_routing_enabled::text||':'||human_send_enabled::text from public.aos_wa_ai_control_v1 cross join public.aos_wa_routing_control_v1 where aos_wa_ai_control_v1.id=1 and aos_wa_routing_control_v1.id=1")" = 'false:false:false:true'
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_messages_v1 where direction='OUTBOUND' and send_origin='AUTO')" = '0'

# Once audit evidence exists, rollback must fail closed rather than erase history.
set +e
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/rollbacks/20260904014500_wa_l10_canary_observability_v1.rollback.sql >/tmp/l10-recovery-block.txt 2>&1
rc=$?
set -e
test "$rc" -ne 0
grep -q 'WA_L10_RECOVERY_BLOCKED_AUDIT_HISTORY' /tmp/l10-recovery-block.txt
test "$(psql "$DB" -X -qAt -c "select to_regclass('public.aos_wa_l10_canary_runs_v1') is not null")" = 't'

(cd "$STAGING" && supabase db lint --local --schema public --level error 2>&1 | tee /tmp/l10-lint.txt)
! grep -q '\[ERROR\]' /tmp/l10-lint.txt

echo 'WA_L10_SAFE_OFF_FULL_LOCAL_PASS'
