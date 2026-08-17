// ASCENDA OS Phase 2/F4/F9 — app-wide controlled-write + revenue operations + Sentinel owner notification bridge.
'use strict';
self.addEventListener('install',function(){self.skipWaiting();});
self.addEventListener('activate',function(e){e.waitUntil(self.clients.claim());});
self.addEventListener('message',function(e){if(e&&e.data&&e.data.type==='ASCENDA_ACTIVATE_NOW')self.skipWaiting();});

var PROTECTED={aos_catalogo_categorias:1,aos_catalogo_servicios:1,aos_catalogo_toppings:1,aos_catalogo_productos_detalle:1,aos_planes_trabajo:1,aos_plan_trabajo_items:1};
var CAJA={aos_caja_abrir:'aos_caja_abrir_v2',aos_caja_cerrar:'aos_caja_cerrar_v2',aos_caja_editar_pago:'aos_caja_editar_pago_v2',aos_caja_eliminar_venta:'aos_caja_eliminar_venta_v2',aos_caja_ingreso_extra:'aos_caja_ingreso_extra_v2',aos_caja_registrar_gasto:'aos_caja_registrar_gasto_v2'};
var IDENTITY={aos_admin_crear_usuario:'aos_admin_crear_usuario_v3',aos_admin_cambiar_password:'aos_admin_cambiar_password_v3',aos_cambiar_password:'aos_cambiar_password_v3'};
// Cartera reads are intentionally NOT re-proxied here. The production DB keeps
// aos_cartera_gateway as the compatibility read alias to Auth V3 gateway V2.
// Rebuilding the cross-origin request in the service worker caused PostgREST 401
// before the valid application token could be evaluated.

async function getToken(){try{var c=await caches.open('aos-phase2-auth');var r=await c.match('/__aos_app_token');return r?await r.text():'';}catch(e){return '';}}
function json(obj,status){return new Response(JSON.stringify(obj),{status:status||200,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});}
function isMissing(r){return r.status===404||r.status===400;}
function parseMatch(u){var out={};u.searchParams.forEach(function(v,k){if(k==='select'||k==='order'||k==='limit'||k==='offset')return;if(String(v).indexOf('eq.')!==0)throw new Error('FILTER_NOT_ALLOWED');out[k]=String(v).slice(3);});return out;}
async function requestJson(req){try{return await req.clone().json();}catch(e){return {};}}
async function rpcFrom(req,name,payload){var u=new URL(req.url);var target=u.origin+'/rest/v1/rpc/'+name;var h=new Headers(req.headers);h.set('Content-Type','application/json');return fetch(target,{method:'POST',headers:h,body:JSON.stringify(payload),credentials:req.credentials,mode:req.mode==='navigate'?'cors':req.mode,cache:'no-store'});}

async function injectF4(req){
  var r=await fetch(req,{cache:'no-store'});if(!r.ok)return r;
  var type=(r.headers.get('content-type')||'').toLowerCase();if(type.indexOf('text/html')<0)return r;
  var html=await r.text(),tags='';
  if(html.indexOf('/f4-revenue-ops.js')<0){
    tags+='<script src="/f4-revenue-ops.js?v=20260815-f4-canary-p0"></script><script src="/f4-kronia-revenue-bridge.js?v=20260815-f4-canary-p0"></script>';
  }
  if(html.indexOf('/f4-production-canary-hotfix.js')<0){
    tags+='<script src="/f4-production-canary-hotfix.js?v=20260815-f4-sales-auth-p06"></script>';
  }
  if(html.indexOf('/wa-shell-integration.js')<0){
    tags+='<script src="/wa-shell-integration.js?v=20260815-wa-shell-p02"></script>';
  }
  if(html.indexOf('/sentinel-inapp-notifications.js')<0){
    tags+='<script src="/sentinel-inapp-notifications.js?v=20260816-f9-inapp-v1"></script>';
  }
  if(tags){html=html.indexOf('</body>')>=0?html.replace('</body>',tags+'</body>'):html+tags;}
  var h=new Headers(r.headers);h.set('Cache-Control','no-store, no-cache, must-revalidate');h.delete('content-length');
  return new Response(html,{status:r.status,statusText:r.statusText,headers:h});
}

async function injectSameOriginAppToken(req){
  var h=new Headers(req.headers),t=String(await getToken()).trim();
  if(t.length>=32)h.set('X-AOS-App-Token',t);
  return fetch(new Request(req,{headers:h,cache:'no-store'}));
}

self.addEventListener('fetch',function(event){
  var req=event.request,u;
  try{u=new URL(req.url);}catch(e){return;}
  if(u.origin===self.location.origin&&req.method==='GET'&&(u.pathname==='/app'||u.pathname==='/app.html')){event.respondWith(injectF4(req));return;}
  // A direct WA-3 page is now a compatibility entrypoint. Normal navigation is
  // returned to the canonical ASCENDA shell; the embedded iframe bypasses this.
  if(u.origin===self.location.origin&&req.method==='GET'&&req.mode==='navigate'&&u.pathname==='/admin-whatsapp.html'&&u.searchParams.get('embedded')!=='1'){
    event.respondWith(Response.redirect(u.origin+'/app.html#admin-whatsapp',302));return;
  }
  // WA APIs are same-origin and may execute inside the embedded workspace.
  // Inject the already-governed Phase 2 token from the same-origin cache.
  if(u.origin===self.location.origin&&(u.pathname.indexOf('/api/wa3/')===0||u.pathname.indexOf('/api/wa/')===0)){
    event.respondWith(injectSameOriginAppToken(req));return;
  }
  if(u.hostname.indexOf('supabase.co')<0)return;

  var rm=u.pathname.match(/\/rest\/v1\/rpc\/([^/]+)$/);
  if(rm&&IDENTITY[rm[1]]){
    event.respondWith((async function(){var p=await requestJson(req);p.p_token=await getToken();if(rm[1]==='aos_admin_cambiar_password'&&!p.p_usuario_id){return json({ok:false,error:'LEGACY_IDENTITY_FLOW_RETIRED'},403);}if(rm[1]==='aos_cambiar_password')p={p_token:p.p_token,p_password_actual:p.p_password_actual,p_password_nuevo:p.p_password_nuevo};var r=await rpcFrom(req,IDENTITY[rm[1]],p);if(isMissing(r))return fetch(req);return r;})());return;
  }
  if(rm&&CAJA[rm[1]]){
    event.respondWith((async function(){var p=await requestJson(req);p.p_token=await getToken();delete p.p_usuario;var r=await rpcFrom(req,CAJA[rm[1]],p);if(isMissing(r))return fetch(req);return r;})());return;
  }
  var tm=u.pathname.match(/\/rest\/v1\/([^/]+)$/),table=tm&&tm[1],method=req.method.toUpperCase();
  if(table&&PROTECTED[table]&&(method==='POST'||method==='PATCH'||method==='DELETE')){
    event.respondWith((async function(){var match;try{match=parseMatch(u);}catch(e){return json({ok:false,error:'FILTER_NOT_ALLOWED'},403);}var payload={p_token:await getToken(),p_table:table,p_action:method==='POST'?'INSERT':method,p_match:match,p_data:method==='DELETE'?{}:await requestJson(req)};var r=await rpcFrom(req,'aos_secure_write_v2',payload);if(isMissing(r))return fetch(req);var d;try{d=await r.json();}catch(e){return json({ok:false,error:'WRITE_REJECTED'},500);}if(!d||d.ok===false)return json(d||{ok:false,error:'WRITE_REJECTED'},403);return json(d.rows||[],200);})());
  }
});
