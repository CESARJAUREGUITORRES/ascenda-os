'use strict';
const fs=require('fs');
function read(p){return fs.readFileSync(p,'utf8');}
function write(p,s){fs.writeFileSync(p,s,'utf8');}
function need(cond,msg){if(!cond)throw new Error(msg);}
function replaceOnce(text,oldText,newText,label){
  const i=text.indexOf(oldText);need(i>=0,'missing '+label);need(text.indexOf(oldText,i+1)<0,'duplicate '+label);
  return text.slice(0,i)+newText+text.slice(i+oldText.length);
}
function replaceRegion(text,start,end,newText,label){
  const a=text.indexOf(start);need(a>=0,'missing start '+label);const b=text.indexOf(end,a+start.length);need(b>=0,'missing end '+label);
  return text.slice(0,a)+newText+text.slice(b);
}

// 1) Same-origin read transport in the F4 outer proxy. The RPC remains the auth authority.
{
  const p='app/server-f4.js';let s=read(p);
  if(!s.includes("pathname==='/api/f4/cartera-read'")){
    const handler=`async function handleRevenueRead(req,res,body,kind){\n  const appToken=strongToken(req);\n  if(!appToken){writeJson(res,403,{ok:false,error:'F4_STRONG_SESSION_REQUIRED'});return;}\n  let rpcName='',payload={};\n  if(kind==='cartera'){\n    rpcName='aos_cartera_gateway';\n    payload={p_token:appToken,p_estado:String((body&&body.estado)||''),p_sede:String((body&&body.sede)||''),p_limit:Number((body&&body.limit)||50),p_offset:Number((body&&body.offset)||0)};\n  }else if(kind==='sales-intelligence'){\n    rpcName='aos_sales_intelligence_gateway';\n    payload={p_token:appToken,p_anio:Number((body&&body.anio)||0),p_sede:String((body&&body.sede)||''),p_asesor:String((body&&body.asesor)||'')};\n  }else{writeJson(res,400,{ok:false,error:'INVALID_REVENUE_READ'});return;}\n  try{\n    const out=await sbRpc(rpcName,payload);\n    if(out.status<200||out.status>=300){writeJson(res,502,{ok:false,error:'F4_REVENUE_UPSTREAM_REJECTED',upstream_status:out.status});return;}\n    writeJson(res,200,out.data||{ok:false,error:'UPSTREAM_EMPTY'});\n  }catch(e){console.error('[F4-PROXY] revenue read',kind,e.message);writeJson(res,502,{ok:false,error:'F4_REVENUE_UPSTREAM_UNAVAILABLE'});}\n}\n\n`;
    s=replaceOnce(s,'function waConfigReadyInbound(){',handler+'function waConfigReadyInbound(){','F4 revenue handler anchor');
    const routeAnchor="  if(pathname==='/api/f4/cartera-candidates'&&req.method==='POST'){";
    const routes=`  if(pathname==='/api/f4/cartera-read'&&req.method==='POST'){\n    try{const parsed=await readJson(req,64*1024);await handleRevenueRead(req,res,parsed.body,'cartera');}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;\n  }\n  if(pathname==='/api/f4/sales-intelligence-read'&&req.method==='POST'){\n    try{const parsed=await readJson(req,64*1024);await handleRevenueRead(req,res,parsed.body,'sales-intelligence');}catch(e){writeJson(res,e.status||400,{ok:false,error:e.message||'INVALID_REQUEST'});}return;\n  }\n`;
    s=replaceOnce(s,routeAnchor,routes+routeAnchor,'F4 route anchor');
    write(p,s);
  }
}

