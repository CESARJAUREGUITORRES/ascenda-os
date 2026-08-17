'use strict';
const base='https://ascenda-os-production.up.railway.app';
const ok=(v,m)=>{if(!v)throw new Error(m)};
async function text(path,opts){const r=await fetch(base+path,Object.assign({cache:'no-store'},opts||{}));return {r,body:await r.text()};}
(async()=>{
  let x=await text('/health?probe=wa-s9-20260817');
  ok(x.r.ok,'health '+x.r.status);
  ok(x.body.includes('ascenda-phase-s'),'Phase S marker missing');

  x=await text('/app?probe=wa-s9-20260817');
  ok(x.r.ok,'app '+x.r.status);
  ok((x.r.headers.get('x-ascenda-phase-s-shell')||'')==='native-wa-anchor-v1','shell marker missing');
  ok(x.body.includes('/wa-native-panel.js'),'native panel anchor missing');
  ok(x.body.includes('/wa-shell-integration.js'),'shell integration anchor missing');

  x=await text('/wa-shell-integration.js?probe=wa-s9-20260817');
  ok(x.r.ok,'shell js '+x.r.status);
  ok(x.body.includes('/wa-native-panel.js?v=20260817-wa-native-s9-p01'),'S9 native cache-buster missing');
  ok(x.body.includes('/wa-native-layout-s9.js?v=20260817-wa-layout-s9-p01'),'S9 layout loader missing');
  ok(x.body.includes('ensureLayout'),'S9 layout readiness missing');
  ok(!x.body.includes('WA_IFRAME_URL'),'old iframe runtime still live');
  ok(!x.body.includes('<iframe'),'iframe markup still live');
  ok(!x.body.includes('installRecovery'),'old recovery still live');

  x=await text('/wa-native-layout-s9.js?probe=wa-s9-20260817');
  ok(x.r.ok,'layout '+x.r.status);
  ok(x.body.includes("display:flex!important"),'deterministic flex layout missing');
  ok(x.body.includes('getBoundingClientRect'),'geometry measurement missing');
  ok(x.body.includes('self-heal'),'self-heal marker missing');
  ok(x.body.includes('AOS_WA_LAYOUT_DIAG'),'layout diagnostics missing');
  ok(x.body.includes("wa9-left-closed")&&x.body.includes("wa9-right-closed"),'S9 side controls missing');

  x=await text('/phase2-service-worker.js?probe=wa-s9-20260817');
  ok(x.r.ok,'service worker '+x.r.status);
  ok(x.body.includes('/wa-native-layout-s9.js?v=20260817-wa-layout-s9-p01'),'PWA S9 layout injection missing');
  ok(x.body.includes('WA-S9'),'PWA S9 version marker missing');

  x=await text('/wa-native-panel.js?probe=wa-s9-20260817');
  ok(x.r.ok,'native panel '+x.r.status);
  ok(x.body.includes("h.set('X-AOS-App-Token',t)"),'strong token header missing');
  ok(x.body.includes("api('/api/wa3/inbox?limit=120')"),'inbox path missing');
  ok(x.body.includes("'/messages?limit=250'"),'timeline path missing');
  ok(x.body.includes("'/send'"),'send path missing');
  ok(x.body.includes('human_send_enabled')&&x.body.includes('owner_user_id'),'composer governance missing');
  ok(x.body.includes('wa8-left-toggle')&&x.body.includes('wa8-right-toggle'),'collapsible controls missing');

  x=await text('/api/wa3/bootstrap?probe=wa-s9-20260817');
  ok(x.r.status===403,'anonymous WA3 must remain closed: '+x.r.status);
  ok(x.body.includes('WA3_2FA_PANEL_REQUIRED'),'anonymous gate changed');
  console.log('WA_S9_NATIVE_LAYOUT_LIVE=PASS');
})().catch(e=>{console.error(e);process.exit(1)});
