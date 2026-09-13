'use strict'
const fs=require('fs')
const path=require('path')
const vm=require('vm')
const assert=require('assert')
const ROOT=path.resolve(__dirname,'../..')
function read(p){return fs.readFileSync(path.join(ROOT,p),'utf8')}
function ok(v,m){assert.ok(v,m)}
function compileJs(p){new vm.Script(read(p),{filename:p})}
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
ok(injected.indexOf('Abrir y guardar en Google Calendar')>0,'calendar CTA missing')
ok(injected.indexOf('Abrir y guardar en Google Calendar')<injected.toLowerCase().indexOf('</body>'),'calendar CTA must be inside body')

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
  "state:'SUPERSEDED'",
  'GOOGLE_CALENDAR_LINK_PERSIST_FAILED',
  'GOOGLE_CALENDAR_LEDGER_PERSIST_FAILED',
  'GOOGLE_CONTACT_LINK_PERSIST_FAILED'
]) ok(gateway.includes(token),'gateway missing '+token)
ok(!gateway.includes("console.log(refresh"),'refresh token must never be logged')
ok(!gateway.includes("console.log(tr.body"),'OAuth token response must never be logged')
ok(!gateway.includes('setInterval('),'Google module must not own a recurrent interval')
ok(!gateway.includes('setTimeout('),'Google module must not become a new recurrent network owner')
ok(!/select=\*/i.test(gateway),'Google integration must not add broad select=* reads')
ok(gateway.includes('✨ CITA ZIVITAL'),'Calendar event must carry patient-friendly ZIVITAL detail')
ok(gateway.includes("reminders:{useDefault:false"),'Calendar event must carry explicit reminders')
ok(gateway.includes('Estamos preparando tu cita en Google Calendar'),'Calendar link must explain short sync window')

const server=read('app/server.js')
ok(server.includes("if (p.indexOf('/api/google/') === 0) return GOOGLE_INTEGRATION.handle(req, res)"),'server Google boundary missing')
ok(server.includes('GOOGLE_INTEGRATION.injectEmailCalendarButton'),'email Calendar injection missing')
ok(server.includes('GOOGLE_INTEGRATION.processQueueOnce()'),'Google retry worker must reuse existing server scheduler')
ok(!server.includes('if (_autoTickRunning || !bgCanRun()) return'),'Google worker must not be blocked by unrelated background circuit')
ok(server.includes('if (bgCanRun()) {'),'existing business background must remain circuit-guarded')
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
const agendaSrc=read('app/public/agenda.js')
ok(agendaSrc.includes('aos_agenda_rebook_bridge_v1'),'Agenda rebook must use transactional canonical-to-legacy bridge')
ok(agendaSrc.includes("email_template:'reprogramacion'"),'Agenda rebook must use reprogram email after commit')
ok(!agendaSrc.includes("row.email_template='reprogramacion'"),'Agenda rows must never contain non-schema email_template')
ok(!agendaSrc.includes("Original marcada + nueva creada"),'legacy split-write rebook UX must be removed')
ok(agendaSrc.includes('aos_agenda_rebook_history_day_v1'),'Agenda must expose read-only rebook history on the original day')
ok(agendaSrc.includes('HISTORIAL DE REPROGRAMACIONES'),'Agenda must label historical rebooks as non-active history')
ok(agendaSrc.includes('fecha_anterior'),'Agenda reprogram email must receive the prior schedule')
ok(read('app/public/citas.html').includes("email_template:'reprogramacion'"),'Citas rebook must use reprogram email')

const callsSrc=read('app/public/calls.js')
const manualStart=callsSrc.indexOf('function guardarCitaManual')
const manualEnd=callsSrc.indexOf('// Incluir doctora en ccConfirmarCita')
ok(manualStart>=0&&manualEnd>manualStart,'Call Center manual appointment function missing')
const manualBlock=callsSrc.slice(manualStart,manualEnd)
ok(manualBlock.includes('aosQueueGoogleAppointment(rowC.id)'),'Call Center manual appointment must queue Google Calendar/Contacts')
const tipifStart=callsSrc.indexOf('function ccConfirmarCita')
const tipifEnd=callsSrc.indexOf('function ccConfirmarSeguimiento')
ok(tipifStart>=0&&tipifEnd>tipifStart,'Call Center appointment typification function missing')
ok(callsSrc.slice(tipifStart,tipifEnd).includes('results.every(function(r){return r&&r.ok;})'),'Call Center legacy appointment typification must verify both writes')

