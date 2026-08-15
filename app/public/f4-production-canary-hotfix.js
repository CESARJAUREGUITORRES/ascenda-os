// ASCENDA OS — F4 production canary P0/P0.5 browser recovery.
(function(){
'use strict';
if(window.__AOS_F4_PRODUCTION_CANARY_P0__)return;
window.__AOS_F4_PRODUCTION_CANARY_P0__=true;

var previousFetch=window.fetch.bind(window);

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
  // Ventas F4 is authorized exclusively by Auth V3 app sessions.
  // Never consume the separate Sales Intelligence finance token here.
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
  // Keep token scopes isolated: app_token belongs to aos_app_sessions_v3.
  // Sales Intelligence owns its own finance token and must remain untouched.
  try{sessionStorage.setItem('aos_app_token',t);}catch(e){}
  try{caches.open('aos-phase2-auth').then(function(c){return c.put('/__aos_app_token',new Response(t));}).catch(function(){});}catch(e){}
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

// P0.5: intercept Sales reads before the older F4 bridge. The older bridge used
// only sessionStorage synchronously; after some app/PWA navigation cycles the
// app token can be absent while the same strong app token remains in the service
// worker cache written at login. Trying both app-token sources prevents a valid
// dataset from being rendered as an all-zero dashboard on an UNAUTHORIZED envelope.
window.fetch=function(input,init){
  var url=urlOf(input),rm=url.match(/\/rest\/v1\/rpc\/([^?]+)/),name=rm&&rm[1];
  if(name==='aos_ventas_admin'||name==='aos_ventas_admin_anio'){
    return strongSalesRead(url,init,name,parseBody(init));
  }
  return previousFetch(input,init);
};

function run(){cleanCajaClosedState();}
run();

try{
  var obs=new MutationObserver(function(){run();});
  obs.observe(document.documentElement||document.body,{childList:true,subtree:true});
}catch(e){}
})();
