'use strict';
const fs=require('fs');
const test=require('node:test');
const assert=require('node:assert/strict');

const migration=fs.readFileSync('supabase/migrations/20260929234000_marketing_web_booking_lineage_v1.sql','utf8');
const boot=fs.readFileSync('app/public/admin-marketing-v2.js','utf8');
const ui=fs.readFileSync('app/public/admin-marketing-web-bookings.js','utf8');
const gateway=fs.readFileSync('app/marketing-read-gateway.js','utf8');

test('landing booking lineage is additive and preserves canonical agenda authority',()=>{
  assert.match(migration,/create table if not exists public\.aos_landing_registry/);
  assert.match(migration,/create table if not exists public\.aos_landing_booking_attribution/);
  assert.match(migration,/create or replace function public\.aos_agendar_publica_landing_v1/);
  assert.match(migration,/public\.aos_agendar_publica_v2\(/);
  assert.match(migration,/source_channel='LANDING'/);
  assert.doesNotMatch(migration,/insert into public\.aos_leads/i);
  assert.doesNotMatch(migration,/delete from public\.aos_agenda_citas/i);
});

test('lineage ledger is append-only and idempotent',()=>{
  assert.match(migration,/WEB_BOOKING_ATTRIBUTION_APPEND_ONLY/);
  assert.match(migration,/before update or delete on public\.aos_landing_booking_attribution/);
  assert.match(migration,/aos_landing_booking_idempotency_uq/);
  assert.match(migration,/pg_advisory_xact_lock/);
  assert.match(migration,/idempotent_replay/);
});

test('web booking read model is admin-only and follows booking through calls and sales',()=>{
  assert.match(migration,/aos_marketing_web_bookings_admin_v1/);
  assert.match(migration,/aos_app_actor_v3\(p_token,'admin-marketing',true\)/);
  assert.match(migration,/public\.aos_llamadas/);
  assert.match(migration,/public\.aos_ventas/);
  assert.match(migration,/estado_comercial/);
  assert.match(migration,/facturacion/);
  assert.match(migration,/spend_available/);
});

test('Marketing gateway allowlists the web booking read model',()=>{
  assert.match(gateway,/aos_marketing_web_bookings_admin_v1:\{keys:\['p_desde','p_hasta','p_filters'\],ttl:15000,token:true\}/);
});

test('Citas Web UI is same-origin, admin-session based, exportable and non-polling',()=>{
  assert.match(boot,/admin-marketing-web-bookings\.js/);
  assert.match(ui,/name:'aos_marketing_web_bookings_admin_v1'/);
  assert.match(ui,/X-AOS-App-Token/);
  assert.match(ui,/\/api\/marketing\/rpc/);
  assert.match(ui,/Citas Web/);
  assert.match(ui,/Exportar CSV/);
  assert.doesNotMatch(ui,/SUPABASE_ANON_KEY|Authorization':'Bearer/);
  assert.doesNotMatch(ui,/setInterval\s*\(/);
});
