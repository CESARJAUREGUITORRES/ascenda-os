const fs=require('fs');
const sw=fs.readFileSync('app/public/phase2-service-worker.js','utf8');
const ui=fs.readFileSync('app/public/patients-f6-v2.js','utf8');
function ok(cond,msg){if(!cond){console.error('F6.1 UI CONTRACT FAIL:',msg);process.exit(1);}}
ok(sw.includes('/patients-f6-v2.js'),'AppShell must inject Patient 360 V2 bridge');
ok(sw.includes("rpcFrom(req,'aos_patient_commercial_360_v2'"),'legacy Patient 360 must route to canonical V2');
ok(sw.includes("rm[1]==='aos_patient_search_v2'"),'search V2 must receive governed token injection');
ok(sw.includes("p.p_token=t"),'V2 browser RPCs must receive app token from controlled cache');
ok(!sw.includes("rpcFrom(req,'aos_patient_history_summary_v1',{p_token:t,p_numero:p.p_numero||''})"),'legacy Patient 360 must not route to F6.0 minimum summary');
ok(ui.includes("p_lookup_type:type"),'UI selection must support canonical lookup type');
ok(ui.includes("ptSelV2('CANONICAL_ID'"),'search results must select canonical_patient_id explicitly');
ok(ui.includes('IDENTITY_CONFLICT'),'shared-identifier conflicts must be visible');
ok(ui.includes('Timeline V2'),'existing panel must expose unified timeline');
ok(ui.includes('NO_CERTIFIED_SOURCE'),'historical coverage warning must be visible');
ok(ui.includes('Metric Trust'),'trust metadata must be visible');
console.log('REV-F6.1 UI contract PASS');
