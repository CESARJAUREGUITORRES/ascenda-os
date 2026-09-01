'use strict'

const test=require('node:test')
const assert=require('node:assert/strict')
const fs=require('node:fs')

const migration=fs.readFileSync('supabase/migrations/20260901193000_agv2_l3_delivery_outbox_v3.sql','utf8')
const rollback=fs.readFileSync('supabase/rollbacks/20260901193000_agv2_l3_delivery_outbox_v3_rollback.sql','utf8')
const server=fs.readFileSync('app/server.js','utf8')

function has(s){assert.ok(migration.includes(s),`missing contract: ${s}`)}

test('L3 is durable/idempotent and remains dormant until L4',()=>{
  has('aos_agenda_delivery_outbox_v3')
  has('idempotency_key text not null unique')
  has("state text not null default 'DORMANT'")
  has("'dispatch_boundary','L4_AUTHORITY_REQUIRED'")
  assert.equal(/sendResend|graph\.facebook\.com|https:\/\//i.test(migration),false,'DDL must not perform provider network dispatch')
})

test('booking event projection is fail-soft and repairable',()=>{
  has('trg_aos_agenda_delivery_event_v3')
  has('after insert on public.aos_agenda_events_v2')
  has('Delivery projection is repairable from the append-only event ledger. Never roll back a booking.')
  has('aos_agenda_delivery_reconcile_v3')
  has('exception when others then')
})

test('BOOK and REBOOK confirmations are revision-aware',()=>{
  has("v_kind:=case when v_e.event_type='BOOKED' then 'CONFIRMATION' else 'REPROGRAMMATION' end")
  has("blocking_reason='SUPERSEDED_BY_RESCHEDULE'")
  has("schedule_revision<>v_e.id::text")
  has("provider_message_id is null")
})

test('TODAY/TOMORROW reminders are local-time, V2-only, and idempotent',()=>{
  has("at time zone 'America/Lima'")
  has("c.fecha_cita in (v_local_date,v_local_date+1)")
  has("exists(select 1 from public.aos_agenda_events_v2 e where e.appointment_id=c.id)")
  has("'REMINDER_TODAY' else 'REMINDER_TOMORROW'")
  has("v_key:='agv2-l3:'||p_schedule_revision||':'||v_kind||':'||v_channel")
})

test('current email runtime already supports the L3 transactional contracts',()=>{
  assert.ok(server.includes("tipo === 'confirmacion_cita'"),'confirmation renderer missing')
  assert.ok(server.includes("tipo === 'reprogramacion'"),'reprogram renderer missing')
  assert.ok(server.includes("template === 'recordatorio_manana'"),'tomorrow reminder runtime missing')
  assert.ok(server.includes('buildEmailRecordatorio'),'reminder renderer missing')
  assert.ok(server.includes("'recordatorio_hoy'"),'today reminder contract missing')
  assert.ok(server.includes("'recordatorio_manana'"),'tomorrow reminder transactional type missing')
})

test('email can be provider-ready but WhatsApp remains fail-closed pending Meta approval',()=>{
  has("('CONFIRMATION','EMAIL','*','confirmacion_cita','RESEND','confirmacion_cita',true")
  has("('REPROGRAMMATION','EMAIL','*','reprogramacion','RESEND','reprogramacion',true")
  has("('CONFIRMATION','WHATSAPP','*','cita_confirmada','META_CLOUD_API',null,false")
  has('PROVIDER_TEMPLATE_APPROVAL_UNVERIFIED')
  has('recordatorio_manana_si')
  has('recordatorio_manana_pl')
  has('recordatorio_hoy_si')
  has('recordatorio_hoy_pl')
})

test('rollback is narrow and never mutates Agenda data',()=>{
  assert.ok(rollback.includes('drop trigger if exists trg_aos_agenda_delivery_event_v3'))
  assert.ok(rollback.includes('drop table if exists public.aos_agenda_delivery_outbox_v3'))
  assert.equal(/delete\s+from\s+public\.aos_agenda_citas|update\s+public\.aos_agenda_citas/i.test(rollback),false)
})
