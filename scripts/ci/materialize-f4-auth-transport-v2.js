'use strict';
const fs=require('fs');
function read(p){return fs.readFileSync(p,'utf8');}
function write(p,s){fs.writeFileSync(p,s,'utf8');}
function need(c,m){if(!c)throw new Error(m);}
function once(s,a,b,m){const i=s.indexOf(a);need(i>=0,'missing '+m);need(s.indexOf(a,i+1)<0,'duplicate '+m);return s.slice(0,i)+b+s.slice(i+a.length);}
function region(s,a,b,n,m){const i=s.indexOf(a);need(i>=0,'missing start '+m);const j=s.indexOf(b,i+a.length);need(j>=0,'missing end '+m);return s.slice(0,i)+n+s.slice(j);}

// Server: same-origin read-only bridge. Existing RPCs remain the sole auth/data authority.
{
 const p='app/server-f4.js';let s=read(p);
 if(!s.includes("pathname==='/api/f4/cartera-read'")){
  const handler=`async function handleRevenueRead(req,res,body,kind){\n  const appToken=strongToken(req);\n  if(!appToken){writeJson(res,403,{ok:false,error:'F4_STRONG_SESSION_REQUIRED'});return;}\n  let rpcName='',payload={};\n  if(kind==='cartera'){rpcName='aos_cartera_gateway';payload={p_token:appToken,p_estado:String((body&&body.estado)||''),p_sede:String((body&&body.sede)||''),p_limit:Number((body&&body.limit)||100),p_offset:Number((body&&body.offset)||0)};}\n  else if(kind==='sales-intelligence'){rpcName='aos_sales_intelligence_gateway';payload={p_token:appToken,p_anio:Number((body&&body.anio)||0),p_sede:String((body&&body.sede)||''),p_asesor:String((body&&body.asesor)||'')};}\n  else{writeJson(res,400,{ok:false,error:'INVALID_REVENUE_READ'});return;}\n  try{const out=await sbRpc(rpcName,payload);if(out.status<200||out.status>=300){writeJson(res,502,{ok:false,error:'F4_REVENUE_UPSTREAM_REJECTED',upstream_status:out.status});return;}writeJson(res,200,out.data||{ok:false,error:'UPSTREAM_EMPTY'});}\n  catch(e){console.error('[F4-PROXY] revenue read',kind,e.message);writeJson(res,502,{ok:false,error:'F4_REVENUE_UPSTREAM_UNAVAILABLE'});}\n}\n\n`;
  s=once(s,'function waConfigReadyInbound(){',handler+'function waConfigReadyInbound(){','server revenue handler anchor');
  const a="  if(pathname==='/api/f4/cartera-candidates'&&req.method==='POST'){";
  const routes=`  if(pathname==='/api/f4/cartera-read'&&req.method==='POST'){try{const parsed=await readJson(req,64*1024);await handleRevenueRead(req,res,parsed.body,'cartera');}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;}\n  if(pathname==='/api/f4/sales-intelligence-read'&&req.method==='POST'){try{const parsed=await readJson(req,64*1024);await handleRevenueRead(req,res,parsed.body,'sales-intelligence');}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;}\n`;
  s=once(s,a,routes+a,'server route anchor');write(p,s);
 }
}

