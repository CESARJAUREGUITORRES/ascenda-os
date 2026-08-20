from pathlib import Path

p=Path('app/public/phase2-service-worker.js')
s=p.read_text(encoding='utf-8')
original=s

s=s.replace(
"// ASCENDA OS Phase 2/F4/F9/WA-S14/S15.1/REV-F6.0 — controlled-write + revenue + Sentinel + actor-bound notification/patient-history bridge.",
"// ASCENDA OS Phase 2/F4/F9/WA-S14/S15.1/REV-F6.1 — controlled-write + revenue + Sentinel + canonical Patient Commercial 360 bridge."
)

needle="""  if(html.indexOf('/sentinel-inapp-notifications.js')<0){\n    tags+='<script src=\"/sentinel-inapp-notifications.js?v=20260816-f9-inapp-v1\"></script>';\n  }\n"""
repl=needle+"""  if(html.indexOf('/patients-f6-v2.js')<0){\n    tags+='<script src=\"/patients-f6-v2.js?v=20260819-rev-f6-1-v1\"></script>';\n  }\n"""
if '/patients-f6-v2.js' not in s:
    if needle not in s: raise SystemExit('inject marker not found')
    s=s.replace(needle,repl,1)

old="""  // REV-F6.0: keep the legacy Citas UI contract, but never let browser roles execute\n  // the legacy SECURITY DEFINER Patient 360 RPC. Bind the read to Auth V3 + 2FA and\n  // return only the minimum commercial history consumed by the Citas panel.\n  if(rm&&rm[1]==='aos_paciente_360'){\n    event.respondWith((async function(){\n      var p=await requestJson(req),t=String(await getToken()).trim();\n      if(t.length<32)return json({ok:false,error:'PATIENT_HISTORY_APP_SESSION_REQUIRED'},401);\n      return rpcFrom(req,'aos_patient_history_summary_v1',{p_token:t,p_numero:p.p_numero||''});\n    })());return;\n  }\n"""
new="""  // REV-F6.1: browser callers never execute the legacy SECURITY DEFINER Patient 360 RPC.\n  // Legacy phone lookups are compatibility inputs only; the server resolves them through\n  // Identity Bridge V2 to canonical_patient_id before any commercial history is returned.\n  if(rm&&rm[1]==='aos_paciente_360'){\n    event.respondWith((async function(){\n      var p=await requestJson(req),t=String(await getToken()).trim();\n      if(t.length<32)return json({ok:false,error:'PATIENT_360_APP_SESSION_REQUIRED'},401);\n      return rpcFrom(req,'aos_patient_commercial_360_v2',{p_token:t,p_lookup_type:'PHONE',p_lookup_value:p.p_numero||''});\n    })());return;\n  }\n  if(rm&&(rm[1]==='aos_patient_search_v2'||rm[1]==='aos_patient_commercial_360_v2')){\n    event.respondWith((async function(){\n      var p=await requestJson(req),t=String(await getToken()).trim();\n      if(t.length<32)return json({ok:false,error:'PATIENT_360_APP_SESSION_REQUIRED'},401);\n      p.p_token=t;\n      return rpcFrom(req,rm[1],p);\n    })());return;\n  }\n"""
if "rpcFrom(req,'aos_patient_commercial_360_v2'" not in s:
    if old not in s: raise SystemExit('patient-history bridge marker not found')
    s=s.replace(old,new,1)

if s==original:
    print('REV-F6.1 service worker already patched')
else:
    p.write_text(s,encoding='utf-8')
    print('REV-F6.1 service worker patched')
