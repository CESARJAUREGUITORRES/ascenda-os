'use strict'
const fs=require('fs')
function read(p){return fs.readFileSync(p,'utf8')}
function ok(v,m){if(!v){console.error('CC72 WORKSPACE V2 FAIL:',m);process.exit(1)}}

const sql=read('supabase/migrations/20260921193000_cc_rolling_72h_workspace_io_v2.sql')
const calls=read('app/public/calls-loop6.js')
const callsHtml=read('app/public/calls.html')
const workspace=read('app/public/cia-audience-workspace-v3.js')
const shell=read('app/public/clinic-shell-ui-v1.js')

ok(sql.includes('v_owner_last_activity timestamptz'),'latest owner activity timestamp missing')
ok(sql.includes('select max(x.ts)'),'rolling owner activity aggregation missing')
ok(sql.includes("v_protected_until:=greatest(v_no_show_slot,coalesce(v_owner_last_activity,v_no_show_slot))+interval '72 hours'"),'rolling 72h lease calculation missing')
ok(sql.includes("v_owner_followup:=v_owner_last_activity is not null and v_event<v_protected_until"),'expired owner activity must not protect indefinitely')
ok(sql.includes("'ownerLastActivityAt',v_owner_last_activity")&&sql.includes("'ownershipRule','ROLLING_72H'"),'rolling lease evidence missing')
ok(calls.includes("cc6Toast('♻️ Recuperación disponible'"),'released no-show should not show blocking ownership modal')
ok(calls.includes('Última gestión del propietario'),'active owner lease explanation missing')
ok(callsHtml.includes('/calls-loop6.js?v=20260921-rolling72-v1'),'Call Center cache-bust missing')

ok(sql.includes('aos_cia_workspace_catalog_members_v1'),'catalog member fast-path missing')
ok(sql.includes('aos_cia_workspace_preview_app_v2'),'preview dedicated RPC missing')
ok(sql.includes('aos_cia_workspace_export_app_v2'),'CSV dedicated RPC missing')
ok(sql.includes('aos_cia_distribution_preview_app_v2'),'distribution dedicated RPC missing')
ok(workspace.includes("endpoint='aos_cia_workspace_preview_app_v2'"),'UI preview not routed to dedicated RPC')
ok(workspace.includes("endpoint='aos_cia_workspace_export_app_v2'"),'UI export not routed to dedicated RPC')
ok(workspace.includes("endpoint='aos_cia_distribution_preview_app_v2'"),'UI planner not routed to dedicated RPC')
ok(workspace.includes("preset_key:s.preset_key||null"),'catalog preset key not sent by UI')
ok(workspace.includes("toast('Audiencia lista para distribución')"),'use-in-distribution feedback missing')
ok(shell.includes('/cia-audience-workspace-v3.js?v=20260921-1'),'Workspace cache-bust missing')
ok(!sql.includes('START_DISTRIBUTION'),'bulk distribution must remain disabled')
ok(!sql.includes("SET_GLOBAL"),'fast catalog/planner patch must not alter Call Center routing')

console.log('Rolling 72h ownership + Workspace catalog IO V2 contract: PASS')
