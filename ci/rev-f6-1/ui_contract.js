const fs=require('fs');
const sw=fs.readFileSync('app/public/phase2-service-worker.js','utf8');
const app=fs.readFileSync('app/public/app.html','utf8');
const ui=fs.readFileSync('app/public/patients-f6-v2.js','utf8');
function ok(cond,msg){if(!cond){console.error('F6.1 UI CONTRACT FAIL:',msg);process.exit(1);}}

// Runtime availability remains deterministic through the existing critical bridge slot.
ok(sw.includes('/patients-f6-v2.js'),'Service worker must preserve Patient 360 runtime compatibility injection');
ok(app.includes('ASCENDA_CRITICAL_RUNTIME_BRIDGES_20260820'),'App shell must contain deterministic critical-runtime marker');
ok(app.includes('/patients-f6-v2.js?v=20260820-rev-f6-runtime-hotfix-v1'),'Patient runtime must load directly from app shell');

// Rebuild semantics: search resolves current canonical identity once; selection never re-resolves it.
ok(ui.includes('window.__AOS_PATIENTS_360_V3__'),'Rebuilt Patient 360 runtime must publish a V3 idempotency marker');
ok(ui.includes("window.__AOS_PATIENTS_360_V3__='waiting'"),'V3 runtime must wait until base patients.js exists');
ok(ui.includes("window.__AOS_PATIENTS_360_V3__='installed'"),'V3 runtime must publish installed state');
ok(ui.includes('schedule();return;'),'V3 runtime must support long-lived sessions without expiry');
ok(ui.includes("'aos_patient_search_v2'"),'Search must keep governed canonical patient discovery');
ok(ui.includes('p_token:token()'),'Patient requests may carry the browser token, but worker authority must overwrite it');
ok(ui.includes('onclick="ptSelCurrent'),'Search cards must open the returned canonical patient directly');
ok(ui.includes("'aos_patient_360_current_v3'"),'Selection must call the rebuilt canonical-current Patient 360 RPC');
ok(ui.includes('p_canonical_patient_id:cid'),'Selection must pass canonical_patient_id directly');
ok(!ui.includes("'aos_patient_commercial_360_v2'"),'Current selection must not use the failed V2 re-resolution chain');
ok(!ui.includes("addAttempt('PHONE'"),'Current canonical selection must not fall back through phone resolution');
ok(!ui.includes("addAttempt('DOCUMENT'"),'Current canonical selection must not fall back through document resolution');

// Browser-path authentication: every governed patient read must use the canonical service-worker token.
ok(sw.includes("rm[1]==='aos_patient_search_v2'||rm[1]==='aos_patient_commercial_360_v2'||rm[1]==='aos_patient_360_current_v3'"),'Patient 360 Current V3 must share the governed worker token bridge');
ok(sw.includes('p.p_token=t'),'Governed patient bridge must overwrite browser p_token with the canonical worker token');
ok(sw.includes('browser/sessionStorage'),'Worker contract must explicitly reject browser/sessionStorage as token authority');

// P0 #436: long-lived/PWA clients must self-heal a stale pre-#323 controller without polling.
ok(ui.includes("window.__AOS_PATIENT_BRIDGE_GUARD__='p0436-v1'"),'Patient runtime must publish the P0 #436 bridge-guard version');
ok(ui.includes("navigator.serviceWorker.getRegistration('/')"),'Patient runtime must inspect the active root service-worker registration');
ok(ui.includes("navigator.serviceWorker.register('/phase2-service-worker.js',{scope:'/',updateViaCache:'none'})"),'Missing patient bridge must register the canonical Phase-2 worker without HTTP cache reuse');
ok(ui.includes('reg.update()'),'Patient runtime must force one bounded service-worker update check');
ok(ui.includes("postMessage({type:'ASCENDA_ACTIVATE_NOW'})"),'Waiting canonical worker must be explicitly activated');
ok(ui.includes("addEventListener('controllerchange'"),'Patient runtime must wait for controller takeover before governed V3 selection');
ok(ui.includes('bridgeReadyPromise'),'Patient bridge readiness must be single-flight per runtime');
ok(ui.includes('4500'),'Bridge activation wait must be bounded');
ok(!ui.includes('setInterval('),'Patient bridge recovery must not poll');
ok(!ui.includes("if(t.length<32)"),'Browser/sessionStorage token length must not gate a worker-authoritative patient read');
ok(ui.includes("status==='CANONICAL_TARGET_MISSING'"),'True missing canonical rows must be distinguished from bridge/session failures');
ok(ui.includes('loadCurrent(cid,true)'),'Canonical selection must permit one controlled bridge repair/retry');

// F5/F6 enrich current truth; historical review remains visible but non-blocking.
ok(ui.includes('ACTUAL RESOLVED'),'UI must distinguish resolved current patient identity');
ok(ui.includes('HISTÓRICO REVIEW'),'UI must distinguish historical linkage review from current identity');
ok(ui.includes('el histórico pendiente no bloquea esta ficha'),'UI must state that historical review does not gate current visibility');
ok(ui.includes('NO_CERTIFIED_SOURCE'),'Historical transaction coverage warning must remain explicit');

// Legacy phone buttons may resolve once through governed search, but never auto-merge.
ok(ui.includes('Compatibility for old buttons'),'Legacy UI compatibility must be explicit');
ok(ui.includes('Selecciona la ficha por nombre'),'Shared phone compatibility must fail closed instead of auto-merging');

console.log('REV-F6.1 UI contract PASS — canonical Patient 360 + self-healing governed worker bridge');
