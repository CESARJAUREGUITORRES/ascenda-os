const fs = require('fs');
const path = require('path');
const p = path.join(process.cwd(), 'app', 'public', 'admin-sales.html');
let text = fs.readFileSync(p, 'utf8');

const oldDecl = "var SB='https://ituyqwstonmhnfshnaqz.supabase.co',SK='";
const newDecl = "var VS_SB='https://ituyqwstonmhnfshnaqz.supabase.co',VS_SK='";
if (!text.includes(oldDecl)) {
  if (text.includes(newDecl)) {
    console.log('ADMIN_SALES_RPC_ISOLATION=ALREADY_APPLIED');
    process.exit(0);
  }
  throw new Error('ADMIN_SALES_RPC_ISOLATION=FAIL: legacy SB/SK declaration not found');
}
text = text.replace(oldDecl, newDecl);

const oldRpc = "function rpc(fn,p,ok){fetch(SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json'},body:JSON.stringify(p||{})}).then(function(r){return r.json();}).then(ok||function(){}).catch(function(e){console.error(fn,e);});}";
const newRpc = "function rpc(fn,p,ok){fetch(VS_SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':VS_SK,'Authorization':'Bearer '+VS_SK,'Content-Type':'application/json'},body:JSON.stringify(p||{}),cache:'no-store'}).then(function(r){return r.json().then(function(b){if(!r.ok||!b||b.code||b.error)throw new Error((b&&(b.message||b.error||b.code))||('HTTP '+r.status));return b;});}).then(ok||function(){}).catch(function(e){console.error('Ventas RPC '+fn,e);var f=el('vs-fact');if(f)f.textContent='Error de lectura';var tb=el('vs-tb');if(tb)tb.innerHTML='<tr><td colspan=\"10\" class=\"ld\">No se pudieron cargar las ventas. Reintenta o recarga el panel.</td></tr>';});}";
if (!text.includes(oldRpc)) throw new Error('ADMIN_SALES_RPC_ISOLATION=FAIL: rpc helper source shape changed');
text = text.replace(oldRpc, newRpc);

const oldRest = "function rest(p,o){return fetch(SB+'/rest/v1/'+p,Object.assign({headers:{'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json','Prefer':'return=minimal'}},o||{}));}";
const newRest = "function rest(p,o){return fetch(VS_SB+'/rest/v1/'+p,Object.assign({headers:{'apikey':VS_SK,'Authorization':'Bearer '+VS_SK,'Content-Type':'application/json','Prefer':'return=minimal'},cache:'no-store'},o||{}));}";
if (!text.includes(oldRest)) throw new Error('ADMIN_SALES_RPC_ISOLATION=FAIL: rest helper source shape changed');
text = text.replace(oldRest, newRest);

const oldToday = "var hoyStr=new Date().toISOString().slice(0,10);";
const newToday = "var hoyStr=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());";
if (text.includes(oldToday)) text = text.replace(oldToday, newToday);

fs.writeFileSync(p, text, 'utf8');
console.log('ADMIN_SALES_RPC_ISOLATION=PASS');
