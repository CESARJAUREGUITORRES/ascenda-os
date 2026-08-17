'use strict';
const base='https://ascenda-os-production.up.railway.app';
const ok=(v,m)=>{if(!v)throw new Error(m)};
async function text(path,opts){const r=await fetch(base+path,Object.assign({cache:'no-store'},opts||{}));return {r,body:await r.text()};}
(async()=>{
  let x=await text('/health?probe=wa-s10-20260817');
  ok(x.r.ok,'health '+x.r.status);
  ok(x.body.includes('ascenda-phase-s'),'Phase S marker missing');

  x=await text('/app?probe=wa-s10-20260817');
  ok(x.r.ok,'app '+x.r.status);
  ok((x.r.headers.get('x-ascenda-phase-s-shell')||'')==='native-wa-anchor-v1','shell marker missing');
  ok(x.body.includes('wa-native-panel.js?v=20260817-wa-native-s10-p01'),'S10 panel anchor missing');
  ok(x.body.includes('wa-shell-integration.js?v=20260817-wa-shell-s10-p01'),'S10 shell anchor missing');

  x=await text('/wa-shell-integration.js?probe=wa-s10-20260817');
  ok(x.r.ok,'shell js '+x.r.status);
  ok(x.body.includes('/wa-native-panel.js?v=20260817-wa-native-s10-p01'),'S10 native cache-buster missing');
  ok(x.body.includes('/wa-native-layout-s9.js?v=20260817-wa-layout-s9-p01'),'S9 stable layout loader missing');
  ok(!x.body.includes('WA_IFRAME_URL'),'old iframe runtime still live');
  ok(!x.body.includes('installRecovery'),'old recovery still live');

  x=await text('/wa-native-panel.js?probe=wa-s10-20260817');
  ok(x.r.ok,'native panel '+x.r.status);
  ok(x.body.includes('Ventana de WhatsApp cerrada (>24 h)'),'S10 native 24h gate missing');
  ok(x.body.includes("24H '+(windowOpen?'ABIERTA':'CERRADA')"),'S10 window status chip missing');
  ok(x.body.includes("windowState=(Number.isFinite(li)&&Date.now()-li<86400000)?'OPEN':'CLOSED'"),'S10 dynamic window refresh missing');
  ok(x.body.includes('provider_details'),'S10 Meta details UI missing');
  ok(x.body.includes("h.set('X-AOS-App-Token',t)"),'strong token header missing');
  ok(x.body.includes("'/send'"),'send path missing');
  ok(x.body.includes('human_send_enabled')&&x.body.includes('owner_user_id'),'composer governance missing');

  x=await text('/wa-native-layout-s9.js?probe=wa-s10-20260817');
  ok(x.r.ok,'layout '+x.r.status);
  ok(x.body.includes('self-heal')&&x.body.includes('AOS_WA_LAYOUT_DIAG'),'S9 layout safety missing');

  x=await text('/api/wa3/bootstrap?probe=wa-s10-20260817');
  ok(x.r.status===403,'anonymous WA3 must remain closed: '+x.r.status);
  ok(x.body.includes('WA3_2FA_PANEL_REQUIRED'),'anonymous gate changed');

  console.log('WA_S10_CUSTOMER_WINDOW_LIVE=PASS');
})().catch(e=>{console.error(e);process.exit(1)});
