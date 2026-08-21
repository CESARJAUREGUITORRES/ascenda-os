const fs=require('fs');
const path='app/public/phase2-service-worker.js';
const appPath='app/public/app.html';
let s=fs.readFileSync(path,'utf8'),original=s;
s=s.replace('// ASCENDA OS Phase 2/F4/F9/WA-S14/S15.1/REV-F6.0 — controlled-write + revenue + Sentinel + actor-bound notification/patient-history bridge.','// ASCENDA OS Phase 2/F4/F9/WA-S14/S15.1/REV-F6.1 — controlled-write + revenue + Sentinel + canonical Patient Commercial 360 bridge.');

if(!s.includes('/patients-f6-v2.js')){
  const marker="  if(tags){html=html.indexOf('</body>')>=0?html.replace('</body>',tags+'</body>'):html+tags;}";
  const pos=s.indexOf(marker);
  if(pos<0)throw new Error('injectF4 terminal marker not found');
  const add="  if(html.indexOf('/patients-f6-v2.js')<0){\n    tags+='<script src=\"/patients-f6-v2.js?v=20260820-rev-f6-runtime-hotfix-v1\"></script>';\n  }\n";
  s=s.slice(0,pos)+add+s.slice(pos);
}

if(!s.includes("rpcFrom(req,'aos_patient_commercial_360_v2'")){
  const start=s.indexOf('  // REV-F6.0: keep the legacy Citas UI contract');
  const end=s.indexOf('  if(rm&&IDENTITY[rm[1]]){',start);
  if(start<0||end<0||end<=start)throw new Error('patient-history semantic block markers not found');
  const neu="  // REV-F6.1: browser callers never execute the legacy SECURITY DEFINER Patient 360 RPC.\n  // Compatibility phone inputs resolve through Identity Bridge V2 to canonical_patient_id.\n  if(rm&&rm[1]==='aos_paciente_360'){\n    event.respondWith((async function(){\n      var p=await requestJson(req),t=String(await getToken()).trim();\n      if(t.length<32)return json({ok:false,error:'PATIENT_360_APP_SESSION_REQUIRED'},401);\n      return rpcFrom(req,'aos_patient_commercial_360_v2',{p_token:t,p_lookup_type:'PHONE',p_lookup_value:p.p_numero||''});\n    })());return;\n  }\n  if(rm&&(rm[1]==='aos_patient_search_v2'||rm[1]==='aos_patient_commercial_360_v2')){\n    event.respondWith((async function(){\n      var p=await requestJson(req),t=String(await getToken()).trim();\n      if(t.length<32)return json({ok:false,error:'PATIENT_360_APP_SESSION_REQUIRED'},401);\n      p.p_token=t;\n      return rpcFrom(req,rm[1],p);\n    })());return;\n  }\n";
  s=s.slice(0,start)+neu+s.slice(end);
}

if(s!==original){fs.writeFileSync(path,s,'utf8');console.log('REV-F6.1 service worker patched');}else console.log('REV-F6.1 service worker already patched');

// Runtime-hardening: F4 revenue + Patient V2 are critical shell bridges. They must
// not depend exclusively on service-worker HTML rewriting. Load them directly from
// app.html as well; each bridge is idempotent and the service worker detects these
// tags and will not duplicate them.
let app=fs.readFileSync(appPath,'utf8'),appOriginal=app;
const marker='<!-- ASCENDA_CRITICAL_RUNTIME_BRIDGES_20260820 -->';
if(!app.includes(marker)){
  const tags='\n'+marker+'\n'+
    '<script src="/f4-revenue-ops.js?v=20260820-rev-runtime-hotfix-v1"></script>\n'+
    '<script src="/f4-kronia-revenue-bridge.js?v=20260820-rev-runtime-hotfix-v1"></script>\n'+
    '<script src="/f4-production-canary-hotfix.js?v=20260820-rev-runtime-hotfix-v1"></script>\n'+
    '<script src="/patients-f6-v2.js?v=20260820-rev-f6-runtime-hotfix-v1"></script>\n';
  const pos=app.lastIndexOf('</body>');
  if(pos<0)throw new Error('app.html closing body marker not found');
  app=app.slice(0,pos)+tags+app.slice(pos);
}
if(app!==appOriginal){fs.writeFileSync(appPath,app,'utf8');console.log('REV runtime critical bridges injected directly into app shell');}else console.log('REV runtime app shell already patched');
