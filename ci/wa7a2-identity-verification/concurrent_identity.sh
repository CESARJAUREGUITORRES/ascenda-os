#!/usr/bin/env bash
set -euo pipefail
: "${DB_URL:?DB_URL required}"

psql "$DB_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
insert into public.aos_wa_messages_v1(provider_message_id,direction,from_number,from_user_id,phone_number_id,message_type,status,provider_timestamp,received_at)
values('wamid.wa7a2.concurrent.seed','INBOUND','51966666666','PE.CONCURRENT.OLD','pn-concurrent','text','received',now(),now());
insert into public.aos_wa_events_v1(event_key,event_type,status,payload)
values('identity:pair:concurrent.seed','identity.meta_pair','observed',jsonb_build_object('business_scope','pn-concurrent','phone','51966666666','user_id','PE.CONCURRENT.OLD','observed_at',now()));
SQL

psql "$DB_URL" -X -v ON_ERROR_STOP=1 -c "insert into public.aos_wa_events_v1(event_key,event_type,status,payload) values('identity:system:concurrent:A','identity.system_change','observed',jsonb_build_object('business_scope','pn-concurrent','system_type','user_changed_user_id','previous_user_id','PE.CONCURRENT.OLD','user_id','PE.CONCURRENT.A','observed_at',now()));" &
p1=$!
psql "$DB_URL" -X -v ON_ERROR_STOP=1 -c "insert into public.aos_wa_events_v1(event_key,event_type,status,payload) values('identity:system:concurrent:B','identity.system_change','observed',jsonb_build_object('business_scope','pn-concurrent','system_type','user_changed_user_id','previous_user_id','PE.CONCURRENT.OLD','user_id','PE.CONCURRENT.B','observed_at',now()));" &
p2=$!
wait "$p1"
wait "$p2"

verified="$(psql "$DB_URL" -X -qAt -c "select count(*) from public.aos_wa_events_v1 where event_key in ('identity:system:concurrent:A','identity:system:concurrent:B') and status='VERIFIED'")"
conflict="$(psql "$DB_URL" -X -qAt -c "select count(*) from public.aos_wa_events_v1 where event_key in ('identity:system:concurrent:A','identity:system:concurrent:B') and status='CONFLICT'")"
active_bsuid="$(psql "$DB_URL" -X -qAt -c "select count(*) from public.aos_wa_channel_aliases_v1 where business_scope='pn-concurrent' and alias_type='BSUID' and active")"
active_phone="$(psql "$DB_URL" -X -qAt -c "select count(*) from public.aos_wa_channel_aliases_v1 where business_scope='pn-concurrent' and alias_type='PHONE' and active")"

[[ "$verified" == "1" ]]
[[ "$conflict" == "1" ]]
[[ "$active_bsuid" == "1" ]]
[[ "$active_phone" == "0" ]]
echo WA7A2_CONCURRENT_LINEAGE_PASS
