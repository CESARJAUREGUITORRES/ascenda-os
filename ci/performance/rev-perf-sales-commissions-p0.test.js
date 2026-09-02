const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');

const migration=fs.readFileSync('supabase/migrations/20260902181000_rev_perf_sales_commissions_p0_v1.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260902181000_rev_perf_sales_commissions_p0_v1_rollback.sql','utf8');

function fnBody(sql,name){
  const marker=`function public.${name}`;
  const i=sql.toLowerCase().indexOf(marker.toLowerCase());
  assert.notEqual(i,-1,`${name} must exist`);
  const next=sql.toLowerCase().indexOf('create or replace function public.',i+marker.length);
  return sql.slice(i,next===-1?sql.length:next);
}

test('REV-PERF P0 replaces only intended read contracts',()=>{
  assert.match(migration,/aos_comisiones_asesor/i);
  assert.match(migration,/aos_ventas_admin\(/i);
  assert.match(migration,/aos_ventas_admin_anio/i);
  assert.doesNotMatch(migration,/create\s+or\s+replace\s+function\s+public\.aos_comisiones_admin\b/i);
  assert.doesNotMatch(migration,/insert\s+into\s+public\.aos_ventas/i);
  assert.doesNotMatch(migration,/update\s+public\.aos_ventas/i);
  assert.doesNotMatch(migration,/delete\s+from\s+public\.aos_ventas/i);
});

test('Sales monthly hot path uses scoped materialized bases',()=>{
  const body=fnBody(migration,'aos_ventas_admin');
  for(const token of ['period_all as materialized','base as materialized','advisor_base as materialized','year_base as materialized','agg as']){
    assert.ok(body.toLowerCase().includes(token),`missing ${token}`);
  }
  assert.match(body,/fecha\s+between\s+v_desde\s+and\s+v_hasta/i);
  assert.match(body,/Legacy filter semantics intentionally preserved/i);
});

test('Sales annual hot path reuses one annual base',()=>{
  const body=fnBody(migration,'aos_ventas_admin_anio');
  assert.match(body,/period_all as materialized/i);
  assert.match(body,/base as materialized/i);
  assert.match(body,/advisor_base as materialized/i);
});

test('Commission hot path derives month from one advisor-year base and preserves empty-month nulls',()=>{
  const body=fnBody(migration,'aos_comisiones_asesor');
  assert.match(body,/year_sales as materialized/i);
  assert.match(body,/month_sales as materialized/i);
  assert.match(body,/ranking_sales as materialized/i);
  assert.match(body,/'comServ',\(select sum\(calc_com\)/i);
  assert.match(body,/'comProd',\(select sum\(calc_com\)/i);
  assert.match(body,/'rankingTop'/i);
});

test('Commission rules remain canonical and no timeout is raised',()=>{
  assert.match(migration,/aos_tabla_comisiones/i);
  assert.match(migration,/monto_min<=/i);
  assert.match(migration,/0\.005/);
  const executable=migration.replace(/--.*$/gm,'');
  assert.doesNotMatch(executable,/statement_timeout/i);
  assert.doesNotMatch(executable,/set\s+local\s+.*timeout/i);
});

test('Rollback restores all three replaced functions',()=>{
  for(const name of ['aos_comisiones_asesor','aos_ventas_admin','aos_ventas_admin_anio']){
    assert.ok(rollback.toLowerCase().includes(`function public.${name}`),`rollback missing ${name}`);
  }
  assert.doesNotMatch(rollback,/rankingTop/i);
});
