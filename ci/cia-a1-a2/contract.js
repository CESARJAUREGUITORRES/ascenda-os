const fs=require('fs')
function read(p){return fs.readFileSync(p,'utf8')}
function ok(v,m){if(!v){console.error('CIA A1+A2 CONTRACT FAIL:',m);process.exit(1)}}

const a1=read('supabase/migrations/20260930030000_cia_a1_acquisition_landing_facts_v1.sql')
const a2=read('supabase/migrations/20260930031000_cia_a2_event_runtime_freshness_v1.sql')

ok(a1.includes('aos_cia_acquisition_facts_v1'),'acquisition facts view missing')
ok(a1.includes('aos_landing_booking_attribution'),'landing attribution source missing')
ok(a1.includes("'ACQUISITION'"),'ACQUISITION registry mapping missing')
ok(a1.includes('acquisition.landing_code')&&a1.includes('acquisition.campaign_code')&&a1.includes('acquisition.ad_code'),'landing/campaign/ad dimensions missing')
ok(a1.includes('latest_utm_source')&&a1.includes('latest_utm_campaign')&&a1.includes('latest_utm_content'),'UTM lineage missing')
ok(a1.includes('aos_cia_audience_leaf_keys_v3'),'audience resolver extension missing')
ok(a1.includes('WEB_BOOKINGS')&&a1.includes('WEB_BOOKINGS_FUTURE')&&a1.includes('WEB_BOOKINGS_NO_PURCHASE'),'web audience presets missing')

ok(a2.includes('aos_cia_runtime_freshness_v1'),'freshness state missing')
ok(a2.includes('aos_cia_runtime_refresh_acquisition_one_v1'),'incremental acquisition refresh missing')
ok(a2.includes('aos_cia_runtime_refresh_profile_one_v1'),'incremental profile refresh missing')
ok(a2.includes('aos_cia_runtime_refresh_appointment_one_v1'),'incremental appointment refresh missing')
ok(a2.includes('aos_cia_runtime_refresh_call_one_v1'),'incremental call refresh missing')
ok(a2.includes('aos_cia_runtime_refresh_sale_one_v1'),'incremental sale refresh missing')
ok(a2.includes('aos_cia_runtime_refresh_lead_one_v1'),'incremental lead refresh missing')
ok(a2.includes('aos_cia_catalog_recount_runtime_v1'),'runtime recount missing')
ok(a2.includes('FOR EACH STATEMENT')||a2.includes('for each statement'),'statement-level coalesced recount missing')
ok(a2.includes('pg_try_advisory_xact_lock'),'single-flight recount lock missing')

const combined=a1+'\n'+a2
ok(!combined.includes('START_DISTRIBUTION'),'A1+A2 must not enable bulk distribution')
ok(!combined.includes('SET_GLOBAL'),'A1+A2 must not change global Call Center routing')
ok(!combined.includes('send_email'),'A1+A2 must not send email')
ok(!combined.includes('WHATSAPP_SEND'),'A1+A2 must not send WhatsApp')

console.log('CIA A1+A2 CONTRACT PASS')