// 2) Cartera read: recover the strong app token from sessionStorage or the login cache, then use same-origin proxy.
{
  const p='app/public/admin-cartera.html';let s=read(p);
  if(!s.includes("'/api/f4/cartera-read'")){
    const tokenAnchor="  function token(){try{return sessionStorage.getItem('aos_app_token')||''}catch(e){return ''}}\n";
    const recovery=`  function strongAppToken(){\n    var t=token();if(t)return Promise.resolve(t);\n    if(!('caches' in window))return Promise.resolve('');\n    return caches.open('aos-phase2-auth').then(function(c){return c.match('/__aos_app_token')}).then(function(r){return r?r.text():''}).then(function(v){v=String(v||'').trim();if(v){try{sessionStorage.setItem('aos_app_token',v)}catch(e){}}return v}).catch(function(){return ''});\n  }\n`;
    s=replaceOnce(s,tokenAnchor,tokenAnchor+recovery,'Cartera token helper');
    const newLoad=`  function load(){\n    strongAppToken().then(function(t){\n      if(!t){deny('Inicia sesión nuevamente con 2FA.');return;}\n      return fetch('/api/f4/cartera-read',{method:'POST',headers:{'Content-Type':'application/json','X-AOS-App-Token':t},body:JSON.stringify({estado:state.estado,sede:state.sede,limit:state.limit,offset:state.offset}),cache:'no-store'})\n        .then(function(r){return r.json().then(function(d){return {ok:r.ok,data:d}})})\n        .then(function(x){var d=x.data||{};if(!x.ok||!d||d.ok!==true){deny('No fue posible validar Cartera.');return;}state.data=d;render(d);});\n    }).catch(function(e){console.error(e);deny('No fue posible validar Cartera.')});\n  }\n`;
    s=replaceRegion(s,'  function load(){','  function render(d){',newLoad,'Cartera load');
    write(p,s);
  }
}

// 3) Sales Intelligence read: same-origin transport and strong token recovery. The SI RPC still validates finance-session membership.
{
  const p='app/public/admin-sales-intelligence.html';let s=read(p);
  if(!s.includes("'/api/f4/sales-intelligence-read'")){
    const callStart='  function call(){';
    const callEnd='  function render(d){';
    const replacement=`  function strongFinanceToken(){\n    var t='';try{t=sessionStorage.getItem('aos_si_token')||sessionStorage.getItem('aos_app_token')||'';}catch(err){}\n    if(t)return Promise.resolve(t);\n    if(!('caches' in window))return Promise.resolve('');\n    return caches.open('aos-phase2-auth').then(function(c){return c.match('/__aos_app_token')}).then(function(r){return r?r.text():''}).then(function(v){v=String(v||'').trim();if(v){try{sessionStorage.setItem('aos_app_token',v);sessionStorage.setItem('aos_si_token',v)}catch(e){}}return v}).catch(function(){return ''});\n  }\n  function call(){\n    strongFinanceToken().then(function(token){\n      if(!token){deny('Inicia sesión nuevamente con 2FA y solicita que Sales Intelligence V2 esté asignado en Roles y Permisos.');return;}\n      var y=Number(e('si-year').value),s=e('si-sede').value;\n      return fetch('/api/f4/sales-intelligence-read',{method:'POST',headers:{'Content-Type':'application/json','X-AOS-App-Token':token},body:JSON.stringify({anio:y,sede:s,asesor:''}),cache:'no-store'})\n        .then(function(r){return r.json().then(function(d){return {ok:r.ok,data:d}})})\n        .then(function(x){var d=x.data||{};if(!x.ok||d&&d.ok===false){deny('La sesión o el permiso no son válidos. Vuelve a ingresar con 2FA.');return;}render(d);});\n    }).catch(function(err){console.error(err);deny('No fue posible validar el acceso. Intenta nuevamente.');});\n  }\n`;
    s=replaceRegion(s,callStart,callEnd,replacement,'Sales Intelligence call');
    write(p,s);
  }
}