// Cartera: preserve token() as-is; insert cache recovery structurally and replace only load().
{
 const p='app/public/admin-cartera.html';let s=read(p);
 if(!s.includes("'/api/f4/cartera-read'")){
  const ts=s.indexOf('  function token(){');const te=s.indexOf('  function esc(s){',ts);need(ts>=0&&te>ts,'Cartera token/esc anchors missing');
  const recovery=`  function strongAppToken(){\n    var t=token();if(t)return Promise.resolve(t);\n    if(!('caches' in window))return Promise.resolve('');\n    return caches.open('aos-phase2-auth').then(function(c){return c.match('/__aos_app_token')}).then(function(r){return r?r.text():''}).then(function(v){v=String(v||'').trim();if(v){try{sessionStorage.setItem('aos_app_token',v)}catch(err){}}return v}).catch(function(){return ''});\n  }\n`;
  s=s.slice(0,te)+recovery+s.slice(te);
  const load=`  function load(){\n    strongAppToken().then(function(t){\n      if(!t){deny('Inicia sesión nuevamente con 2FA y solicita el panel Cartera.');return;}\n      return fetch('/api/f4/cartera-read',{method:'POST',headers:{'Content-Type':'application/json','X-AOS-App-Token':t},body:JSON.stringify({estado:e('car-estado').value,sede:e('car-sede').value,limit:100,offset:0}),cache:'no-store'})\n        .then(function(r){return r.json().then(function(d){return {httpOk:r.ok,data:d}})})\n        .then(function(x){var d=x.data||{};if(!x.httpOk||!d||d.ok===false){deny('La sesión o el permiso de Cartera no son válidos.');return;}render(d);});\n    }).catch(function(err){console.error(err);deny('No fue posible validar Cartera.')});\n  }\n`;
  s=region(s,'  function load(){','  function render(d){',load,'Cartera load');write(p,s);
 }
}

// Sales Intelligence: recover same strong opaque token and route read same-origin.
{
 const p='app/public/admin-sales-intelligence.html';let s=read(p);
 if(!s.includes("'/api/f4/sales-intelligence-read'")){
  const call=`  function strongFinanceToken(){\n    var t='';try{t=sessionStorage.getItem('aos_si_token')||sessionStorage.getItem('aos_app_token')||'';}catch(err){}\n    if(t)return Promise.resolve(t);\n    if(!('caches' in window))return Promise.resolve('');\n    return caches.open('aos-phase2-auth').then(function(c){return c.match('/__aos_app_token')}).then(function(r){return r?r.text():''}).then(function(v){v=String(v||'').trim();if(v){try{sessionStorage.setItem('aos_app_token',v);sessionStorage.setItem('aos_si_token',v)}catch(err){}}return v}).catch(function(){return ''});\n  }\n  function call(){\n    strongFinanceToken().then(function(token){\n      if(!token){deny('Inicia sesión nuevamente con 2FA y solicita que Sales Intelligence V2 esté asignado en Roles y Permisos.');return;}\n      var y=Number(e('si-year').value),sede=e('si-sede').value;\n      return fetch('/api/f4/sales-intelligence-read',{method:'POST',headers:{'Content-Type':'application/json','X-AOS-App-Token':token},body:JSON.stringify({anio:y,sede:sede,asesor:''}),cache:'no-store'})\n        .then(function(r){return r.json().then(function(d){return {httpOk:r.ok,data:d}})})\n        .then(function(x){var d=x.data||{};if(!x.httpOk||d&&d.ok===false){deny('La sesión o el permiso no son válidos. Vuelve a ingresar con 2FA.');return;}render(d);});\n    }).catch(function(err){console.error(err);deny('No fue posible validar el acceso. Intenta nuevamente.');});\n  }\n`;
  s=region(s,'  function call(){','  function render(d){',call,'Sales Intelligence call');write(p,s);
 }
}

