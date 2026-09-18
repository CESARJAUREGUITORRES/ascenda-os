'use strict'
const fs=require('fs')
function read(p){return fs.readFileSync(p,'utf8')}
function ok(v,m){if(!v){console.error('CIA DISTRIBUTION PLANNER V1 FAIL:',m);process.exit(1)}}
const ui=read('app/public/cia-audience-workspace-v3.js')
const sql=read('supabase/migrations/20260918022500_cia_distribution_planner_v1.sql')

ok(ui.includes('/rpc/aos_cia_control_center_app_v5'),'UI must use additive V5 reliability gateway')
ok(ui.includes("'DISTRIBUTION_RELEASE_STATE'"),'release state read missing')
ok(ui.includes("'DISTRIBUTION_PREVIEW'"),'distribution preview missing')
ok(ui.includes('Simular distribución'),'planner CTA missing')
ok(ui.includes('Ejecución masiva bloqueada'),'rollout lock copy missing')
ok(ui.includes('Activar distribución')&&ui.includes('disabled'),'bulk activation must remain disabled')
ok(!ui.includes("rpc('START_DISTRIBUTION'"),'bulk distribution execution must not exist before canary PASS')
ok(ui.includes("rpc('START_CANARY_ASSIGNMENT'")&&ui.includes('source_limit:1'),'one-contact gate must remain intact')
ok(!ui.includes('setInterval('),'planner must not poll')

ok(sql.includes('aos_cia_distribution_release_state_v1'),'distribution release control missing')
ok(sql.includes("'CALL','HUMAN_CANARY_REQUIRED',false,1,1"),'CALL release must remain fail-closed')
ok(sql.includes('aos_cia_control_center_app_v4'),'V4 gateway missing')
ok(sql.includes("v_action not in ('DISTRIBUTION_RELEASE_STATE','DISTRIBUTION_PREVIEW')"),'V4 must delegate all other actions to V3')
ok(sql.includes("coalesce(u.paneles_acceso,'{}'::text[]) @> array['advisor-calls']::text[]"),'planner targets must require Call Center permission')
ok(sql.includes('aos_cia_audience_validate_v1')&&sql.includes('aos_cia_audience_count_v2'),'planner must use governed audience resolver')
ok(!sql.includes('START_DISTRIBUTION'),'bulk execution action forbidden before canary PASS')
ok(!sql.includes('SET_GLOBAL'),'planner must never mutate routing')
ok(!sql.includes('aos_cia_assignment_plan_create_admin_v1'),'planner must not create plans')

console.log('CIA Distribution Planner V1 contract: PASS')
