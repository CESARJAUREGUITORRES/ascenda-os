'use strict';
const base='https://ascenda-os-production.up.railway.app';
const ok=(v,m)=>{if(!v)throw new Error(m)};
async function text(path,opts){const r=await fetch(base+path,Object.assign({cache:'no-store'},opts||{}));return {r,body:await r.text()};}
(async()=>{
  let x=await text('/health?probe=wa-s11-20260817');
  ok(x.r.ok,'health '+x.r.status);
  ok(x.body.includes('ascenda-phase-s'),'Phase S marker missing');
  x=await text('/app?probe=wa-s11-20260817');
  ok(x.r.ok,'app '+x.r.status);
  ok((x.r.headers.get('x-ascenda-phase-s-shell')||'')==='native-wa-anchor-v1','shell marker missing');
  ok(x.body.includes('/wa-native-panel.js?v=20260817-wa-native-s11-p01'),'S11 native panel anchor missing');
  ok(x.body.includes('/wa-shell-integration.js?v=20260817-wa-shell-s11-p01'),'S11 shell anchor missing');
  x=await text('/wa-native-panel.js?probe=wa-s11-20260817');
  ok(x.r.ok,'native '+x.r.status);
  ok(x.body.includes('function heartbeat(force)'),'S11 heartbeat missing');
  ok(x.body.includes('visibilitychange'),'visibility recovery missing');
  ok(x.body.includes("api('/api/wa3/provider-health')"),'provider health UI missing');
  ok(x.body.includes('1500'),'S11 polling cadence missing');
  x=await text('/api/wa3/provider-health?probe=wa-s11-20260817');
  ok(x.r.status===403,'anonymous provider health must be 403, got '+x.r.status);
  ok(x.body.includes('WA3_2FA_PANEL_REQUIRED'),'provider health auth gate changed');
  x=await text('/api/wa3/bootstrap?probe=wa-s11-20260817');
  ok(x.r.status===403,'anonymous bootstrap must remain 403, got '+x.r.status);
  console.log('WA_S11_LIVE=PASS');
})().catch(e=>{console.error(e);process.exit(1)});
