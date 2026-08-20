const fs=require('fs');
const path='app/public/phase2-service-worker.js';
let s=fs.readFileSync(path,'utf8'),original=s;
s=s.replace('// ASCENDA OS Phase 2/F4/F9/WA-S14/S15.1/REV-F6.0 — controlled-write + revenue + Sentinel + actor-bound notification/patient-history bridge.','// ASCENDA OS Phase 2/F4/F9/WA-S14/S15.1/REV-F6.1 — controlled-write + revenue + Sentinel + canonical Patient Commercial 360 bridge.');
const needle=`  if(html.indexOf('/sentinel-inapp-notifications.js')<0){\n    tags+='<script src="/sentinel-inapp-notifications.js?v=20260816-f9-inapp-v1"></script>';\n  }\n`;
if(!s.includes('/patients-f6-v2.js')){
  if(!s.includes(needle))throw new Error('inject marker not found');
  s=s.replace(needle,needle+`  if(html.indexOf('/patients-f6-v2.js')<0){\n    tags+='<script src="/patients-f6-v2.js?v=20260819-rev-f6-1-v1"></script>';\n  }\n`);
}
const old=`  // REV-F6.0: keep the legacy Citas UI contract, but never let browser roles execute\n  // the legacy SECURITY DEFINER Patient 360 RPC. Bind the read to Auth V3 + 2FA and\n  // return only the minimum commercial history consumed by the Citas panel.\n  if(rm&&rm[1]==='aos_paciente_360'){\n    event.respondWith((async function(){\n      var p=await requestJson(req),t=String(await getToken()).trim();\n      if(t.length<32)return json({ok:false,error:'PATIENT_HISTORY_APP_SESSION_REQUIRED'},401);\n      return rpcFrom(req,'aos_patient_history_summary_v1',{p_token:t,p_numero:p.p_numero||''});\n    })());return;\n  }\n`;
const neu=`  // REV-F6.1: browser callers never execute the legacy SECURITY DEFINER Patient 360 RPC.\n  // Compatibility phone inputs resolve through Identity Bridge V2 to canonical_patient_id.\n  if(rm&&rm[1]==='aos_paciente_360'){\n    event.respondWith((async function(){\n      var p=await requestJson(req),t=String(await getToken()).trim();\n      if(t.length<32)return json({ok:false,error:'PATIENT_360_APP_SESSION_REQUIRED'},401);\n      return rpcFrom(req,'aos_patient_commercial_360_v2',{p_token:t,p_lookup_type:'PHONE',p_lookup_value:p.p_numero||''});\n    })());return;\n  }\n  if(rm&&(rm[1]==='aos_patient_search_v2'||rm[1]==='aos_patient_commercial_360_v2')){\n    event.respondWith((async function(){\n      var p=await requestJson(req),t=String(await getToken()).trim();\n      if(t.length<32)return json({ok:false,error:'PATIENT_360_APP_SESSION_REQUIRED'},401);\n      p.p_token=t;\n      return rpcFrom(req,rm[1],p);\n    })());return;\n  }\n`;
if(!s.includes("rpcFrom(req,'aos_patient_commercial_360_v2'")){
  if(!s.includes(old))throw new Error('patient-history bridge marker not found');
  s=s.replace(old,neu);
}
if(s!==original){fs.writeFileSync(path,s,'utf8');console.log('REV-F6.1 service worker patched');}else console.log('REV-F6.1 service worker already patched');
