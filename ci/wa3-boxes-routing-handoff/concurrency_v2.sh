#!/usr/bin/env bash
set -euo pipefail
: "${DB_URL:?DB_URL required}"

psql "$DB_URL" -X -v ON_ERROR_STOP=1 -f ci/wa3-boxes-routing-handoff/concurrency_setup_v2.sql >/tmp/wa3v2-race-setup.txt
A=/tmp/wa3v2-race-a.txt
B=/tmp/wa3v2-race-b.txt
rm -f "$A" "$B"

(
  psql "$DB_URL" -X -qAt -v ON_ERROR_STOP=1 -c "begin; select public.aos_wa3_claim_next_v2('dddddddd-dddd-4ddd-8ddd-dddddddddddd','44444444-4444-4444-8444-444444444444'); select pg_sleep(1); commit;" >"$A"
) &
PA=$!
sleep 0.05
(
  psql "$DB_URL" -X -qAt -v ON_ERROR_STOP=1 -c "begin; select public.aos_wa3_claim_next_v2('dddddddd-dddd-4ddd-8ddd-dddddddddddd','55555555-5555-4555-8555-555555555555'); select pg_sleep(1); commit;" >"$B"
) &
PB=$!
wait "$PA"
wait "$PB"

CLAIMED=$(cat "$A" "$B" | grep -c '"claimed": true' || true)
test "$CLAIMED" = "1"

ACTIVE=$(psql "$DB_URL" -X -qAt -c "select count(*) from public.aos_wa_assignments_v1 where conversation_id='30000000-0000-4000-8000-000000000001' and state='ACTIVE'")
CURRENT=$(psql "$DB_URL" -X -qAt -c "select count(*) from public.aos_wa_assignments_v1 where conversation_id='30000000-0000-4000-8000-000000000001' and state in ('ACTIVE','QUEUED')")
OWNER_OK=$(psql "$DB_URL" -X -qAt -c "select owner_user_id in ('44444444-4444-4444-8444-444444444444'::uuid,'55555555-5555-4555-8555-555555555555'::uuid) from public.aos_wa_conversations_v1 where id='30000000-0000-4000-8000-000000000001'")
STATE=$(psql "$DB_URL" -X -qAt -c "select state from public.aos_wa_conversations_v1 where id='30000000-0000-4000-8000-000000000001'")

test "$ACTIVE" = "1"
test "$CURRENT" = "1"
test "$OWNER_OK" = "t"
test "$STATE" = "HUMAN_ACTIVE"

echo "WA-3 V2 concurrent claim: PASS (exactly one owner)"
