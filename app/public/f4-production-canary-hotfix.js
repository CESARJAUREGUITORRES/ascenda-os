// ASCENDA OS — F4 production canary P0/P0.5/P0.6/P0.7 browser recovery.
(function(){
'use strict';
if(window.__AOS_F4_PRODUCTION_CANARY_P0__)return;
window.__AOS_F4_PRODUCTION_CANARY_P0__=true;

var previousFetch=window.fetch.bind(window);
var nativeConfirm=window.confirm.bind(window);
var tokenSyncPromise=null;
var cc6PanelSeen=null;
var cc6ReloadTimer=null;
var agendaPanelSeen=null;
var agendaReloadTimer=null;

function cleanCajaClosedState(){
  var box=document.getElementById('no-sesion-msg');
  if(!box)return;
  var extras=box.querySelectorAll('.btn-abrir-inline');
  Array.prototype.forEach.call(extras,function(b){b.remove();});
}

function urlOf(input){return typeof input==='string'?input:(input&&input.url)||'';}
function parseBody(init){try{return JSON.parse((init&&init.body)||'{}');}catch(e){return {};}}
function rpcUrl(url,name){return url.split('/rest/v1/')[0]+'/rest/v1/rpc/'+name;}
function unique(xs){var out=[];xs.forEach(function(x){x=String(x||'').trim();if(x&&out.indexOf(x)<0)out.push(x);});return out;}
function storageTokens(){
  try{return unique([sessionStorage.getItem('aos_app_token')]);}
  catch(e){return [];}
}
function cacheToken(){
  if(!('caches' in window))return Promise.resolve('');
  return caches.open('aos-phase2-auth').then(function(c){return c.match('/__aos_app_token');}).then(function(r){return r?r.text():'';}).catch(function(){return '';});
}
function strongTokenCandidates(){
  var first=storageTokens();
  return cacheToken().then(function(t){return unique(first.concat([t]));});
}
function rememberToken(t){
  if(!t)return;
  try{sessionStorage.setItem('aos_app_token',t);}catch(e){}
  try{caches.open('aos-phase2-auth').then(function(c){return c.put('/__aos_app_token',new Response(t));}).catch(function(){});}catch(e){}
}
function syncCanonicalAppToken(){
  if(tokenSyncPromise)return tokenSyncPromise;
  tokenSyncPromise=cacheToken().then(function(t){
    t=String(t||'').trim();
    if(t.length>=32)try{sessionStorage.setItem('aos_app_token',t);}catch(e){}
    return t;
  }).catch(function(){return '';}).then(function(t){tokenSyncPromise=null;return t;},function(){tokenSyncPromise=null;return '';});
  return tokenSyncPromise;
}
function salesErrorBanner(msg){
  var host=document.querySelector('.vs');if(!host)return;
  var old=document.getElementById('f4-sales-auth-alert');if(old)old.remove();
  var el=document.createElement('div');el.id='f4-sales-auth-alert';
  el.style.cssText='padding:9px 12px;border:1px solid #FECACA;background:#FEF2F2;color:#991B1B;border-radius:9px;font:700 11px DM Sans,sans-serif';
  el.textContent=msg||'No fue posible validar la sesión segura de Ventas.';
  host.insertBefore(el,host.firstChild);
}
function clearSalesError(){var old=document.getElementById('f4-sales-auth-alert');if(old)old.remove();}
function postSalesGateway(url,init,name,body,token){
  var payload={p_token:token,p_anio:body.p_anio,p_sede:body.p_sede||'',p_asesor:body.p_asesor||'',p_mode:name==='aos_ventas_admin_anio'?'ANIO':'MES'};
  if(name==='aos_ventas_admin')payload.p_mes=body.p_mes;
  var h=new Headers((init&&init.headers)||{});h.set('Content-Type','application/json');
  return previousFetch(rpcUrl(url,'aos_sales_admin_gateway_v4'),{method:'POST',headers:h,body:JSON.stringify(payload),cache:'no-store'});
}
function strongSalesRead(url,init,name,body){
  return strongTokenCandidates().then(function(tokens){
    var i=0,last=null;
    function attempt(){
      if(i>=tokens.length){
        salesErrorBanner('Sesión 2FA de Ventas no disponible. Vuelve a iniciar sesión para recuperar el acceso; los datos no se han borrado.');
        return last||new Response(JSON.stringify({ok:false,error:'F4_STRONG_SESSION_REQUIRED'}),{status:401,headers:{'Content-Type':'application/json'}});
      }
      var t=tokens[i++];
      return postSalesGateway(url,init,name,body,t).then(function(r){
        last=r;
        return r.clone().json().catch(function(){return null;}).then(function(d){
          if(d&&d.ok===false&&d.error==='UNAUTHORIZED')return attempt();
          if(d&&d.ok===true){rememberToken(t);clearSalesError();}
          return r;
        });
      });
    }
    return attempt();
  });
}
window.confirm=function(message){
  var text=String(message||'');
  if(window.__AOS_F4_REVENUE_OPS__&&text.indexOf('CONFIRMAR IMPORTACIÓN DE VENTAS')===0)return true;
  return nativeConfirm(message);
};
window.fetch=function(input,init){
  var url=urlOf(input),rm=url.match(/\/rest\/v1\/rpc\/([^?]+)/),name=rm&&rm[1];
  if(name==='aos_ventas_admin'||name==='aos_ventas_admin_anio'){
    return strongSalesRead(url,init,name,parseBody(init));
  }
  if(name==='aos_editar_venta'||name==='aos_importar_ventas'||name==='aos_grabar_venta_caja'){
    return syncCanonicalAppToken().then(function(t){
      if(String(t||'').trim().length<32){salesErrorBanner('Sesión 2FA de Ventas no disponible. Vuelve a iniciar sesión; no se realizó ninguna escritura.');}
      return previousFetch(input,init);
    });
  }
  return previousFetch(input,init);
};
function patchSalesEditorTruth(){
  if(typeof window.evCampoSel!=='function'||window.evCampoSel.__f4TruthSafe)return;
  var original=window.evCampoSel;
  function safe(id,label,val,opts){
    var current=String(val==null?'':val);
    var list=(opts||[]).map(function(x){return String(x);});
    if(list.indexOf(current)<0)list.unshift(current);
    return original(id,label,current,list);
  }
  safe.__f4TruthSafe=true;
  safe.__original=original;
  window.evCampoSel=safe;
}
function loadProductResolutionCenter(){
  function loadCenterRuntime(){
    if(window.__AOS_REV_PRC1__||document.getElementById('rev-prc1-runtime'))return;
    var s=document.createElement('script');
    s.id='rev-prc1-runtime';
    s.src='/rev-prc1-product-resolution-center.js?v=20260821-prc1-v3-authbridge';
    s.async=false;
    (document.head||document.documentElement).appendChild(s);
  }
  if(window.__AOS_REV_PRC1__||document.getElementById('rev-prc1-runtime'))return;
  if(window.__AOS_REV_PRC1_AUTH_BRIDGE__){loadCenterRuntime();return;}
  if(document.getElementById('rev-prc1-auth-bridge'))return;
  var b=document.createElement('script');
  b.id='rev-prc1-auth-bridge';
  b.src='/rev-prc1-auth-bridge.js?v=20260821-prc1-auth-v1';
  b.async=false;
  b.onload=loadCenterRuntime;
  b.onerror=function(){console.error('[REV-PRC1] auth bridge failed to load');};
  (document.head||document.documentElement).appendChild(b);
}

function loadBusinessPriorityRuntime(){
  if(window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__||document.getElementById('aos-business-priority-browser-v1'))return;
  var s=document.createElement('script');
  s.id='aos-business-priority-browser-v1';
  s.src='/browser-business-priority-v1.js?v=20260901-p0-bc-v1';
  s.async=false;
  s.onerror=function(){console.error('[BUSINESS-PRIORITY] browser runtime failed');};
  (document.head||document.documentElement).appendChild(s);
}

function loadCallCenterPerformance(){
  var old=document.getElementById('aos-cc-performance-v1');if(old)old.remove();
  var p=document.createElement('script');
  p.id='aos-cc-performance-v1';
  p.src='/calls-performance-v1.js?v=20260901-p0-v1';
  p.async=false;
  p.onerror=function(){console.error('[ASCENDA][CC-PERF] runtime failed');};
  (document.head||document.documentElement).appendChild(p);
}

// Call Center Loop 6 V2.3 must execute after the panel's legacy inline script.
// app.html loads panel externals first and sets AOS._capturePanelTimers=false
// only after the collected inline runtime has finished loading. We wait for
// that exact loader boundary, then replay the certified governed handlers.
function ensureCallCenterLoop6Postload(){
  var panel=document.getElementById('cc-m-cita-manual');
  if(!panel){
    cc6PanelSeen=null;
    if(cc6ReloadTimer){clearTimeout(cc6ReloadTimer);cc6ReloadTimer=null;}
    return;
  }
  if(panel===cc6PanelSeen)return;
  cc6PanelSeen=panel;
  if(cc6ReloadTimer)clearTimeout(cc6ReloadTimer);
  var attempts=0;
  function afterInline(){
    if(document.getElementById('cc-m-cita-manual')!==panel)return;
    attempts++;
    if(window.AOS&&AOS._capturePanelTimers===true&&attempts<100){
      cc6ReloadTimer=setTimeout(afterInline,50);
      return;
    }
    cc6ReloadTimer=null;
    var old=document.getElementById('aos-cc6-postload-runtime');
    if(old)old.remove();
    var s=document.createElement('script');
    s.id='aos-cc6-postload-runtime';
    s.src='/calls-loop6.js?v=20260901-loop6-v2.3-postload';
    s.async=false;
    s.onload=function(){
      window.__AOS_CC_LOOP6_POSTLOAD_READY__='v2.3-postload';
      console.log('[ASCENDA][CC6V23] governed postload runtime active');
      loadCallCenterPerformance();
    };
    s.onerror=function(){console.error('[ASCENDA][CC6V23] postload runtime failed');};
    (document.head||document.documentElement).appendChild(s);
  }
  cc6ReloadTimer=setTimeout(afterInline,0);
}

// Agenda legacy inline code owns agGuardarEstado. Replay the governed status
// adapter only after that inline boundary so it cannot be overwritten.
function ensureAgendaGovernedPostload(){
  var panel=document.getElementById('ag-content');
  if(!panel){
    agendaPanelSeen=null;
    if(agendaReloadTimer){clearTimeout(agendaReloadTimer);agendaReloadTimer=null;}
    return;
  }
  if(panel===agendaPanelSeen)return;
  agendaPanelSeen=panel;
  if(agendaReloadTimer)clearTimeout(agendaReloadTimer);
  var attempts=0;
  function afterInline(){
    if(document.getElementById('ag-content')!==panel)return;
    attempts++;
    if(window.AOS&&AOS._capturePanelTimers===true&&attempts<100){
      agendaReloadTimer=setTimeout(afterInline,50);
      return;
    }
    agendaReloadTimer=null;
    var old=document.getElementById('aos-agenda-governed-status-v1');if(old)old.remove();
    var s=document.createElement('script');
    s.id='aos-agenda-governed-status-v1';
    s.src='/agenda-governed-status-v1.js?v=20260901-p0-v1';
    s.async=false;
    s.onerror=function(){console.error('[ASCENDA][AGENDA] governed status runtime failed');};
    (document.head||document.documentElement).appendChild(s);
  }
  agendaReloadTimer=setTimeout(afterInline,0);
}

function run(){cleanCajaClosedState();patchSalesEditorTruth();loadProductResolutionCenter();ensureCallCenterLoop6Postload();ensureAgendaGovernedPostload();}
loadBusinessPriorityRuntime();
run();
syncCanonicalAppToken();
setTimeout(syncCanonicalAppToken,700);
setTimeout(syncCanonicalAppToken,2500);
try{window.addEventListener('focus',syncCanonicalAppToken);}catch(e){}
try{document.addEventListener('visibilitychange',function(){if(!document.hidden)syncCanonicalAppToken();});}catch(e){}
try{var obs=new MutationObserver(function(){run();});obs.observe(document.documentElement||document.body,{childList:true,subtree:true});}catch(e){}
})();
