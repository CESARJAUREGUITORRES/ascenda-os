// ASCENDA OS Phase 2 — app-wide controlled-write bridge.
'use strict';
self.addEventListener('install',function(){self.skipWaiting();});
self.addEventListener('activate',function(e){e.waitUntil(self.clients.claim());});

var PROTECTED={aos_catalogo_categorias:1,aos_catalogo_servicios:1,aos_catalogo_toppings:1,aos_catalogo_productos_detalle:1,aos_planes_trabajo:1,aos_plan_trabajo_items:1};
var CAJA={aos_caja_abrir:'aos_caja_abrir_v2',aos_caja_cerrar:'aos_caja_cerrar_v2',aos_caja_editar_pago:'aos_caja_editar_pago_v2',aos_caja_eliminar_venta:'aos_caja_eliminar_venta_v2',aos_caja_ingreso_extra:'aos_caja_ingreso_extra_v2',aos_caja_registrar_gasto:'aos_caja_registrar_gasto_v2'};

async function getToken(){try{var c=await caches.open('aos-phase2-auth');var r=await c.match('/__aos_app_token');return r?await r.text():'';}catch(e){return '';}}
function json(obj,status){return new Response(JSON.stringify(obj),{status:status||200,headers:{'Content-Type':'application/json'}});}
function isMissing(r){return r.status===404||r.status===400;}
function parseMatch(u){var out={};u.searchParams.forEach(function(v,k){if(k==='select'||k==='order'||k==='limit'||k==='offset')return;if(String(v).indexOf('eq.')!==0)throw new Error('FILTER_NOT_ALLOWED');out[k]=String(v).slice(3);});return out;}
async function requestJson(req){try{return await req.clone().json();}catch(e){return {};}}
async function rpcFrom(req,name,payload){var u=new URL(req.url);var target=u.origin+'/rest/v1/rpc/'+name;var h=new Headers(req.headers);h.set('Content-Type','application/json');return fetch(target,{method:'POST',headers:h,body:JSON.stringify(payload),credentials:req.credentials,mode:req.mode==='navigate'?'cors':req.mode,cache:'no-store'});}

self.addEventListener('fetch',function(event){
  var req=event.request,u;
  try{u=new URL(req.url);}catch(e){return;}
  if(u.hostname.indexOf('supabase.co')<0)return;

  var rm=u.pathname.match(/\/rest\/v1\/rpc\/([^/]+)$/);
  if(rm&&CAJA[rm[1]]){
    event.respondWith((async function(){
      var p=await requestJson(req);p.p_token=await getToken();delete p.p_usuario;
      var r=await rpcFrom(req,CAJA[rm[1]],p);if(isMissing(r))return fetch(req);return r;
    })());return;
  }

  var tm=u.pathname.match(/\/rest\/v1\/([^/]+)$/),table=tm&&tm[1],method=req.method.toUpperCase();
  if(table&&PROTECTED[table]&&(method==='POST'||method==='PATCH'||method==='DELETE')){
    event.respondWith((async function(){
      var match;try{match=parseMatch(u);}catch(e){return json({ok:false,error:'FILTER_NOT_ALLOWED'},403);}
      var payload={p_token:await getToken(),p_table:table,p_action:method==='POST'?'INSERT':method,p_match:match,p_data:method==='DELETE'?{}:await requestJson(req)};
      var r=await rpcFrom(req,'aos_secure_write_v2',payload);if(isMissing(r))return fetch(req);
      var d;try{d=await r.json();}catch(e){return json({ok:false,error:'WRITE_REJECTED'},500);}
      if(!d||d.ok===false)return json(d||{ok:false,error:'WRITE_REJECTED'},403);
      return json(d.rows||[],200);
    })());
  }
});