// 4) Contracts: make browser->same-origin->RPC the required path, including cache recovery.
{
  const p='ci/phase4-revenue/ui_contract.js';let s=read(p);
  if(!s.includes('F4 same-origin sensitive-read transport')){
    const marker="console.log('F4 UI/runtime contract PASS');";
    const checks=`const carteraPage = read('app/public/admin-cartera.html');\nconst siPage = read('app/public/admin-sales-intelligence.html');\nok(proxy.includes("pathname==='/api/f4/cartera-read'") && proxy.includes("pathname==='/api/f4/sales-intelligence-read'"), 'F4 same-origin sensitive-read transport routes missing');\nok(proxy.includes("rpcName='aos_cartera_gateway'") && proxy.includes("rpcName='aos_sales_intelligence_gateway'"), 'F4 same-origin read RPC routing missing');\nok(proxy.includes('const appToken=strongToken(req)') && proxy.includes('F4_STRONG_SESSION_REQUIRED'), 'F4 same-origin read must require strong app token');\nok(carteraPage.includes("'/api/f4/cartera-read'") && carteraPage.includes("'X-AOS-App-Token':t"), 'Cartera must use same-origin read transport');\nok(carteraPage.includes("caches.open('aos-phase2-auth')") && carteraPage.includes("sessionStorage.setItem('aos_app_token'"), 'Cartera strong-token recovery missing');\nok(siPage.includes("'/api/f4/sales-intelligence-read'") && siPage.includes("'X-AOS-App-Token':token"), 'Sales Intelligence must use same-origin read transport');\nok(siPage.includes("caches.open('aos-phase2-auth')") && siPage.includes("sessionStorage.setItem('aos_si_token'"), 'Sales Intelligence token recovery missing');\nok(!carteraPage.includes("fetch(SB+'/rest/v1/rpc/aos_cartera_gateway'"), 'Cartera direct browser PostgREST read must remain absent');\nok(!siPage.includes("fetch(SB+'/rest/v1/rpc/aos_sales_intelligence_gateway'"), 'Sales Intelligence direct browser PostgREST read must remain absent');\n// F4 same-origin sensitive-read transport\n`;
    s=replaceOnce(s,marker,checks+marker,'F4 contract log');write(p,s);
  }
}
{
  const p='ci/phase2-cartera/ui_contract.js';let s=read(p);
  if(!s.includes('same-origin Cartera read transport missing')){
    const marker="console.log('CARTERA_PHASE2_UI_CONTRACT=PASS');";
    const checks=`ok(cartera.includes("'/api/f4/cartera-read'"), 'same-origin Cartera read transport missing');\nok(cartera.includes("caches.open('aos-phase2-auth')"), 'Cartera cached Auth V3 recovery missing');\nok(!cartera.includes("api('aos_cartera_gateway'"), 'direct Cartera gateway browser read must remain absent');\n`;
    s=replaceOnce(s,marker,checks+marker,'Cartera contract log');write(p,s);
  }
}
{
  const p='ci/phase1-sales-intelligence/ui_contract.js';let s=read(p);
  if(!s.includes('same-origin Sales Intelligence read transport missing')){
    const marker="console.log('PHASE1_UI_CONTRACT=PASS');";
    const checks=`ok(page.includes("'/api/f4/sales-intelligence-read'"), 'same-origin Sales Intelligence read transport missing');\nok(page.includes("caches.open('aos-phase2-auth')"), 'Sales Intelligence cached strong-token recovery missing');\nok(page.includes("sessionStorage.getItem('aos_app_token')"), 'Sales Intelligence app-token recovery marker missing');\nok(!page.includes("fetch(SB+'/rest/v1/rpc/aos_sales_intelligence_gateway'"), 'direct Sales Intelligence browser PostgREST read must remain absent');\n`;
    s=replaceOnce(s,marker,checks+marker,'SI contract log');write(p,s);
  }
}

// 5) Incident evidence / safety boundary.
{
  const p='docs/control/F4_AUTH_TRANSPORT_SAME_ORIGIN_HOTFIX_20260815.md';
  if(!fs.existsSync(p))write(p,`# F4 Auth transport same-origin hotfix — 2026-08-15\n\n## Production evidence\n- Fresh Auth V3 + 2FA created matching active app/finance session hashes for ZIV-001.\n- Cartera browser request to PostgREST returned HTTP 401 before last_used_at changed.\n- Sales Intelligence did not emit its gateway request in the failing fresh session.\n- Transactional rollback diagnostics proved both aos_cartera_gateway and aos_sales_intelligence_gateway succeed as role anon with a valid strong token.\n- Therefore PostgreSQL contracts, grants and Auth V3 are healthy; the failure boundary is browser/direct-PostgREST token transport.\n\n## Fix\n- Add read-only same-origin endpoints /api/f4/cartera-read and /api/f4/sales-intelligence-read to server-f4.js.\n- Browser sends only X-AOS-App-Token to ASCENDA's own origin.\n- server-f4 forwards p_token to the existing protected RPC using the configured anon key; the RPC remains the authorization authority.\n- Recover the opaque app token from the login cache when sessionStorage is missing.\n- No service-role credential is exposed or needed by these routes.\n- No business data writes, no patient/payment/sale creation, no debt mutation.\n\n## Gate\nExact-head F4/Phase1/Cartera/Ascenda CI must pass before merge. Owner must then perform one fresh login + 2FA and open Sales Intelligence and Cartera. Legacy Revenue write cutover remains blocked until that canary passes.\n`);
}

// Temporary materializer removes itself and its workflow from the generated commit.
for(const p of ['scripts/ci/materialize-f4-auth-transport.js','.github/workflows/f4-auth-transport-materialize.yml']){if(fs.existsSync(p))fs.unlinkSync(p);}

console.log('F4_AUTH_TRANSPORT_MATERIALIZED=PASS');
