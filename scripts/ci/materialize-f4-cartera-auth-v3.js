'use strict';
const fs = require('fs');
const vm = require('vm');

function read(p){ return fs.readFileSync(p,'utf8'); }
function write(p,s){ fs.writeFileSync(p,s,'utf8'); }
function replaceOnce(p, oldText, newText){
  let s=read(p);
  const first=s.indexOf(oldText);
  if(first<0){
    if(s.includes(newText)){
      console.log(`${p}: already materialized`);
      return;
    }
    throw new Error(`${p}: expected source shape not found`);
  }
  if(s.indexOf(oldText, first+oldText.length)>=0) throw new Error(`${p}: source shape is ambiguous`);
  s=s.replace(oldText,newText);
  write(p,s);
  console.log(`${p}: materialized`);
}

replaceOnce(
  'app/public/admin-cartera.html',
  "function token(){try{return sessionStorage.getItem('aos_si_token')||''}catch(err){return ''}}",
  "function token(){try{return sessionStorage.getItem('aos_app_token')||''}catch(err){return ''}}"
);

replaceOnce(
  'app/public/f4-revenue-ops.js',
  "try{return sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||''}catch(e){return ''}",
  "try{return sessionStorage.getItem('aos_app_token')||''}catch(e){return ''}"
);

replaceOnce(
  'ci/phase2-cartera/ui_contract.js',
  "for(const marker of ['aos_cartera_gateway','aos_cartera_reconcile','p_expected_updated_at:current.updatedAt','aos_si_token','RECORDATORIOS BLOQUEADOS','Adelantos ≠ deuda']) ok(cartera.includes(marker), `missing Cartera marker: ${marker}`);",
  "for(const marker of ['aos_cartera_gateway','aos_cartera_reconcile','p_expected_updated_at:current.updatedAt','aos_app_token','RECORDATORIOS BLOQUEADOS','Adelantos ≠ deuda']) ok(cartera.includes(marker), `missing Cartera marker: ${marker}`);\nok(!cartera.includes('aos_si_token'), 'Cartera must not depend on the Sales Intelligence token scope');"
);

replaceOnce(
  'ci/phase4-revenue/ui_contract.js',
  "for(const marker of requiredBridge) ok(bridge.includes(marker), `missing F4 bridge marker: ${marker}`);",
  "for(const marker of requiredBridge) ok(bridge.includes(marker), `missing F4 bridge marker: ${marker}`);\nok(bridge.includes(\"sessionStorage.getItem('aos_app_token')\"), 'F4 must use the Auth V3 app token');\nok(!bridge.includes('aos_si_token'), 'F4 must not fall back to the Sales Intelligence token scope');"
);

const cartera=read('app/public/admin-cartera.html');
const m=cartera.match(/<script>([\s\S]*?)<\/script>/);
if(!m) throw new Error('admin-cartera inline script not found');
new vm.Script(m[1],{filename:'admin-cartera.inline.js'});

for(const p of ['app/public/admin-cartera.html','app/public/f4-revenue-ops.js']){
  if(read(p).includes('aos_si_token')) throw new Error(`${p}: cross-scope aos_si_token remains`);
}
console.log('F4_CARTERA_AUTH_V3_MATERIALIZATION=PASS');
