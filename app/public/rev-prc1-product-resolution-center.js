// ASCENDA OS — REV-PRC1 Product Resolution Center
// Human-in-the-loop resolution for F3 REVIEW_REQUIRED product aliases.
(function(){
'use strict';
if(window.__AOS_REV_PRC1__)return;
window.__AOS_REV_PRC1__=true;

var previousFetch=window.fetch.bind(window);
var SB_URL='https://ituyqwstonmhnfshnaqz.supabase.co';
var SB_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';
var lastBadgeLoad=0;
var cachedReview=null;

function esc(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function money(v){return 'S/'+Number(v||0).toLocaleString('es-PE',{minimumFractionDigits:2,maximumFractionDigits:2});}
function parseBody(init){try{return JSON.parse((init&&init.body)||'{}');}catch(e){return {};}}
function rpcName(input){var u=typeof input==='string'?input:(input&&input.url)||'';var m=u.match(/\/rest\/v1\/rpc\/([^?]+)/);return m&&m[1];}
function normalize(v){return String(v||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,'');}
function bigrams(s){s=normalize(s);var a=[];if(s.length<2)return s?[s]:[];for(var i=0;i<s.length-1;i++)a.push(s.slice(i,i+2));return a;}
function similarity(a,b){
  a=normalize(a);b=normalize(b);if(!a||!b)return 0;if(a===b)return 1;if(a.indexOf(b)>=0||b.indexOf(a)>=0)return .88;
  var aa=bigrams(a),bb=bigrams(b),used={},hit=0;
  aa.forEach(function(x,i){for(var j=0;j<bb.length;j++){var k=x+'#'+j;if(!used[k]&&x===bb[j]){used[k]=true;hit++;break;}}});
  return (2*hit)/Math.max(1,aa.length+bb.length);
}
function canonicalToken(){
  var fallback='';try{fallback=sessionStorage.getItem('aos_app_token')||'';}catch(e){}
  if(!('caches' in window))return Promise.resolve(fallback);
  return caches.open('aos-phase2-auth').then(function(c){return c.match('/__aos_app_token');}).then(function(r){return r?r.text():'';}).then(function(t){
    t=String(t||'').trim()||fallback;if(t)try{sessionStorage.setItem('aos_app_token',t);}catch(e){}return t;
  }).catch(function(){return fallback;});
}
function rpc(name,payload){
  return canonicalToken().then(function(t){
    var body=Object.assign({},payload||{},{p_token:t});
    return previousFetch(SB_URL+'/rest/v1/rpc/'+name,{method:'POST',headers:{'apikey':SB_KEY,'Authorization':'Bearer '+SB_KEY,'Content-Type':'application/json'},body:JSON.stringify(body),cache:'no-store'});
  }).then(function(r){return r.json().then(function(d){if(!r.ok&&(!d||d.ok!==false))throw new Error('HTTP_'+r.status);return d;});});
}

function buttonHost(){var h=document.querySelector('.vs .vs-hdr');if(!h)return null;return h.lastElementChild||h;}
function ensureButton(){
  var host=buttonHost();if(!host)return;
  var b=document.getElementById('prc1-products-review-btn');
  if(!b){
    b=document.createElement('button');b.id='prc1-products-review-btn';b.type='button';
    b.style.cssText='padding:6px 12px;border-radius:8px;border:1px solid #F59E0B;background:#FFFBEB;color:#92400E;font:700 10px DM Sans,sans-serif;cursor:pointer;white-space:nowrap';
    b.textContent='Productos por validar';b.onclick=openCenter;host.appendChild(b);
  }
  if(Date.now()-lastBadgeLoad>3000)refreshBadge();
}
function refreshBadge(){
  lastBadgeLoad=Date.now();
  rpc('aos_product_review_admin_v1',{}).then(function(d){
    if(!d||!d.ok)return;cachedReview=d;
    var b=document.getElementById('prc1-products-review-btn');if(!b)return;
    b.textContent='Productos por validar · '+Number(d.reviewLines||0);
    if(Number(d.reviewLines||0)===0){b.style.borderColor='#BBF7D0';b.style.background='#F0FDF4';b.style.color='#166534';}
    else{b.style.borderColor='#F59E0B';b.style.background='#FFFBEB';b.style.color='#92400E';}
  }).catch(function(){});
}

function rankedProducts(group,products){
  var raw=((group.rawDescriptions||[])[0]||group.aliasKey||'');
  return (products||[]).map(function(p){return {p:p,score:similarity(raw,p.canonicalName)};}).sort(function(a,b){return b.score-a.score||String(a.p.canonicalName).localeCompare(String(b.p.canonicalName));});
}
function productOptions(group,products){
  var ranked=rankedProducts(group,products),html='<option value="">Selecciona producto existente…</option>';
  ranked.forEach(function(x,i){var star=(i<3&&x.score>=.34)?'★ ':'';html+='<option value="'+esc(x.p.productKey)+'">'+star+esc(x.p.canonicalName)+' · '+esc(x.p.lifecycleStatus||'')+'</option>';});
  return html;
}
function groupCard(g,i,products){
  var names=(g.rawDescriptions||[]).join(' / '),sedes=(g.sedes||[]).join(', '),warn=Number(g.lockedCount||0)>0;
  return '<div data-prc1-group="'+i+'" style="border:1px solid #DDE4F5;border-radius:12px;padding:12px;margin:9px 0;background:#fff">'+
    '<div style="display:flex;justify-content:space-between;gap:12px;align-items:start"><div><div style="font:800 12px Exo 2,sans-serif;color:#0D1B3E">'+esc(names||g.aliasKey)+'</div><div style="font-size:9px;color:#6B7BA8;margin-top:3px">Alias: '+esc(g.aliasKey)+' · '+esc(g.firstDate)+' → '+esc(g.lastDate)+' · '+esc(sedes)+'</div></div><div style="text-align:right"><div style="font:800 14px Exo 2;color:#0D1B3E">'+Number(g.lineCount||0)+' línea(s)</div><div style="font-size:9px;color:#6B7BA8">'+money(g.revenue)+'</div></div></div>'+
    (warn?'<div style="margin-top:7px;padding:6px 8px;border-radius:7px;background:#FEF2F2;color:#991B1B;font-size:9px">Hay '+Number(g.lockedCount||0)+' línea(s) bloqueada(s); no se resolverán automáticamente.</div>':'')+
    '<div style="display:grid;grid-template-columns:1fr auto;gap:7px;margin-top:10px"><select data-prc1-product style="min-width:0;padding:7px;border:1px solid #DDE4F5;border-radius:8px;background:#fff;font-size:10px">'+productOptions(g,products)+'</select><button data-prc1-link style="border:0;border-radius:8px;padding:7px 11px;background:#0A4FBF;color:#fff;font-weight:700;font-size:10px;cursor:pointer">Vincular</button></div>'+
    '<div style="display:flex;gap:7px;margin-top:7px"><button data-prc1-new style="border:1px solid #DDE4F5;border-radius:8px;padding:7px 10px;background:#F8FAFF;color:#0A4FBF;font-weight:700;font-size:10px;cursor:pointer">+ Crear producto nuevo</button><button data-prc1-exclude style="border:1px solid #FECACA;border-radius:8px;padding:7px 10px;background:#FEF2F2;color:#991B1B;font-weight:700;font-size:10px;cursor:pointer">No mapear como producto</button></div>'+
    '<div data-prc1-createbox style="display:none;margin-top:9px;padding:9px;border-radius:9px;background:#F8FAFF;border:1px solid #DDE4F5"><div style="display:grid;grid-template-columns:1fr 170px;gap:7px"><input data-prc1-name value="'+esc(names||'')+'" placeholder="Nombre canónico" style="padding:7px;border:1px solid #DDE4F5;border-radius:8px;font-size:10px"><select data-prc1-life style="padding:7px;border:1px solid #DDE4F5;border-radius:8px;background:#fff;font-size:10px"><option value="CURRENT_UNCATALOGED">Producto actual · fuera de catálogo</option><option value="LEGACY">Producto histórico</option></select></div><div style="font-size:9px;color:#6B7BA8;margin-top:6px">Se creará una identidad canónica y este alias quedará aprendido para futuras importaciones.</div><button data-prc1-createconfirm style="margin-top:7px;border:0;border-radius:8px;padding:7px 11px;background:#16A34A;color:#fff;font-weight:700;font-size:10px;cursor:pointer">Crear y resolver</button></div>'+
    '<div data-prc1-status style="font-size:9px;margin-top:7px;color:#6B7BA8"></div></div>';
}
function renderCenter(d){
  var old=document.getElementById('prc1-center');if(old)old.remove();
  var ov=document.createElement('div');ov.id='prc1-center';
  ov.style.cssText='position:fixed;inset:0;background:rgba(7,29,74,.45);z-index:13000;display:flex;align-items:center;justify-content:center;backdrop-filter:blur(5px)';
  var q=d.queue||[];
  ov.innerHTML='<div style="width:min(880px,94vw);max-height:88vh;overflow:auto;background:#F8FAFF;border-radius:16px;padding:18px;box-shadow:0 24px 70px rgba(7,29,74,.28);font-family:DM Sans,sans-serif">'+
    '<div style="display:flex;justify-content:space-between;gap:10px;align-items:start"><div><div style="font:800 18px Exo 2,sans-serif;color:#0D1B3E">Product Resolution Center</div><div style="font-size:10px;color:#6B7BA8;margin-top:3px">Validación humana · F3/F4. La descripción original de la venta nunca se sobrescribe.</div></div><button id="prc1-close" style="border:0;background:none;font-size:22px;color:#6B7BA8;cursor:pointer">×</button></div>'+
    '<div style="display:flex;gap:8px;margin-top:12px"><div style="padding:8px 11px;border-radius:9px;background:#FFF7ED;color:#9A3412;font-size:10px;font-weight:700">'+Number(d.reviewLines||0)+' líneas pendientes</div><div style="padding:8px 11px;border-radius:9px;background:#F5F3FF;color:#6D28D9;font-size:10px;font-weight:700">'+Number(d.uniqueAliases||0)+' descripciones/aliases únicos</div></div>'+
    '<div id="prc1-list">'+(q.length?q.map(function(g,i){return groupCard(g,i,d.products||[]);}).join(''):'<div style="padding:32px;text-align:center;color:#16A34A;font-weight:700">✓ No hay productos pendientes de validación.</div>')+'</div></div>';
  document.body.appendChild(ov);
  document.getElementById('prc1-close').onclick=function(){ov.remove();};
  ov.onclick=function(e){if(e.target===ov)ov.remove();};
  bindGroups(d);
}
function openCenter(){
  rpc('aos_product_review_admin_v1',{}).then(function(d){if(!d||!d.ok)throw new Error((d&&d.error)||'LOAD_FAILED');cachedReview=d;renderCenter(d);}).catch(function(e){alert('No se pudo cargar la validación de productos: '+e.message);});
}
function setStatus(card,msg,ok){var s=card.querySelector('[data-prc1-status]');if(s){s.style.color=ok?'#166534':'#991B1B';s.textContent=msg;}}
function resolveGroup(card,g,payload){
  setStatus(card,'Procesando decisión…',true);
  return rpc('aos_product_review_resolve_v1',Object.assign({p_alias_key:g.aliasKey,p_expected_count:Number(g.lineCount||0)},payload)).then(function(r){
    if(!r||!r.ok)throw new Error((r&&r.error)||'RESOLUTION_FAILED');
    setStatus(card,'✓ '+Number(r.affected||0)+' línea(s) resueltas. Alias aprendido.',true);
    refreshBadge();
    if(typeof window.vsLoad==='function')try{window.vsLoad();}catch(e){}
    setTimeout(function(){openCenter();},450);
    return r;
  }).catch(function(e){setStatus(card,'Error: '+e.message,false);});
}
function bindGroups(d){
  Array.prototype.forEach.call(document.querySelectorAll('#prc1-center [data-prc1-group]'),function(card){
    var i=Number(card.getAttribute('data-prc1-group')),g=(d.queue||[])[i];if(!g)return;
    card.querySelector('[data-prc1-link]').onclick=function(){
      var key=card.querySelector('[data-prc1-product]').value;if(!key){setStatus(card,'Selecciona un producto canónico existente.',false);return;}
      var p=(d.products||[]).find(function(x){return x.productKey===key;});
      if(!confirm('Vincular “'+((g.rawDescriptions||[])[0]||g.aliasKey)+'” a “'+(p?p.canonicalName:key)+'”?\n\nEsto resolverá '+g.lineCount+' línea(s) actuales y el alias se aprenderá para futuras importaciones.'))return;
      resolveGroup(card,g,{p_action:'LINK_EXISTING',p_product_key:key,p_note:'Owner-confirmed link from REV-PRC1'});
    };
    card.querySelector('[data-prc1-new]').onclick=function(){var b=card.querySelector('[data-prc1-createbox]');b.style.display=b.style.display==='none'?'block':'none';};
    card.querySelector('[data-prc1-createconfirm]').onclick=function(){
      var name=card.querySelector('[data-prc1-name]').value.trim(),life=card.querySelector('[data-prc1-life]').value;if(!name){setStatus(card,'Ingresa el nombre canónico.',false);return;}
      if(!confirm('Crear el producto canónico “'+name+'” y resolver '+g.lineCount+' línea(s)?'))return;
      resolveGroup(card,g,{p_action:'CREATE_NEW',p_canonical_name:name,p_lifecycle_status:life,p_note:'Owner-created canonical product from REV-PRC1'});
    };
    card.querySelector('[data-prc1-exclude]').onclick=function(){
      if(!confirm('Excluir este alias del análisis canónico de productos?\n\nLa venta original NO se modificará. Si realmente debe ser SERVICIO, corrige también el campo Tipo desde Editar Venta.'))return;
      resolveGroup(card,g,{p_action:'EXCLUDE_NOT_PRODUCT',p_note:'Owner excluded alias from canonical product analytics'});
    };
  });
}

function decorateImportPreview(d,attempt){
  attempt=attempt||0;if(!d||!d.ok||!Number(d.reviewLines||0))return;
  var ov=document.getElementById('f4-import-preview');
  if(!ov){if(attempt<30)setTimeout(function(){decorateImportPreview(d,attempt+1);},100);return;}
  if(document.getElementById('prc1-import-details'))return;
  var actions=document.getElementById('f4-imp-cancel');actions=actions&&actions.parentElement;
  var block=document.createElement('div');block.id='prc1-import-details';
  block.style.cssText='margin-top:8px;padding:9px;border-radius:9px;background:#FFF7ED;border:1px solid #FED7AA;color:#9A3412;font-size:10px';
  block.innerHTML='<b>'+Number(d.reviewLines||0)+' línea(s) / '+Number(d.uniqueAliases||0)+' descripción(es) requieren validación:</b><div style="margin-top:5px">'+(d.groups||[]).map(function(g){return '• '+esc((g.rawDescriptions||[]).join(' / ')||g.aliasKey)+' ×'+Number(g.lineCount||0);}).join('<br>')+'</div><div style="margin-top:5px;color:#7C2D12">Puedes importar: quedarán protegidas como REVIEW_REQUIRED y luego aparecerán en “Productos por validar”.</div>';
  if(actions&&actions.parentElement)actions.parentElement.insertBefore(block,actions);else ov.firstElementChild.appendChild(block);
}

window.fetch=function(input,init){
  if(rpcName(input)==='aos_importar_ventas'){
    var ventas=parseBody(init).p_ventas||[];
    rpc('aos_product_batch_review_v1',{p_ventas:ventas}).then(function(d){decorateImportPreview(d,0);}).catch(function(){});
  }
  return previousFetch(input,init);
};

function run(){ensureButton();}
run();
try{new MutationObserver(run).observe(document.documentElement||document.body,{childList:true,subtree:true});}catch(e){}
try{window.addEventListener('focus',function(){ensureButton();refreshBadge();});}catch(e){}
})();