// Contracts.
{
 const p='ci/phase4-revenue/ui_contract.js';let s=read(p);if(!s.includes('F4 same-origin sensitive-read transport')){
  const m="console.log('F4 UI/runtime contract PASS');";
  const c=`const carteraPage = read('app/public/admin-cartera.html');\nconst siPage = read('app/public/admin-sales-intelligence.html');\nok(proxy.includes("pathname==='/api/f4/cartera-read'") && proxy.includes("pathname==='/api/f4/sales-intelligence-read'"), 'F4 same-origin sensitive-read transport routes missing');\nok(proxy.includes("rpcName='aos_cartera_gateway'") && proxy.includes("rpcName='aos_sales_intelligence_gateway'"), 'F4 same-origin read RPC routing missing');\nok(proxy.includes('const appToken=strongToken(req)') && proxy.includes('F4_STRONG_SESSION_REQUIRED'), 'F4 same-origin read must require strong app token');\nok(carteraPage.includes("'/api/f4/cartera-read'") && carteraPage.includes("'X-AOS-App-Token':t"), 'Cartera same-origin transport missing');\nok(carteraPage.includes("caches.open('aos-phase2-auth')"), 'Cartera cache recovery missing');\nok(siPage.includes("'/api/f4/sales-intelligence-read'") && siPage.includes("'X-AOS-App-Token':token"), 'Sales Intelligence same-origin transport missing');\nok(siPage.includes("caches.open('aos-phase2-auth')"), 'Sales Intelligence cache recovery missing');\nok(!carteraPage.includes("api('aos_cartera_gateway'"), 'Cartera direct PostgREST read must remain absent');\nok(!siPage.includes("fetch(SB+'/rest/v1/rpc/aos_sales_intelligence_gateway'"), 'SI direct PostgREST read must remain absent');\n// F4 same-origin sensitive-read transport\n`;
  s=once(s,m,c+m,'F4 contract log');write(p,s);
 }
}
{
 const p='ci/phase2-cartera/ui_contract.js';let s=read(p);if(!s.includes('same-origin Cartera read transport missing')){const m="console.log('CARTERA_PHASE2_UI_CONTRACT=PASS');";const c=`ok(cartera.includes("'/api/f4/cartera-read'"), 'same-origin Cartera read transport missing');\nok(cartera.includes("caches.open('aos-phase2-auth')"), 'Cartera cached Auth V3 recovery missing');\nok(!cartera.includes("api('aos_cartera_gateway'"), 'direct Cartera gateway browser read must remain absent');\n`;s=once(s,m,c+m,'Cartera contract log');write(p,s);}
}
{
 const p='ci/phase1-sales-intelligence/ui_contract.js';let s=read(p);if(!s.includes('same-origin Sales Intelligence read transport missing')){const m="console.log('PHASE1_UI_CONTRACT=PASS');";const c=`ok(page.includes("'/api/f4/sales-intelligence-read'"), 'same-origin Sales Intelligence read transport missing');\nok(page.includes("caches.open('aos-phase2-auth')"), 'Sales Intelligence cached strong-token recovery missing');\nok(page.includes("sessionStorage.getItem('aos_app_token')"), 'Sales Intelligence app-token recovery marker missing');\nok(!page.includes("fetch(SB+'/rest/v1/rpc/aos_sales_intelligence_gateway'"), 'direct Sales Intelligence browser PostgREST read must remain absent');\n`;s=once(s,m,c+m,'SI contract log');write(p,s);}
}

const doc='docs/control/F4_AUTH_TRANSPORT_SAME_ORIGIN_HOTFIX_20260815.md';if(!fs.existsSync(doc))write(doc,`# F4 Auth transport same-origin hotfix — 2026-08-15\n\nProduction diagnostics proved Auth V3 sessions, grants, aos_cartera_gateway and aos_sales_intelligence_gateway are healthy. Both RPCs succeeded under role anon with transactional synthetic strong tokens and rollback. The production failure boundary is browser/direct-PostgREST token transport.\n\nFix: read-only same-origin routes /api/f4/cartera-read and /api/f4/sales-intelligence-read in server-f4; browser sends X-AOS-App-Token; server forwards p_token with anon transport; existing RPC remains authorization authority. Panels recover the app token from aos-phase2-auth cache if sessionStorage is absent. No service-role exposure, no sale/payment/patient/debt write, and no legacy cutover.\n`);

for(const p of ['scripts/ci/materialize-f4-auth-transport.js','scripts/ci/materialize-f4-auth-transport-wrapper.js','scripts/ci/materialize-f4-auth-transport-v2.js','.github/workflows/f4-auth-transport-materialize.yml'])if(fs.existsSync(p))fs.unlinkSync(p);
console.log('F4_AUTH_TRANSPORT_V2_MATERIALIZED=PASS');
