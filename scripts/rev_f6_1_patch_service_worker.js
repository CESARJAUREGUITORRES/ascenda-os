const fs=require('fs');
const path='app/public/phase2-service-worker.js';
let s=fs.readFileSync(path,'utf8'),original=s;
s=s.replace('// ASCENDA OS Phase 2/F4/F9/WA-S14/S15.1/REV-F6.0 — controlled-write + revenue + Sentinel + actor-bound notification/patient-history bridge.','// ASCENDA OS Phase 2/F4/F9/WA-S14/S15.1/REV-F6.1 — controlled-write + revenue + Sentinel + canonical Patient Commercial 360 bridge.');

if(!s.includes('/patients-f6-v2.js')){
  const marker="  if(tags){html=html.indexOf('</body>')>=0?html.replace('</body>',tags+'</body>'):html+tags;}";
  const pos=s.indexOf(marker);
  if(pos<0)throw new Error('injectF4 terminal marker not found');
  const add="  if(html.indexOf('/patients-f6-v2.js')<0){\n    tags+='<script src=\"/patients-f6-v2.js?v=20260819-rev-f6-1-v1\"></script>';\n  }\n";
  s=s.slice(0,pos)+add+s.slice(pos);
}

if(!s.includes("rpcFrom(req,'aos_patient_commercial_360_v2'")){
  const start=s.indexOf('  // REV-F6.0: keep the legacy Citas UI contract');
  const end=s.indexOf('  if(rm&&IDENTITY[rm[1]]){',start);
  if(start<0||end<0||end<=start)throw new Error('patient-history semantic block markers not found');
  const neu="  // REV-F6.1: browser callers never execute the legacy SECURITY DEFINER Patient 360 RPC.\n  // Compatibility phone inputs resolve through Identity Bridge V2 to canonical_patient_id.\n  if(rm&&rm[1]==='aos_paciente_360'){\n    event.respondWith((async function(){\n      var p=await requestJson(req),t=String(await getToken()).trim();\n      if(t.length<32)return json({ok:false,error:'PATIENT_360_APP_SESSION_REQUIRED'},401);\n      return rpcFrom(req,'aos_patient_commercial_360_v2',{p_token:t,p_lookup_type:'PHONE',p_lookup_value:p.p_numero||''});\n    })());return;\n  }\n  if(rm&&(rm[1]==='aos_patient_search_v2'||rm[1]==='aos_patient_commercial_360_v2')){\n    event.respondWith((async function(){\n      var p=await requestJson(req),t=String(await getToken()).trim();\n      if(t.length<32)return json({ok:false,error:'PATIENT_360_APP_SESSION_REQUIRED'},401);\n      p.p_token=t;\n      return rpcFrom(req,rm[1],p);\n    })());return;\n  }\n";
  s=s.slice(0,start)+neu+s.slice(end);
}

// P0 #436: both the operational Patient 360 read and its serial deferred enrichment
// remain governed by the service-worker token. Never trust browser/sessionStorage authority.
if(!s.includes("rm[1]==='aos_patient_360_enrichment_v1'")){
  const old="rm[1]==='aos_patient_search_v2'||rm[1]==='aos_patient_commercial_360_v2'||rm[1]==='aos_patient_360_current_v3'";
  const neu=old+"||rm[1]==='aos_patient_360_enrichment_v1'";
  if(!s.includes(old))throw new Error('governed Patient RPC bridge marker not found');
  s=s.replace(old,neu);
}

if(s!==original){fs.writeFileSync(path,s,'utf8');console.log('REV-F6.1 service worker patched');}else console.log('REV-F6.1 service worker already patched');
