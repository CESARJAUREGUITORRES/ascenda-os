'use strict';
const fs=require('fs');
const assert=require('assert');

const migration=fs.readFileSync('supabase/migrations/20260904004500_p0_457_panel_admin_indexable_v1.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260904004500_p0_457_panel_admin_indexable_v1.rollback.sql','utf8');

assert(/create or replace function public\.aos_panel_admin\(p_hoy text, p_ayer text, p_mes_inicio text\)/i.test(migration));
assert(/returns json/i.test(migration));
assert(/America\/Lima/i.test(migration));
assert(!/fecha::text/i.test(migration),'panel admin migration must not cast indexed date columns to text');
assert(!/fecha_cita::text/i.test(migration),'agenda date predicate must stay native date');
assert(/where fecha in \(v_hoy, v_ayer\)/i.test(migration));
assert(/where fecha >= v_mes_inicio/i.test(migration));
assert(/where fecha_cita = v_hoy/i.test(migration));
assert(/where l\.fecha = v_hoy/i.test(migration));
assert(/where l2\.id_asesor = l\.id_asesor[\s\S]*l2\.fecha = v_hoy/i.test(migration));
assert(!/create\s+index|create\s+materialized\s+view|refresh\s+materialized\s+view|create\s+trigger/i.test(migration));
assert(!/(?:set|alter[^;]*)\s+statement_timeout/i.test(migration));
assert(!/(insert\s+into|update|delete\s+from)\s+public\.(aos_ventas|aos_llamadas|aos_agenda_citas|aos_leads)/i.test(migration));
for(const key of ['businessDate','businessTimezone','factHoy','factHoySI','factHoyPL','nVentasHoy','deltaVentasHoy','llamHoy','llamMes','citasHoy','citasAgHoy','leadsMes','alertas','ventasHoy','semaforo','tipif','fromSupabase']){
  assert(migration.includes(`'${key}'`),`payload key missing: ${key}`);
}
assert(/fecha::text/i.test(rollback),'rollback must restore prior implementation');
console.log('P0_457_PANEL_ADMIN_INDEXABLE_CONTRACT=PASS');
