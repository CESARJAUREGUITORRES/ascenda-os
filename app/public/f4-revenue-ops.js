// ASCENDA OS — F4 Revenue Operations browser bridge.
// Loaded into /app by the registered service worker. Keeps existing panels intact
// while routing revenue/financial reads and writes through tokenized F4 contracts.
(function(){
'use strict';
if(window.__AOS_F4_REVENUE_OPS__)return;window.__AOS_F4_REVENUE_OPS__=true;
var nativeFetch=window.fetch.bind(window);
var carteraRows=[];
var carteraCandidateByCase={};

function token(){try{return sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||''}catch(e){return ''}}
function urlOf(input){return typeof input==='string'?input:(input&&input.url)||''}
function parseBody(init){try{return JSON.parse((init&&init.body)||'{}')}catch(e){return {}}}
function jsonResponse(obj,status){return new Response(JSON.stringify(obj),{status:status||200,headers:{'Content-Type':'application/json','Cache-Control':'no-store','X-Ascenda-Revenue-Contract':'F4'}})}
function rpcUrl(url,name){return url.split('/rest/v1/')[0]+'/rest/v1/rpc/'+name}
function postRpc(url,init,name,payload){var h=new Headers((init&&init.headers)||{});h.set('Content-Type','application/json');return nativeFetch(rpcUrl(url,name),{method:'POST',headers:h,body:JSON.stringify(payload||{}),cache:'no-store'})}
function missing(r){return r.status===404||r.status===400}
function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
function money(n){return 'S/'+Number(n||0).toLocaleString('es-PE',{minimumFractionDigits:2,maximumFractionDigits:2})}

function importApproval(preview){
  return new Promise(function(resolve){
    var old=document.getElementById('f4-import-preview');if(old)old.remove();
    var ov=document.createElement('div');ov.id='f4-import-preview';ov.style.cssText='position:fixed;inset:0;background:rgba(7,29,74,.45);z-index:12000;display:flex;align-items:center;justify-content:center;backdrop-filter:blur(5px)';
    var warn=(preview.productReviewRequired||0)>0||preview.possibleExistingMatches>0||preview.alreadyImported;
    ov.innerHTML='<div style="width:min(560px,92vw);background:#fff;border-radius:16px;padding:20px;box-shadow:0 24px 70px rgba(7,29,74,.25);font-family:DM Sans,sans-serif">'+
      '<div style="font:800 17px Exo 2,sans-serif;color:#0D1B3E">Validación previa · Importar ventas</div><div style="font-size:10px;color:#6B7BA8;margin:4px 0 14px">El lote todavía no ha modificado producción.</div>'+
      '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px">'+
      [['Filas',preview.total],['Monto',money(preview.totalAmount)],['Adelantos',preview.advances],['Productos',preview.productLines],['Reconocidos',preview.productResolved],['A revisar',preview.productReviewRequired]].map(function(x){return '<div style="border:1px solid #DDE4F5;border-radius:10px;padding:9px"><div style="font-size:8px;color:#8291B3;text-transform:uppercase">'+esc(x[0])+'</div><div style="font:800 16px Exo 2;color:#0D1B3E;margin-top:3px">'+esc(x[1])+'</div></div>'}).join('')+'</div>'+
      (preview.possibleExistingMatches?'<div style="margin-top:10px;padding:9px;border-radius:9px;background:#FFF9ED;color:#8A5A00;font-size:10px">⚠ '+preview.possibleExistingMatches+' coincidencia(s) posibles con ventas existentes. El importador conserva su deduplicación; revisa antes de confirmar.</div>':'')+
      (preview.productReviewRequired?'<div style="margin-top:8px;padding:9px;border-radius:9px;background:#FFF3E1;color:#B96500;font-size:10px">⚠ '+preview.productReviewRequired+' producto(s) no tienen alias confirmado y quedarán en REVIEW_REQUIRED, sin inventar identidad.</div>':'')+
      (preview.alreadyImported?'<div style="margin-top:8px;padding:9px;border-radius:9px;background:#FEE2E2;color:#B91C1C;font-size:10px">Este lote exacto ya fue procesado anteriormente.</div>':'')+
      '<div style="display:flex;justify-content:flex-end;gap:8px;margin-top:16px"><button id="f4-imp-cancel" style="border:0;border-radius:9px;padding:8px 14px;background:#EEF3FA;color:#415270;font-weight:700;cursor:pointer">Cancelar</button><button id="f4-imp-ok" style="border:0;border-radius:9px;padding:8px 14px;background:#0A4FBF;color:#fff;font-weight:700;cursor:pointer" '+(preview.alreadyImported?'disabled':'')+'>Confirmar importación</button></div></div>';
    document.body.appendChild(ov);
    function done(v){ov.remove();resolve(v)}
    document.getElementById('f4-imp-cancel').onclick=function(){done(false)};
    var ok=document.getElementById('f4-imp-ok');if(ok&&!preview.alreadyImported)ok.onclick=function(){done(true)};
  });
}

window.fetch=function(input,init){
  var url=urlOf(input),method=String((init&&init.method)||((input&&input.method)||'GET')).toUpperCase();
  var rm=url.match(/\/rest\/v1\/rpc\/([^?]+)/);var name=rm&&rm[1];

  if(name==='aos_ventas_admin'||name==='aos_ventas_admin_anio'){
    var b=parseBody(init),payload={p_token:token(),p_anio:b.p_anio,p_sede:b.p_sede||'',p_asesor:b.p_asesor||'',p_mode:name==='aos_ventas_admin_anio'?'ANIO':'MES'};if(name==='aos_ventas_admin')payload.p_mes=b.p_mes;
    return postRpc(url,init,'aos_sales_admin_gateway_v4',payload).then(function(r){if(missing(r))return nativeFetch(input,init);return r});
  }

  if(method==='GET'&&/\/rest\/v1\/aos_ventas\?/.test(url)){
    try{
      var u=new URL(url,location.href),id=(u.searchParams.get('id')||'');
      if(/^eq\.\d+$/.test(id)&&u.searchParams.get('select')==='*'){
        return postRpc(url,init,'aos_sales_admin_sale_v4',{p_token:token(),p_sale_id:Number(id.slice(3))}).then(function(r){
          if(missing(r))return nativeFetch(input,init);
          return r.json().then(function(d){return jsonResponse(d&&d.ok?[d.row]:d,r.ok?200:r.status)})
        });
      }
    }catch(e){}
  }

  if(name==='aos_editar_venta'){
    var eb=parseBody(init),expected='';try{expected=(window.EV&&window.EV.ventaOriginal&&window.EV.ventaOriginal.updated_at)||eb.p_expected_updated_at||''}catch(e){}
    return postRpc(url,init,'aos_editar_venta_v4',{p_token:token(),p_venta_id:eb.p_venta_id,p_expected_updated_at:expected||null,p_campos:eb.p_campos||{},p_origen:eb.p_origen||'panel_ventas_f4'}).then(function(r){if(missing(r))return nativeFetch(input,init);return r});
  }

  if(name==='aos_importar_ventas'){
    var ib=parseBody(init),ventas=ib.p_ventas||[];
    return postRpc(url,init,'aos_importar_ventas_preview_v4',{p_token:token(),p_ventas:ventas}).then(function(pr){
      if(missing(pr))return nativeFetch(input,init);
      return pr.json().then(function(p){
        if(!p||p.ok===false)return jsonResponse(p||{ok:false,error:'PREVIEW_FAILED'},403);
        return importApproval(p).then(function(approved){
          if(!approved)return jsonResponse({ok:false,cancelled:true,error:'IMPORT_CANCELLED_BY_USER'},409);
          return postRpc(url,init,'aos_importar_ventas_v4',{p_token:token(),p_ventas:ventas});
        });
      });
    });
  }

  if(name==='aos_grabar_venta_caja'){
    var cb=parseBody(init);cb.p_token=token();return postRpc(url,init,'aos_grabar_venta_caja_v4',cb).then(function(r){if(missing(r))return nativeFetch(input,init);return r});
  }

  if(name==='aos_cartera_gateway'){
    return nativeFetch(input,init).then(function(r){try{r.clone().json().then(function(d){if(d&&d.ok)carteraRows=d.rows||[]}).catch(function(){})}catch(e){}return r});
  }

  if(name==='aos_cartera_reconcile'){
    var rb=parseBody(init),sel=carteraCandidateByCase[rb.p_case_id]||null;
    return postRpc(url,init,'aos_cartera_reconcile_v2',{
      p_token:token(),p_case_id:rb.p_case_id,p_expected_updated_at:rb.p_expected_updated_at,p_estado:rb.p_estado,p_confianza:rb.p_confianza,
      p_total_esperado:rb.p_total_esperado,p_saldo_confirmado:rb.p_saldo_confirmado,p_candidate_type:sel?sel.type:null,p_candidate_id:sel?sel.id:null,
      p_rol_pago:rb.p_rol_pago,p_observacion:rb.p_observacion
    }).then(function(r){if(missing(r))return nativeFetch(input,init);return r});
  }
  return nativeFetch(input,init);
};

function patchSales(){
  var box=document.getElementById('vs-top-prod');if(!box||typeof window.renderCategoryRankings!=='function'||window.renderCategoryRankings.__f4)return;
  var original=window.renderCategoryRankings;
  function patched(rows){
    original(rows);
    var target=document.getElementById('vs-top-prod');if(!target)return;
    var map={},base=0,productLines=0,resolved=0,review=0,excluded=0;
    (rows||[]).forEach(function(v){if((v.tipo||'')!=='PRODUCTO')return;productLines++;var m=Number(v.monto||0);base+=m;var st=v.productResolutionStatus||'';if(st==='EXCLUDED'){excluded++;return}if(st!=='RESOLVED'||!v.canonicalProductName){review++;return}resolved++;var k=v.canonicalProductKey||v.canonicalProductName;if(!map[k])map[k]={name:v.canonicalProductName,n:0,total:0,units:0,packs:0};map[k].n++;map[k].total+=m;map[k].units+=Number(v.physicalQty||0);if(v.isPack)map[k].packs++});
    var items=Object.keys(map).map(function(k){return map[k]}).sort(function(a,b){return b.total-a.total}).slice(0,8);if(!items.length){target.innerHTML='<div class="ld">Sin productos canónicos resueltos</div>';return}
    var max=items[0].total||1;target.innerHTML=items.map(function(x,i){var w=Math.max(4,Math.round(x.total/max*100)),share=base?Math.round(x.total/base*100):0;return '<div class="rkx-row"><div><div class="rkx-name" title="'+esc(x.name)+'">'+(i+1)+'. '+esc(x.name)+'</div><div class="rkx-sub">'+x.n+' ventas · '+x.units.toLocaleString('es-PE',{maximumFractionDigits:2})+' u'+(x.packs?' · '+x.packs+' pack':'')+' · '+share+'% categoría</div></div><div class="rkx-bar"><div class="rkx-fill rkx-fill-prod" style="width:'+w+'%"></div></div><div class="rkx-val">'+money(x.total)+'</div></div>'}).join('')+
      '<div class="rkx-note">F4 canónico · '+resolved+'/'+productLines+' líneas resueltas'+(review?' · '+review+' por revisar':'')+(excluded?' · '+excluded+' excluidas':'')+'. La descripción original permanece auditable.</div>';
  }
  patched.__f4=true;patched.__original=original;window.renderCategoryRankings=patched;
  try{if(window.VS&&window.VS.data)patched(window.VS.data.detalle||[])}catch(e){}
}

function candidateSummary(c){var bits=[];var r=c.reasons||{};if(r.phoneMatch)bits.push('teléfono');if(r.dniMatch)bits.push('DNI');if(r.sameCanonicalProduct)bits.push('producto');else if(r.sameConcept)bits.push('concepto');if(r.fullPayment)bits.push('pago completo');if(r.amountNear)bits.push('monto');return bits.join(' · ')||'coincidencia contextual'}
function loadCandidates(caseRow){
  var modal=document.getElementById('car-modal');if(!modal||!caseRow)return;var form=modal.querySelector('.car-form');if(!form)return;
  var old=document.getElementById('f4-car-candidates');if(old)old.remove();var wrap=document.createElement('div');wrap.id='f4-car-candidates';wrap.style.cssText='grid-column:1/-1;border:1px solid #D9E2F1;border-radius:10px;padding:10px;background:#F8FAFE';wrap.innerHTML='<div style="font-size:9px;font-weight:800;color:#415270">COINCIDENCIAS DEL SISTEMA</div><div style="font-size:9px;color:#8291B3;margin-top:3px">Buscando evidencia existente. Seleccionar una coincidencia no crea un pago nuevo.</div><div id="f4-car-list" style="margin-top:8px">Cargando...</div>';form.appendChild(wrap);
  var base='https://ituyqwstonmhnfshnaqz.supabase.co/rest/v1/rpc/aos_cartera_candidates_v2';var headers={'Content-Type':'application/json'};try{var anyReq=document.querySelector('script');}catch(e){};
  // Reuse public Supabase transport headers from an existing request is not possible here; the public anon key is available in the panel globals only.
  // Build from the current panel's gateway URL by using same-origin PostgREST request headers through a minimal public key copied from app runtime when present.
  var key=(window._SBK||window.SK||'');if(!key){var scripts=document.scripts;for(var i=0;i<scripts.length;i++){if(scripts[i].textContent&&scripts[i].textContent.indexOf('ituyqwstonmhnfshnaqz')>=0){var m=scripts[i].textContent.match(/eyJ[a-zA-Z0-9_.-]{80,}/);if(m){key=m[0];break}}}}
  if(key){headers.apikey=key;headers.Authorization='Bearer '+key}
  nativeFetch(base,{method:'POST',headers:headers,body:JSON.stringify({p_token:token(),p_case_id:caseRow.id}),cache:'no-store'}).then(function(r){return r.json()}).then(function(d){var list=document.getElementById('f4-car-list');if(!list)return;if(!d||!d.ok){list.textContent='No fue posible consultar coincidencias.';return}var cs=d.candidates||[];if(!cs.length){list.innerHTML='<span style="font-size:9px;color:#8291B3">Sin coincidencias suficientemente fuertes. Puedes clasificar manualmente el caso, excepto PAGO_RECONCILIADO que exige evidencia vinculada.</span>';return}list.innerHTML=cs.map(function(c,i){return '<button type="button" data-f4cand="'+i+'" style="display:block;width:100%;text-align:left;border:1px solid #DDE4F5;background:#fff;border-radius:8px;padding:8px;margin:5px 0;cursor:pointer"><b>'+esc(c.type)+' · '+esc(c.date||'')+' · '+money(c.totalAmount)+'</b><br><span style="font-size:9px;color:#6B7BA8">Score '+esc(c.score)+' · '+esc(c.confidence)+' · '+esc(candidateSummary(c))+'</span></button>'}).join('');Array.prototype.forEach.call(list.querySelectorAll('[data-f4cand]'),function(b){b.onclick=function(){var c=cs[Number(b.getAttribute('data-f4cand'))];carteraCandidateByCase[caseRow.id]={type:c.type,id:c.id};Array.prototype.forEach.call(list.children,function(x){x.style.borderColor='#DDE4F5';x.style.background='#fff'});b.style.borderColor='#0A4FBF';b.style.background='#EBF2FF';var total=document.getElementById('car-edit-total'),bal=document.getElementById('car-edit-balance');if(c.type==='COTIZACION'){if(total&&c.totalAmount!=null)total.value=c.totalAmount;if(bal&&c.balanceAmount!=null)bal.value=c.balanceAmount}var note=document.getElementById('car-edit-note');if(note&&!note.value)note.value='F4: evidencia vinculada '+c.type+' '+c.id;}}})}).catch(function(){var list=document.getElementById('f4-car-list');if(list)list.textContent='Error consultando coincidencias.'});
}

document.addEventListener('click',function(ev){var b=ev.target&&ev.target.closest?ev.target.closest('#car-body button[data-i]'):null;if(!b)return;var r=carteraRows[Number(b.getAttribute('data-i'))];if(!r)return;setTimeout(function(){loadCandidates(r)},80)},true);

var observer=new MutationObserver(function(){setTimeout(patchSales,40)});observer.observe(document.documentElement,{childList:true,subtree:true});setInterval(patchSales,1200);
console.info('[ASCENDA F4] Revenue Operations bridge active');
})();
