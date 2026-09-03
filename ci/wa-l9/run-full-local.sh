#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB='postgresql://postgres:postgres@127.0.0.1:60202/postgres'
RUNTIME_PID=''

cleanup(){
  set +e
  if [ -n "$RUNTIME_PID" ]; then kill -TERM "$RUNTIME_PID" 2>/dev/null || true; sleep 2; fi
  cd "$ROOT/ci/wa4c-full-local" && supabase stop --no-backup >/dev/null 2>&1 || true
}
trap cleanup EXIT

cd "$ROOT"
test "${ASCENDA_FULL_LOCAL:-}" = '1'
python3 scripts/ci/enforce-zero-cost-policy.py

bash ci/wa4c-full-local/bootstrap.sh

set -a
# shellcheck disable=SC1091
source /tmp/ascenda-wa4c-full-local.env
set +a
export SUPABASE_URL='http://127.0.0.1:60201'
export SUPABASE_ANON_KEY="${ANON_KEY:-${PUBLISHABLE_KEY:-}}"
export SUPABASE_SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:-${SECRET_KEY:-}}"
export WA4C_LOCAL_DB_URL="$DB"
test -n "$SUPABASE_ANON_KEY"
test -n "$SUPABASE_SERVICE_ROLE_KEY"

# Certified identity / consent / booking / L4-L8 substrate layered on WA-4C FULL LOCAL.
psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa7a1-identity-resolution/rev_identity_stub.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260825213500_wa7a1_identity_resolution_bridge_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260825222500_wa7a2_identity_verification_continuity_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260827133000_wa7a3_attribution_ingress_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa7a4-marketing-eligibility/cia_recipient_controls_stub.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260827141500_wa7a4_marketing_eligibility_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260831224500_wa4c_booking_authority_v2.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260831231500_wa4c_governed_booking_pool_v2.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260901000500_wa4c_booking_search_path_fix_v2.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260901013500_agv2_unified_transactional_booking_contract_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260901193000_agv2_l3_delivery_outbox_v3.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260902235500_wa_l4_autonomous_authority_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260902235600_wa_l4_authority_hardening_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260903005500_wa_l5_conversational_booking_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260903005600_wa_l5_treatment_resolver_uuid_fix_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa-l6/prereq.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260903073000_wa_l6_meta_attribution_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260903183000_wa_l7_cost_intelligence_v1.sql
for f in \
  20260903194500_wa_l8_security_gate_v1.sql \
  20260903194600_wa_l8_bounded_preflight_fix_v1.sql \
  20260903194700_wa_l8_persistent_stop_index_v1.sql \
  20260903194800_wa_l8_scoped_eligibility_v1.sql \
  20260903194900_wa_l8_bounded_scoped_eligibility_v1.sql \
  20260903195000_wa_l8_bounded_eligibility_null_guard_v1.sql; do
  psql "$DB" -X -v ON_ERROR_STOP=1 -f "supabase/migrations/$f"
done
psql "$DB" -X -v ON_ERROR_STOP=1 -c "notify pgrst, 'reload schema';"

# Run the certified WA-4C booking/conversation corpus BEFORE the L8 chronology corpus.
# Both are valid independently, but the L8 fixture intentionally books synthetic slots;
# running it first can make the independent WA-4C booking canary correctly return 409.
export PORT=60300
export NODE_OPTIONS="--require $ROOT/ci/wa4c-full-local/local-network-preload.cjs --require $ROOT/ci/wa4c-full-local/local-supabase-auth-preload.cjs"
export WHATSAPP_VERIFY_TOKEN="${WHATSAPP_VERIFY_TOKEN:-wa-l9-full-local-verify-token}"
export WHATSAPP_APP_SECRET="${WHATSAPP_APP_SECRET:-wa-l9-full-local-app-secret}"
export WHATSAPP_ACCESS_TOKEN="${WHATSAPP_ACCESS_TOKEN:-wa-l9-full-local-test-token}"
export WHATSAPP_PHONE_NUMBER_ID="${WHATSAPP_PHONE_NUMBER_ID:-local-phone-id}"
export WHATSAPP_GRAPH_VERSION="${WHATSAPP_GRAPH_VERSION:-v23.0}"
export WA_CANARY_MODE='true'
export WA_CANARY_ALLOW_TO='51911111111'
(
  cd app
  exec node server-wa4.js
) >/tmp/wa-l9-runtime.log 2>&1 &
RUNTIME_PID=$!
for _ in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:60300/api/wa4/health >/tmp/wa-l9-health.json 2>/dev/null; then break; fi
  if ! kill -0 "$RUNTIME_PID" 2>/dev/null; then cat /tmp/wa-l9-runtime.log >&2; exit 1; fi
  sleep 1
done
curl -fsS http://127.0.0.1:60300/api/wa4/health >/dev/null

node ci/wa4c-full-local/run-canaries.js 2>&1 | tee /tmp/l9-wa4c-canaries.txt
node ci/wa4c-full-local/run-booking-canary.js 2>&1 | tee /tmp/l9-booking.txt
node ci/wa4c-full-local/run-conversation-beta.js 2>&1 | tee /tmp/l9-conversation.txt
grep -q 'WA4C_FULL_LOCAL_CANARIES_PASS' /tmp/l9-wa4c-canaries.txt
grep -q 'WA4C_GOVERNED_BOOKING_CANARY_PASS' /tmp/l9-booking.txt
grep -q 'WA4C_FULL_LOCAL_CONVERSATION_BETA_PASS' /tmp/l9-conversation.txt

