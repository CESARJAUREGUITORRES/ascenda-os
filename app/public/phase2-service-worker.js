// ASCENDA OS Phase 2/F4/F9/WA-S14/S15.1/REV-F6.0 — controlled-write + revenue + Sentinel + actor-bound notification/patient-history bridge.
'use strict';
self.addEventListener('install',function(){self.skipWaiting();});
self.addEventListener('activate',function(e){e.waitUntil(self.clients.claim());});
self.addEventListener('message',function(e){if(e&&e.data&&e.data.type==='ASCENDA_ACTIVATE_NOW')self.skipWaiting();});

function appClients(){return self.clients.matchAll({type:'window',includeUncontrolled:true}).then(function(list){return list.filter(function(c){try{var u=new URL(c.url);return u.origin===self.location.origin&&(u.pathname==='/app'||u.pathname==='/app.html');}catch(_){return false;}});});}
function pushData(d){var x=Object.assign({},d&&d.data||{});x.kind='AOS_PUSH';x.version=String(d&&d.version||'AOS_PUSH_V1');x.channel=String(d&&d.channel||'');x.route=String(d&&d.route||'/app.html');x.entityId=String(d&&d.entity_id||x.entityId||'');if(x.channel==='WHATSAPP'&&!x.conversationId)x.conversationId=x.entityId;return x;}
self.addEventListener('push',function(event){
  var payload=null;try{payload=event.data?event.data.json():null;}catch(_){try{payload=JSON.parse(event.data&&event.data.text?event.data.text():'{}');}catch(__){payload=null;}}
  if(!payload||payload.version!=='AOS_PUSH_V1')return;
  event.waitUntil(appClients().then(function(list){
    if(list.length){list.forEach(function(c){try{c.postMessage({type:'AOS_PUSH_EVENT',payload:payload});}catch(_){}});return null;}
    var title=String(payload.title||'ASCENDA'),opts={body:String(payload.body||''),icon:String(payload.icon||'/icons/icon-192x192.png'),badge:String(payload.badge||'/icons/icon-192x192.png'),tag:String(payload.tag||('aos-push-'+Date.now())),renotify:true,silent:false,data:pushData(payload)};
    return self.registration.showNotification(title,opts);
  }));
});

self.addEventListener('notificationclick',function(event){
  var n=event.notification,d=n&&n.data||{};if(!d)return;
  var isWa=d.kind==='AOS_WA_HUMAN'||(d.kind==='AOS_PUSH'&&d.channel==='WHATSAPP');
  var id=String(d.conversationId||d.entityId||''),view=String(d.view||'admin-whatsapp'),route=String(d.route||'/app.html');
  if(isWa&&route.indexOf('#')<0)route='/app.html#'+encodeURIComponent(view);
  try{n.close();}catch(_){}
  event.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(function(list){
    var target=null;for(var i=0;i<list.length;i++){try{var u=new URL(list[i].url);if(u.origin===self.location.origin){target=list[i];break;}}catch(_){}}
    if(target){
      try{if(isWa)target.postMessage({type:'AOS_WA_OPEN_CONVERSATION',conversationId:id,view:view});else target.postMessage({type:'AOS_PUSH_OPEN',route:route,entityId:id,channel:d.channel||''});}catch(_){}
      return target.focus().then(function(){try{if(!isWa&&target.navigate)return target.navigate(route);}catch(_){}return target;});
    }
    var openRoute=route;
    if(isWa&&id){var sep=openRoute.indexOf('?')>=0?'&':'?';var hash='',hi=openRoute.indexOf('#');if(hi>=0){hash=openRoute.slice(hi);openRoute=openRoute.slice(0,hi);}openRoute+=sep+'wa_conv='+encodeURIComponent(id)+hash;}
    return self.clients.openWindow?self.clients.openWindow(openRoute):null;
  }));
});

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
async function notificationApi(path,method,body){
  var t=String(await getToken()).trim();if(t.length<32)return json({ok:false,error:'NOTIFICATION_APP_SESSION_REQUIRED'},401);
  var h=new Headers({'Accept':'application/json','X-AOS-App-Token':t});
  var opts={method:method||'GET',headers:h,cache:'no-store',credentials:'same-origin'};
  if(body!==undefined){h.set('Content-Type','application/json');opts.body=JSON.stringify(body);}
  try{return await fetch(self.location.origin+path,opts);}catch(_){return json({ok:false,error:'NOTIFICATION_BRIDGE_UNAVAILABLE'},503);}
}

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
    tags+='<script src="/wa-shell-integration.js?v=20260817-wa-shell-p03"></script>';
  }
  if(html.indexOf('/wa-native-layout-s9.js')<0){
    tags+='<script src="/wa-native-layout-s9.js?v=20260817-wa-layout-s9-p01"></script>';
  }
  if(html.indexOf('/wa-chat-ux-s13.js')<0){
    tags+='<script src="/wa-chat-ux-s13.js?v=20260817-wa-chat-s13-p01"></script>';
  }
  if(html.indexOf('/wa-human-alerts.js')<0){
    tags+='<script src="/wa-human-alerts.js?v=20260817-wa-alerts-s14-p01"></script>';
  }
  if(html.indexOf('/notification-push-s14.js')<0){
    tags+='<script src="/notification-push-s14.js?v=20260817-push-s15-auth-p02"></script>';
  }
  if(html.indexOf('/sentinel-inapp-notifications.js')<0){
    tags+='<script src="/sentinel-inapp-notifications.js?v=20260816-f9-inapp-v1"></script>';
  }
  if(tags){html=html.indexOf('</body>')>=0?html.replace('</body>',tags+'</body>'):html+tags;}
  var h=new Headers(r.headers);h.set('Cache-Control','no-store, no-cache, must-revalidate');h.delete('content-length');
  return new Response(html,{status:r.status,statusText:r.statusText,headers:h});
}

