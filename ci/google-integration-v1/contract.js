'use strict'
const fs=require('fs')
const path=require('path')
const vm=require('vm')
const assert=require('assert')
const ROOT=path.resolve(__dirname,'../..')
function read(p){return fs.readFileSync(path.join(ROOT,p),'utf8')}
function ok(v,m){assert.ok(v,m)}
function compileInlineHtml(p){
  const src=read(p)
  const re=/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi
  let m,count=0
  while((m=re.exec(src))){
    if(!m[1].trim())continue
    new vm.Script(m[1],{filename:p+'#script'+(++count)})
  }
  ok(count>0,p+': no inline script compiled')
}

process.env.GOOGLE_TOKEN_ENCRYPTION_KEY='synthetic-ci-key-not-production-32bytes'
process.env.GOOGLE_REDIRECT_URI='https://example.invalid/api/google/oauth/callback'
process.env.GOOGLE_CLIENT_ID='synthetic.apps.googleusercontent.com'
process.env.GOOGLE_CLIENT_SECRET='synthetic-not-real'
process.env.GOOGLE_INTEGRATION_ENABLED='true'
process.env.GOOGLE_CALENDAR_SYNC_ENABLED='true'
process.env.GOOGLE_CONTACT_SYNC_ENABLED='false'

const mod=require(path.join(ROOT,'app/google-integration-v1.js'))
const gw=mod.createGoogleIntegrationV1({})
const secret='refresh-token-synthetic-value'
const enc=gw._test.encryptSecret(secret)
ok(enc.startsWith('v1.'),'encrypted token must be versioned')
ok(!enc.includes(secret),'encrypted token must not expose plaintext')
assert.strictEqual(gw._test.decryptSecret(enc),secret,'AES-GCM roundtrip')
assert.strictEqual(gw._test.calendarLinkSignature('appt-1'),gw._test.calendarLinkSignature('appt-1'),'signature deterministic')
assert.notStrictEqual(gw._test.calendarLinkSignature('appt-1'),gw._test.calendarLinkSignature('appt-2'),'signature appointment-bound')
assert.strictEqual(gw._test.contactTag('Toxina Botulínica',{}),'TOX','ZIVITAL tag normalization')
assert.strictEqual(gw._test.monthCode('2026-06-15T10:00:00-05:00'),'JUN','Spanish month contract')
const injected=gw.injectEmailCalendarButton('<html><body><p>Cita</p></body></html>','appt-1')
ok(injected.indexOf('Ver en Google Calendar')>0,'calendar CTA missing')
ok(injected.indexOf('Ver en Google Calendar')<injected.toLowerCase().indexOf('</body>'),'calendar CTA must be inside body')

const gateway=read('app/google-integration-v1.js')
for(const token of [
  "access_type:'offline'",
  "prompt:'consent'",
  'calendar.events.owned',
  'calendar.calendarlist.readonly',
  '/auth/contacts',
  'refresh_token_enc',
  'aes-256-gcm',
  'timingSafeEqual',
  'CONTACT_IDENTITY_CONFLICT',
  'sendUpdates=all',
  "['CANCELADA','REAGENDADA']",
  'extendedProperties',
  'aos_google_claim_sync_v1',
  "x.accessRole==='owner'",
  "state:'SUPERSEDED'"
]) ok(gateway.includes(token),'gateway missing '+token)
ok(!gateway.includes("console.log(refresh"),'refresh token must never be logged')
ok(!gateway.includes("console.log(tr.body"),'OAuth token response must never be logged')

const server=read('app/server.js')
ok(server.includes("if (p.indexOf('/api/google/') === 0) return GOOGLE_INTEGRATION.handle(req, res)"),'server Google boundary missing')
ok(server.includes('GOOGLE_INTEGRATION.injectEmailCalendarButton'),'email Calendar injection missing')
ok(server.includes('EMAIL_GATEWAY.verifyApp'),'existing app auth boundary must remain')

const admin=read('app/public/admin-config.html')
for(const token of ['/api/google/status','/api/google/oauth/start','/api/google/calendars','/api/google/settings','/api/google/disconnect'])
  ok(admin.includes(token),'admin Google UI missing '+token)
for(const forbidden of ['GOOGLE_CLIENT_SECRET','refresh_token_enc','oauth2.googleapis.com/token'])
  ok(!admin.includes(forbidden),'browser must not contain '+forbidden)

for(const p of ['app/public/agenda.js','app/public/calls.js','app/public/calls.html','app/public/citas.html','app/public/attendance.html']){
  const src=read(p)
  ok(src.includes('appointment_id'),'email caller must carry appointment_id: '+p)
  ok(src.includes('X-ASCENDA-Session'),'email caller must keep session auth: '+p)
}
ok(read('app/public/agenda.js').includes("email_template='reprogramacion'"),'Agenda rebook must use reprogram email')
ok(read('app/public/citas.html').includes("email_template:'reprogramacion'"),'Citas rebook must use reprogram email')

const migration=read('supabase/migrations/20260912220000_google_integration_v1.sql')
for(const token of [
 'aos_google_connections_v1','aos_google_oauth_states_v1','aos_google_calendar_links_v1',
 'aos_google_contact_links_v1','aos_google_sync_outbox_v1','force row level security',
 'revoke all on public.aos_google_connections_v1 from anon, authenticated',
 'for update skip locked',"in ('CANCELADA','REAGENDADA')"
]) ok(migration.toLowerCase().includes(token.toLowerCase()),'migration missing '+token)
ok(!/\brefresh_token\s+text\b/i.test(migration),'plaintext refresh_token column forbidden')
ok(!/(net\.http|http_post|http_get|extensions\.http|pg_net)/i.test(migration),'database must not make external HTTP calls')

compileInlineHtml('app/public/admin-config.html')
compileInlineHtml('app/public/citas.html')
compileInlineHtml('app/public/attendance.html')
compileInlineHtml('app/public/calls.html')

console.log('GOOGLE_INTEGRATION_V1_STATIC_CONTRACT=PASS')