# Existing consent/cost/security authority stays green after the booking corpus and
# still runs before L9 itself is installed.
psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa7a4-marketing-eligibility/tests/001_marketing_eligibility.sql 2>&1 | tee /tmp/l9-wa7a4.txt
grep -q 'WA7A4_MARKETING_ELIGIBILITY_PASS' /tmp/l9-wa7a4.txt
python3 ci/wa-l8/render_v3_chronology_canary.py > /tmp/l9-l8.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f /tmp/l9-l8.sql 2>&1 | tee /tmp/l9-l8.txt
grep -q 'WA_L8_SCOPED_CONSENT_COST_CLOSEOUT_PASS' /tmp/l9-l8.txt

# Freeze after all prerequisite fixture suites. From here forward only L9 may run;
# therefore PRE→POST exact equality proves L9 does not mutate protected ledgers.
psql "$DB" -X -qAt -c "select jsonb_build_object('agenda',(select count(*) from public.aos_agenda_citas),'calls',(select count(*) from public.aos_llamadas),'leads',(select count(*) from public.aos_leads),'sales',(select count(*) from public.aos_ventas),'patients',(select count(*) from public.aos_pacientes));" > /tmp/l9-pre.json

psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260903223000_wa_l9_shadow_demo_v1.sql
test "$(psql "$DB" -X -qAt -c "select to_regprocedure('public.aos_wa_l9_shadow_authorize_v1(uuid,text,text,text,text,text,text,text,text,boolean,text)') is not null")" = 't'
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_l9_demo_runs_v1")" = '0'
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/rollbacks/20260903223000_wa_l9_shadow_demo_v1.rollback.sql
test "$(psql "$DB" -X -qAt -c "select to_regclass('public.aos_wa_l9_demo_runs_v1') is null")" = 't'
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260903223000_wa_l9_shadow_demo_v1.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -c "notify pgrst, 'reload schema';"

psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa-l9/tests/001_shadow_authority_contract.sql 2>&1 | tee /tmp/l9-shadow.txt
grep -q 'WA_L9_SHADOW_AUTHORITY_CONTRACT_PASS' /tmp/l9-shadow.txt

# P0 #432 and privacy/non-dispatch invariants.
psql "$DB" -X -v ON_ERROR_STOP=1 -c "set statement_timeout='3000ms'; select public.aos_wa_l9_status_v1(); select public.aos_wa_l7_conversation_cost_v1('99999999-9999-4999-8999-999999999901'::uuid); select public.aos_wa_l7_journey_cost_v1('99999999-9999-4999-8999-999999999901'::uuid);"
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_l9_demo_runs_v1 where provider_dispatch is true or raw_content_stored is true")" = '0'
test "$(psql "$DB" -X -qAt -c "select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid where not t.tgisinternal and c.relname in ('aos_wa_messages_v1','aos_agenda_citas','aos_llamadas','aos_ventas') and pg_get_triggerdef(t.oid) ilike '%wa_l9%'")" = '0'
! grep -Eiq 'create[[:space:]]+materialized[[:space:]]+view|refresh[[:space:]]+materialized[[:space:]]+view' supabase/migrations/20260903223000_wa_l9_shadow_demo_v1.sql

psql "$DB" -X -qAt -c "select jsonb_build_object('agenda',(select count(*) from public.aos_agenda_citas),'calls',(select count(*) from public.aos_llamadas),'leads',(select count(*) from public.aos_leads),'sales',(select count(*) from public.aos_ventas),'patients',(select count(*) from public.aos_pacientes));" > /tmp/l9-post.json
diff -u /tmp/l9-pre.json /tmp/l9-post.json

test "$(psql "$DB" -X -qAt -c "select mode||':'||kill_switch_engaged from public.aos_wa_auto_authority_v1 where id=1")" = 'AUTO_OFF:true'
test "$(psql "$DB" -X -qAt -c "select auto_reply_enabled::text||':'||ai_send_enabled::text||':'||auto_routing_enabled::text||':'||human_send_enabled::text from public.aos_wa_ai_control_v1 cross join public.aos_wa_routing_control_v1 where aos_wa_ai_control_v1.id=1 and aos_wa_routing_control_v1.id=1")" = 'false:false:false:true'
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_messages_v1 where direction='OUTBOUND' and send_origin='AUTO'")" = '0'
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_outbound_requests_v1 where send_origin='AUTO'")" = '0'

# Once redacted demo evidence exists, recovery must fail closed.
set +e
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/rollbacks/20260903223000_wa_l9_shadow_demo_v1.rollback.sql >/tmp/l9-recovery.txt 2>&1
rc=$?
set -e
test "$rc" -ne 0
grep -q 'WA_L9_RECOVERY_BLOCKED_AUDIT_HISTORY' /tmp/l9-recovery.txt

(
  cd ci/wa4c-full-local
  supabase db lint --local --schema public --level error 2>&1 | tee /tmp/l9-lint.txt
)
if grep -q '\[ERROR\]' /tmp/l9-lint.txt; then exit 1; fi

echo 'WA_L9_AUTONOMOUS_DEMO_READY_FULL_LOCAL_PASS'
