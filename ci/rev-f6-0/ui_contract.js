'use strict';
const fs=require('fs');
const sw=fs.readFileSync('app/public/phase2-service-worker.js','utf8');
const citas=fs.readFileSync('app/public/citas.html','utf8');

// REV-F6.0 invariant is the security boundary, not one frozen successor RPC name.
// The legacy browser call may be routed to the F6.0 minimum summary or to the
// stricter F6.1 canonical Patient Commercial 360 successor, but it must remain
// app-token bound and fail closed with no direct legacy fallback.
const common=[
  "rm[1]==='aos_paciente_360'",
  'await getToken()',
  'p_token:t'
];
for(const marker of common){if(!sw.includes(marker))throw new Error('missing F6 patient security marker: '+marker);}

const hasF60=sw.includes('aos_patient_history_summary_v1')&&
  sw.includes('PATIENT_HISTORY_APP_SESSION_REQUIRED')&&
  sw.includes("p_numero:p.p_numero||''");
const hasF61=sw.includes('aos_patient_commercial_360_v2')&&
  sw.includes('PATIENT_360_APP_SESSION_REQUIRED')&&
  sw.includes("p_lookup_type:'PHONE'")&&
  sw.includes("p_lookup_value:p.p_numero||''");
if(!hasF60&&!hasF61)throw new Error('legacy Patient 360 is not routed to an approved governed successor');

const legacyCall="_rpc('aos_paciente_360'";
if(citas.split(legacyCall).length-1!==1)throw new Error('unexpected Citas Patient 360 call count');
const after=sw.split("if(rm&&rm[1]==='aos_paciente_360')")[1]||'';
const block=after.split('if(rm&&IDENTITY[rm[1]])')[0]||'';
if(block.includes('fetch(req)')||block.includes('isMissing'))throw new Error('Patient history cutover must fail closed; legacy fallback detected');
if(block.includes("rpcFrom(req,'aos_paciente_360'"))throw new Error('direct legacy Patient 360 execution detected');
console.log('REV-F6.0 UI/consumer security boundary PASS');