const loop6=read('app/public/calls-loop6.js')
ok(loop6.includes('aos_callcenter_commit_action_v1'),'Call Center runtime must keep atomic governed commit')
ok(loop6.includes('aos_callcenter_confirm_queue_appointment_v1'),'Call Center queue runtime must keep governed appointment commit')
ok(loop6.includes('cc6PostCommitAppointment(res,payload)'),'Call Center governed commits must share post-commit integrations')
ok(loop6.includes('aosQueueGoogleAppointment(agendaId)'),'Call Center governed appointments must queue Google Calendar/Contacts')
ok(loop6.includes('id:agendaId'),'Call Center confirmation email must carry appointment_id for Calendar CTA')

const historyMigration=read('supabase/migrations/20260913011500_agenda_rebook_history_projection_v1.sql')
for(const token of ['aos_agenda_rebook_history_v1','aos_agenda_rebook_history_day_v1','LEGACY_INLINE_V4','CORE_V2_HISTORY_V1'])
  ok(historyMigration.includes(token),'rebook history migration missing '+token)
ok(!/insert\s+into\s+public\.aos_agenda_citas/i.test(historyMigration),'rebook history must never create a second appointment row')

ok(server.includes('function buildEmailReprogramacion'),'server must have a safe reprogram email fallback')
ok(server.includes("subject = 'Tu cita fue reprogramada | '"),'reprogram email subject must be concise and trusted')
ok(gateway.includes("summary:'Zi Vital · '+(appt.tratamiento||'Cita')"),'Google invitation title must remain concise')
const rebookBridge=read('supabase/migrations/20260913003000_agenda_rebook_legacy_bridge_v1.sql')
for(const token of [
  'aos_agenda_rebook_bridge_v1','aos_agenda_rebook_legacy_safe_v1',
  'AGV2_REBOOK_TREATMENT_UNRESOLVED','AGV2_LEGACY_OUTSIDE_BUSINESS_HOURS',
  'for update','pg_advisory_xact_lock','google_queue_required'
]) ok(rebookBridge.toLowerCase().includes(token.toLowerCase()),'rebook bridge missing '+token)
ok(!/insert\s+into\s+public\.aos_agenda_citas/i.test(rebookBridge),'rebook bridge must preserve same appointment row')


const migration=read('supabase/migrations/20260912220000_google_integration_v1.sql')
for(const token of [
 'aos_google_connections_v1','aos_google_oauth_states_v1','aos_google_calendar_links_v1',
 'aos_google_contact_links_v1','aos_google_sync_outbox_v1','force row level security',
 'revoke all on public.aos_google_connections_v1 from anon, authenticated',
 'for update skip locked',
 'aos_google_enqueue_authorized_appointment_v1',
 'trg_aos_google_booking_operation_v1',
 'trg_aos_google_wa4_booking_action_v1',
 "new.operation_type in ('BOOK','REBOOK')",
 "new.status in ('BOOKED','REBOOKED')",
 "new.status in ('CANCELLED','REPLACED')"
]) ok(migration.toLowerCase().includes(token.toLowerCase()),'migration missing '+token)
ok(!/\brefresh_token\s+text\b/i.test(migration),'plaintext refresh_token column forbidden')
ok(!/(net\.http|http_post|http_get|extensions\.http|pg_net)/i.test(migration),'database must not make external HTTP calls')
ok(!/create\s+trigger\s+trg_aos_google_[\s\S]{0,240}?on\s+public\.(?:aos_agenda_citas|aos_pacientes)\b/i.test(migration),'legacy agenda/patient tables must not own Google side-effect triggers')
ok(/create\s+trigger\s+trg_aos_google_booking_operation_v1[\s\S]{0,240}?on\s+public\.aos_booking_operations_v2\b/i.test(migration),'Booking Core governed hook missing')
ok(/create\s+trigger\s+trg_aos_google_wa4_booking_action_v1[\s\S]{0,240}?on\s+public\.aos_wa4_booking_actions_v1\b/i.test(migration),'WA governed hook missing')
ok(gateway.includes("['CANCELADA','REAGENDADA']"),'server boundary must supersede cancelled/rebooked events')
ok(gateway.includes('/api/google/appointment/queue'),'authenticated appointment queue route missing')

for(const p of [
  'app/public/agenda.js',
  'app/public/agenda-governed-status-v1.js',
  'app/public/calls.js',
  'app/public/calls.html',
  'app/public/citas.html',
  'app/public/citas.js',
  'app/public/attendance.html'
]){
  const src=read(p)
  ok(src.includes('/api/google/appointment/queue'),'official appointment writer missing authenticated Google enqueue: '+p)
  ok(src.includes('X-ASCENDA-Session'),'official appointment writer missing session boundary: '+p)
}

compileJs('app/public/agenda-governed-status-v1.js')
compileJs('app/public/citas.js')
compileInlineHtml('app/public/admin-config.html')
compileInlineHtml('app/public/citas.html')
compileInlineHtml('app/public/attendance.html')
compileInlineHtml('app/public/calls.html')

console.log('GOOGLE_INTEGRATION_V1_STATIC_CONTRACT=PASS')
