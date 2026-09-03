#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PID=''
cleanup(){ set +e; [ -z "$PID" ] || kill -TERM "$PID" 2>/dev/null || true; cd "$ROOT/ci/wa4c-full-local" && supabase stop --no-backup >/dev/null 2>&1 || true; }
trap cleanup EXIT
cd "$ROOT"
test "${ASCENDA_FULL_LOCAL:-}" = '1'
python3 scripts/ci/enforce-zero-cost-policy.py
bash ci/wa4c-full-local/bootstrap.sh
set -a
source /tmp/ascenda-wa4c-full-local.env
set +a
export SUPABASE_URL='http://127.0.0.1:60201'
export SUPABASE_ANON_KEY="${ANON_KEY:-${PUBLISHABLE_KEY:-}}"
export SUPABASE_SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY:-${SECRET_KEY:-}}"
export WA4C_LOCAL_DB_URL='postgresql://postgres:postgres@127.0.0.1:60202/postgres'
export PORT=60300
export NODE_OPTIONS="--require $ROOT/ci/wa4c-full-local/local-network-preload.cjs --require $ROOT/ci/wa4c-full-local/local-supabase-auth-preload.cjs"
export WHATSAPP_VERIFY_TOKEN='wa-l9-local-verify'
export WHATSAPP_APP_SECRET='wa-l9-local-secret'
export WHATSAPP_ACCESS_TOKEN='wa-l9-local-test-only'
export WHATSAPP_PHONE_NUMBER_ID='local-phone-id'
export WHATSAPP_GRAPH_VERSION='v23.0'
export WA_CANARY_MODE='true'
export WA_CANARY_ALLOW_TO='51911111111'
(cd app && exec node server-wa4.js) >/tmp/wa-l9-wa4c-runtime.log 2>&1 & PID=$!
for _ in $(seq 1 60); do
  curl -fsS http://127.0.0.1:60300/api/wa4/health >/dev/null 2>&1 && break
  kill -0 "$PID" 2>/dev/null || { cat /tmp/wa-l9-wa4c-runtime.log >&2; exit 1; }
  sleep 1
done
curl -fsS http://127.0.0.1:60300/api/wa4/health >/dev/null
node ci/wa4c-full-local/run-canaries.js 2>&1 | tee /tmp/l9-wa4c.txt
node ci/wa4c-full-local/run-booking-canary.js 2>&1 | tee /tmp/l9-wa4c-booking.txt
node ci/wa4c-full-local/run-conversation-beta.js 2>&1 | tee /tmp/l9-wa4c-conversation.txt
grep -q 'WA4C_FULL_LOCAL_CANARIES_PASS' /tmp/l9-wa4c.txt
grep -q 'WA4C_GOVERNED_BOOKING_CANARY_PASS' /tmp/l9-wa4c-booking.txt
grep -q 'WA4C_FULL_LOCAL_CONVERSATION_BETA_PASS' /tmp/l9-wa4c-conversation.txt
test "$(psql "$WA4C_LOCAL_DB_URL" -X -qAt -c "select count(*) from public.aos_wa_messages_v1 where direction='OUTBOUND' and coalesce(send_origin,'')='AUTO'")" = '0'
test "$(psql "$WA4C_LOCAL_DB_URL" -X -qAt -c "select count(*) from public.aos_wa4_booking_actions_v1 where status='BOOKED'")" = '1'
echo 'WA_L9_WA4C_CANONICAL_REGRESSION_PASS'
