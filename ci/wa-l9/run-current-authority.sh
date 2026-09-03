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
for f in 20260903194500_wa_l8_security_gate_v1.sql 20260903194600_wa_l8_bounded_preflight_fix_v1.sql 20260903194700_wa_l8_persistent_stop_index_v1.sql 20260903194800_wa_l8_scoped_eligibility_v1.sql 20260903194900_wa_l8_bounded_scoped_eligibility_v1.sql 20260903195000_wa_l8_bounded_eligibility_null_guard_v1.sql; do
  psql "$DB" -X -v ON_ERROR_STOP=1 -f "supabase/migrations/$f"
done

# Canonical CURRENT BOOK/REBOOK gate from WA-L5.
psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa-l5/fixture.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa-l5/tests/001_book_rebook_contract.sql 2>&1 | tee /tmp/l9-current-l5.txt
grep -q 'WA_L5_BOOK_REBOOK_CONTRACT_PASS' /tmp/l9-current-l5.txt
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_booking_operations_v2 where operation_type='BOOK'")" -ge 1
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_booking_operations_v2 where operation_type='REBOOK'")" -ge 1

# Current consent/security/cost regression before L9.
psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa7a4-marketing-eligibility/tests/001_marketing_eligibility.sql 2>&1 | tee /tmp/l9-current-wa7a4.txt
grep -q 'WA7A4_MARKETING_ELIGIBILITY_PASS' /tmp/l9-current-wa7a4.txt
python3 ci/wa-l8/render_v3_chronology_canary.py > /tmp/l9-current-l8.sql
psql "$DB" -X -v ON_ERROR_STOP=1 -f /tmp/l9-current-l8.sql 2>&1 | tee /tmp/l9-current-l8.txt
grep -q 'WA_L8_SCOPED_CONSENT_COST_CLOSEOUT_PASS' /tmp/l9-current-l8.txt

# Freeze after every prerequisite fixture. From this boundary onward only L9 runs.
psql "$DB" -X -qAt -c "select jsonb_build_object('agenda',(select count(*) from public.aos_agenda_citas),'calls',(select count(*) from public.aos_llamadas),'leads',(select count(*) from public.aos_leads),'sales',(select count(*) from public.aos_ventas),'patients',(select count(*) from public.aos_pacientes));" > /tmp/l9-current-pre.json

psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260903223000_wa_l9_shadow_demo_v1.sql
test "$(psql "$DB" -X -qAt -c "select to_regprocedure('public.aos_wa_l9_shadow_authorize_v1(uuid,text,text,text,text,text,text,text,text,boolean,text)') is not null")" = 't'
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_l9_demo_runs_v1")" = '0'
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/rollbacks/20260903223000_wa_l9_shadow_demo_v1.rollback.sql
test "$(psql "$DB" -X -qAt -c "select to_regclass('public.aos_wa_l9_demo_runs_v1') is null")" = 't'
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20260903223000_wa_l9_shadow_demo_v1.sql

psql "$DB" -X -v ON_ERROR_STOP=1 -f ci/wa-l9/tests/001_shadow_authority_contract.sql 2>&1 | tee /tmp/l9-current-shadow.txt
grep -q 'WA_L9_SHADOW_AUTHORITY_CONTRACT_PASS' /tmp/l9-current-shadow.txt

# P0/privacy/non-dispatch and exact protected-ledger parity.
psql "$DB" -X -v ON_ERROR_STOP=1 -c "set statement_timeout='3000ms'; select public.aos_wa_l9_status_v1(); select public.aos_wa_l7_conversation_cost_v1('99999999-9999-4999-8999-999999999901'::uuid); select public.aos_wa_l7_journey_cost_v1('99999999-9999-4999-8999-999999999901'::uuid);"
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_l9_demo_runs_v1 where provider_dispatch is true or raw_content_stored is true")" = '0'
test "$(psql "$DB" -X -qAt -c "select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid where not t.tgisinternal and c.relname in ('aos_wa_messages_v1','aos_agenda_citas','aos_llamadas','aos_ventas') and pg_get_triggerdef(t.oid) ilike '%wa_l9%'")" = '0'
psql "$DB" -X -qAt -c "select jsonb_build_object('agenda',(select count(*) from public.aos_agenda_citas),'calls',(select count(*) from public.aos_llamadas),'leads',(select count(*) from public.aos_leads),'sales',(select count(*) from public.aos_ventas),'patients',(select count(*) from public.aos_pacientes));" > /tmp/l9-current-post.json
diff -u /tmp/l9-current-pre.json /tmp/l9-current-post.json

test "$(psql "$DB" -X -qAt -c "select mode||':'||kill_switch_engaged from public.aos_wa_auto_authority_v1 where id=1")" = 'AUTO_OFF:true'
test "$(psql "$DB" -X -qAt -c "select auto_reply_enabled::text||':'||ai_send_enabled::text||':'||auto_routing_enabled::text||':'||human_send_enabled::text from public.aos_wa_ai_control_v1 cross join public.aos_wa_routing_control_v1 where aos_wa_ai_control_v1.id=1 and aos_wa_routing_control_v1.id=1")" = 'false:false:false:true'
test "$(psql "$DB" -X -qAt -c "select count(*) from public.aos_wa_messages_v1 where direction='OUTBOUND' and send_origin='AUTO'")" = '0'

set +e
psql "$DB" -X -v ON_ERROR_STOP=1 -f supabase/rollbacks/20260903223000_wa_l9_shadow_demo_v1.rollback.sql >/tmp/l9-current-recovery.txt 2>&1
rc=$?
set -e
test "$rc" -ne 0
grep -q 'WA_L9_RECOVERY_BLOCKED_AUDIT_HISTORY' /tmp/l9-current-recovery.txt

(cd ci/wa4c-full-local && supabase db lint --local --schema public --level error 2>&1 | tee /tmp/l9-current-lint.txt)
! grep -q '\[ERROR\]' /tmp/l9-current-lint.txt
echo 'WA_L9_CURRENT_AUTHORITY_FULL_LOCAL_PASS'
