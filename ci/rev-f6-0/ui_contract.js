'use strict';
const fs=require('fs');
const sw=fs.readFileSync('app/public/phase2-service-worker.js','utf8');
const citas=fs.readFileSync('app/public/citas.html','utf8');
const required=[
  "rm[1]==='aos_paciente_360'",
  'aos_patient_history_summary_v1',
  'await getToken()',
  'PATIENT_HISTORY_APP_SESSION_REQUIRED',
  'p_token:t',
  "p_numero:p.p_numero||''"
];
for(const marker of required){if(!sw.includes(marker))throw new Error('missing service-worker marker: '+marker);}
const legacyCall="_rpc('aos_paciente_360'";
if(citas.split(legacyCall).length-1!==1)throw new Error('unexpected Citas Patient 360 call count');
const after=sw.split("if(rm&&rm[1]==='aos_paciente_360')")[1]||'';
const block=after.split('if(rm&&IDENTITY[rm[1]])')[0]||'';
if(block.includes('fetch(req)')||block.includes('isMissing'))throw new Error('Patient history cutover must fail closed; legacy fallback detected');
console.log('REV-F6.0 UI/consumer contract PASS');