async function injectEmbeddedWa(req){
  var r=await fetch(req,{cache:'no-store'});if(!r.ok)return r;
  var type=(r.headers.get('content-type')||'').toLowerCase();if(type.indexOf('text/html')<0)return r;
  var html=await r.text();
  if(html.indexOf('/wa-native-bootstrap-prelude.js')<0){
    var tag='<script src="/wa-native-bootstrap-prelude.js?v=20260817-s5-p01"></script>\n';
    var marker='<script>\n(function(){\'use strict\';';
    if(html.indexOf(marker)>=0)html=html.replace(marker,tag+marker);
    else if(html.indexOf('</head>')>=0)html=html.replace('</head>',tag+'</head>');
    else html=tag+html;
  }
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
  if(u.origin===self.location.origin&&req.method==='GET'&&req.mode==='navigate'&&u.pathname==='/admin-whatsapp.html'&&u.searchParams.get('embedded')==='1'){
    event.respondWith(injectEmbeddedWa(req));return;
  }
  // A direct WA-3 page is now a compatibility entrypoint. Normal navigation is
  // returned to the canonical ASCENDA shell; the embedded iframe bypasses this.
  if(u.origin===self.location.origin&&req.method==='GET'&&req.mode==='navigate'&&u.pathname==='/admin-whatsapp.html'&&u.searchParams.get('embedded')!=='1'){
    event.respondWith(Response.redirect(u.origin+'/app.html#admin-whatsapp',302));return;
  }
  // Same-origin governed APIs use the already-controlled Phase 2 token cache.
  if(u.origin===self.location.origin&&(u.pathname.indexOf('/api/wa3/')===0||u.pathname.indexOf('/api/wa/')===0||u.pathname.indexOf('/api/push/')===0||u.pathname.indexOf('/api/notifications/')===0)){
    event.respondWith(injectSameOriginAppToken(req));return;
  }
  if(u.hostname.indexOf('supabase.co')<0)return;

  var rm=u.pathname.match(/\/rest\/v1\/rpc\/([^/]+)$/);
  // Existing app-shell bell still calls these legacy RPC names. Keep its UI contract,
  // but bind identity to the verified application token through F17 instead of trusting p_id_asesor.
  if(rm&&rm[1]==='aos_list_notificaciones'){
    event.respondWith(notificationApi('/api/notifications/inbox?limit=30','GET'));return;
  }
  if(rm&&rm[1]==='aos_mark_notif_read'){
    event.respondWith((async function(){var p=await requestJson(req);return notificationApi('/api/notifications/read','POST',{id:p.p_id});})());return;
  }
  // REV-F6.0: keep the legacy Citas UI contract, but never let browser roles execute
  // the legacy SECURITY DEFINER Patient 360 RPC. Bind the read to Auth V3 + 2FA and
  // return only the minimum commercial history consumed by the Citas panel.
  if(rm&&rm[1]==='aos_paciente_360'){
    event.respondWith((async function(){
      var p=await requestJson(req),t=String(await getToken()).trim();
      if(t.length<32)return json({ok:false,error:'PATIENT_HISTORY_APP_SESSION_REQUIRED'},401);
      return rpcFrom(req,'aos_patient_history_summary_v1',{p_token:t,p_numero:p.p_numero||''});
    })());return;
  }
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