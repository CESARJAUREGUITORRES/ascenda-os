/* ASCENDA CIA-PANEL · PACK-B P2 — governed queue-config compatibility bridge.
   Translates legacy aos_cola_config browser GET/PATCH into Auth V3 governed RPCs. */
(function(){
'use strict';
if(window.__ASCENDA_CIA_QUEUE_GATEWAY_V1__)return;
window.__ASCENDA_CIA_QUEUE_GATEWAY_V1__=true;
var nativeFetch=window.fetch.bind(window);
function token(){try{return String(sessionStorage.getItem('aos_app_token')||'').trim()}catch(_){return''}}
function headersFor(input,init){var h=new Headers((init&&init.headers)||((input&&input.headers)||{}));h.set('Content-Type','application/json');h.set('Accept','application/json');h.delete('Prefer');return h}
function queueTarget(input){try{var raw=typeof input==='string'?input:(input&&input.url)||'';var u=new URL(raw,location.href);return u.hostname==='ituyqwstonmhnfshnaqz.supabase.co'&&u.pathname==='/rest/v1/aos_cola_config'?u:null}catch(_){return null}}
function fail(status,msg){return new Response(JSON.stringify({ok:false,error:msg||'CIA_QUEUE_GATEWAY_ERROR'}),{status:status||503,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}})}
window.fetch=function(input,init){
  var u=queueTarget(input);if(!u)return nativeFetch(input,init);
  var method=String((init&&init.method)||((input&&input.method)||'GET')).toUpperCase();
  var t=token();if(t.length<32){console.warn('[CIA-P2] queue gateway requires Auth V3 token');return Promise.resolve(method==='GET'?new Response('[]',{status:401,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}}):fail(401,'APP_SESSION_REQUIRED'))}
  var h=headersFor(input,init);
  if(method==='GET'){
    return nativeFetch(u.origin+'/rest/v1/rpc/aos_cia_queue_config_list_admin_v1',{method:'POST',headers:h,body:JSON.stringify({p_token:t}),cache:'no-store'}).then(function(r){return r.json().then(function(d){if(!r.ok||!d||d.ok!==true){console.warn('[CIA-P2] queue list rejected',d&&d.error);return new Response('[]',{status:r.status||403,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}})}var rows=Array.isArray(d.rows)?d.rows:[];var f=u.searchParams.get('asesor')||'';if(f.indexOf('eq.')===0){var a=f.slice(3).toUpperCase();rows=rows.filter(function(x){return String(x.asesor||'').toUpperCase()===a})}return new Response(JSON.stringify(rows),{status:200,headers:{'Content-Type':'application/json','Cache-Control':'no-store','X-Ascenda-CIA':'queue-gateway-v1'}})})}).catch(function(e){console.warn('[CIA-P2] queue list unavailable',e&&e.message);return new Response('[]',{status:503,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}})})
  }
  if(method==='PATCH'){
    var body={};try{body=JSON.parse((init&&init.body)||'{}')}catch(_){return Promise.resolve(fail(400,'INVALID_QUEUE_PAYLOAD'))}
    var f=u.searchParams.get('asesor')||'';var asesor=f.indexOf('eq.')===0?f.slice(3):'';
    return nativeFetch(u.origin+'/rest/v1/rpc/aos_cia_queue_config_set_admin_v1',{method:'POST',headers:h,body:JSON.stringify({p_token:t,p_asesor:asesor,p_tipo_cola:body.tipo_cola||'global',p_filtro_valor:body.filtro_valor||''}),cache:'no-store'}).then(function(r){return r.json().then(function(d){if(!r.ok||!d||d.ok!==true)return fail(r.status||403,(d&&d.error)||'QUEUE_UPDATE_REJECTED');return new Response('',{status:204,headers:{'Cache-Control':'no-store','X-Ascenda-CIA':'queue-gateway-v1'}})})}).catch(function(e){return fail(503,(e&&e.message)||'QUEUE_GATEWAY_UNAVAILABLE')})
  }
  return Promise.resolve(fail(405,'QUEUE_METHOD_NOT_ALLOWED'));
};
})();
