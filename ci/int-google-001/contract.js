'use strict'

const assert=require('assert')
const fs=require('fs')
function read(p){return fs.readFileSync(p,'utf8')}

const runtime=read('app/google-integration-v1.js')
const outer=read('app/server-f17.js')
const ui=read('app/public/admin-config.html')
const email=read('app/server.js')
const migration=read('supabase/migrations/20260912230500_int_google_001_governed_integration_v1.sql')
const rollback=read('supabase/rollbacks/20260912230500_int_google_001_governed_integration_v1.rollback.sql')

for(const table of [
  'aos_google_oauth_states_v1','aos_google_connections_v1','aos_google_calendar_links_v1',
  'aos_google_contact_links_v1','aos_google_sync_outbox_v1'
]) {
  assert(migration.includes(table),'missing Google table '+table)
  assert(migration.includes('alter table public.'+table+' force row level security'),'FORCE RLS missing '+table)
  assert(migration.includes('revoke all on table public.'+table+' from public,anon,authenticated'),'browser ACL revoke missing '+table)
  assert(rollback.includes('drop table if exists public.'+table),'rollback missing '+table)
}
assert(migration.includes("state text not null default 'DORMANT'"),'Google outbox must start dormant')
assert(migration.includes("after insert on public.aos_agenda_events_v2"),'booking/rebook projection trigger missing')
assert(migration.includes("after update of estado_cita on public.aos_agenda_citas"),'cancel projection trigger missing')
assert(migration.includes("GOOGLE_SERVER_FLAGS_AND_OAUTH_REQUIRED"),'dispatch boundary evidence missing')
assert(migration.includes('for update skip locked'),'leased outbox must claim work atomically')
assert(migration.includes("lease_until=now()+interval '90 seconds'"),'recoverable outbox lease missing')
assert(runtime.includes("serviceRpc('aos_google_sync_claim_v1'"),'runtime must use DB lease claim instead of browser/direct queue polling')
assert(!/https?:\/\//i.test(migration),'database migration must not call Google HTTP')
assert(!/refresh_token\s+text/i.test(migration),'plaintext refresh-token column forbidden')
assert(migration.includes('refresh_token_ciphertext text not null'),'encrypted token field missing')

assert(runtime.includes("createCipheriv('aes-256-gcm'"),'AES-GCM token encryption missing')
assert(runtime.includes("createDecipheriv('aes-256-gcm'"),'AES-GCM token decryption missing')
assert(runtime.includes("state_hash"),'hashed OAuth state missing')
assert(runtime.includes("prompt','consent'"),'offline refresh-token consent flow missing')
assert(runtime.includes("GOOGLE_INTEGRATION_ENABLED"),'master SAFE-OFF flag missing')
assert(runtime.includes("GOOGLE_CALENDAR_SYNC_ENABLED"),'Calendar SAFE-OFF flag missing')
assert(runtime.includes("GOOGLE_CONTACT_SYNC_ENABLED"),'Contacts SAFE-OFF flag missing')
assert(runtime.includes("if(!configured()||!f.integration||(!f.calendar&&!f.contacts))return {skipped:true}"),'worker SAFE-OFF guard missing')
assert(runtime.includes("sendUpdates=none"),'Google must not replace Resend communication authority')
assert(runtime.includes("extendedProperties"),'ASCENDA appointment/revision correlation missing')
assert(runtime.includes("google_event_id"),'same-event Calendar link missing')
assert(runtime.includes("method:'PATCH'")||runtime.includes("googleJson('PATCH'"),'Calendar rebook/update PATCH missing')
assert(runtime.includes("CALENDAR_DELETE"),'cancel/delete path missing')
assert(runtime.includes("PATIENT_IDENTITY_AMBIGUOUS"),'ambiguous patient identity fail-closed missing')
assert(runtime.includes("PATIENT_IDENTITY_CONFLICT"),'patient identity conflict fail-closed missing')
assert(!runtime.includes("Nombres=eq."),'Contacts must never dedupe by name')
assert(runtime.includes("numero_limpio=eq."),'exact phone identity lookup missing')
assert(runtime.includes("Email=eq."),'exact email identity lookup missing')
assert(runtime.includes("GOOGLE_CANARY"),'explicit human canary confirmation missing')
assert(runtime.includes("GOOGLE_BACKFILL"),'explicit post-canary backfill confirmation missing')
assert(runtime.includes("GOOGLE_TREATMENT_AUTHORITY_UNRESOLVED"),'Calendar duration must fail closed when treatment authority is unresolved')
assert(runtime.includes("aos_booking_timing_for_service_v2"),'governed duration authority missing')

assert(outer.includes("verifyPanel(token, 'admin-config', strong)"),'Google admin-config role/2FA boundary missing')
assert(outer.includes("url.pathname.indexOf('/api/google/') === 0"),'Google outer-server route boundary missing')
assert(outer.includes("googleIntegration.startWorker()"),'Google worker lifecycle missing')
assert(outer.includes("googleIntegration.stopWorker()"),'Google worker shutdown missing')

assert(ui.includes("Google Calendar + Contacts"),'Google connector UI missing')
assert(ui.includes("sessionStorage.getItem('aos_app_token')"),'Google UI must use current strong app session')
assert(ui.includes("/api/google/oauth/start"),'Google OAuth UI action missing')
assert(ui.includes("/api/google/canary/candidates"),'bounded canary candidate selector missing')
assert(ui.includes("confirm:'GOOGLE_CANARY'"),'human canary explicit confirmation missing in UI')
assert(!ui.includes('GOOGLE_CLIENT_SECRET'),'Google client secret must never enter browser')
assert(!ui.includes('GOOGLE_TOKEN_ENCRYPTION_KEY'),'Google token encryption key must never enter browser')

const inlineScripts=[...ui.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(m=>m[1]).filter(Boolean)
assert(inlineScripts.length>0,'admin-config inline script missing')
for(const block of inlineScripts)new Function(block)

assert(email.includes('function emailGoogleCalendarAction'),'Resend Calendar action helper missing')
assert(email.includes("calendar.google.com','www.google.com"),'Calendar action URL allowlist missing')
assert(email.includes("d.calendar_url || ''"),'appointment email Calendar action not wired')

const {createGoogleIntegration}=require('../../app/google-integration-v1')
const env={
  GOOGLE_CLIENT_ID:'client',
  GOOGLE_CLIENT_SECRET:'secret',
  GOOGLE_REDIRECT_URI:'https://example.invalid/api/google/oauth/callback',
  GOOGLE_TOKEN_ENCRYPTION_KEY:'test-encryption-material-32-plus-bytes',
  GOOGLE_INTEGRATION_ENABLED:'false',
  GOOGLE_CALENDAR_SYNC_ENABLED:'false',
  GOOGLE_CONTACT_SYNC_ENABLED:'false'
}
const g=createGoogleIntegration({
  verifyConfig:async()=>({ok:true,actor_id:'11111111-1111-4111-8111-111111111111'}),
  serviceRpc:async()=>({}),
  readRaw:async()=>Buffer.from('{}'),
  writeJson:()=>{},
  supabaseUrl:'https://example.invalid',
  serviceRoleKey:'service-role-test-value-long-enough',
  env
})
assert.strictEqual(g.configured(),true)
assert.deepStrictEqual(g.flags(),{integration:false,calendar:false,contacts:false})
const enc=g.encryptToken('refresh-token-private')
assert.notStrictEqual(enc.ciphertext,'refresh-token-private')
assert.strictEqual(g.decryptToken({refresh_token_ciphertext:enc.ciphertext,token_iv:enc.iv,token_tag:enc.tag}),'refresh-token-private')

console.log('INT_GOOGLE_001_CONTRACT_PASS')
