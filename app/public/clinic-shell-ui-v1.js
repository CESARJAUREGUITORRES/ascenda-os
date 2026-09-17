/* ASCENDA CLINIC — SHELL UI V1.3
   Shared responsive shell plus governed compatibility bridges. */
(function(){
'use strict';
if(window.__ASCENDA_CLINIC_UI_V13__)return;
window.__ASCENDA_CLINIC_UI_V13__=true;
window.__ASCENDA_CLINIC_UI_V11__=true;
function q(s,r){return (r||document).querySelector(s)}
function isCompactDevice(){if(!window.matchMedia)return innerWidth<=820;var narrow=window.matchMedia('(max-width:820px)').matches;var touchLandscape=window.matchMedia('(max-width:1200px)').matches&&(window.matchMedia('(pointer:coarse)').matches||window.matchMedia('(hover:none)').matches);return narrow||touchLandscape}
function setDeviceClasses(){var root=document.documentElement;var compact=isCompactDevice();root.classList.toggle('clinic-compact-ui',compact);root.classList.toggle('clinic-landscape',compact&&innerWidth>innerHeight);return compact}
function canonicalBrand(){document.title='Ascenda Clinic';var apple=q('meta[name="apple-mobile-web-app-title"]');if(apple)apple.setAttribute('content','Ascenda Clinic');var brand=q('#tb-brand .bn-txt');if(brand&&brand.dataset.clinic!=='11'){brand.dataset.clinic='11';brand.innerHTML='Ascenda<span>Clinic</span>'}}
function ensureHomeHero(){var root=q('#workspace .ah');var existing=root&&q('.clinic-home-hero',root);if(!isCompactDevice()){if(existing)existing.remove();return}if(!root||existing)return;var h=document.createElement('section');h.className='clinic-home-hero';h.setAttribute('aria-label','Bienvenida Ascenda Clinic');h.innerHTML='<div class="clinic-home-copy"><div class="clinic-home-eyebrow">ASCENDA CLINIC</div><div class="clinic-home-title">Bienvenido de nuevo</div><div class="clinic-home-sub">Gestiona, controla y haz crecer tu clínica desde un solo lugar.</div></div><div class="clinic-home-mark" aria-hidden="true"><span></span><span></span><span></span><span></span></div>';root.insertBefore(h,root.firstChild)}
function applyPanelClass(){var ws=q('#workspace');if(!ws)return;var active=(window.AOS&&AOS.activeView)?String(AOS.activeView):'';if(active)ws.setAttribute('data-active-view',active);else ws.removeAttribute('data-active-view');var child=ws.firstElementChild;if(child)child.classList.add('clinic-responsive-panel');ensureHomeHero()}
function mobileDefault(){if(!isCompactDevice())return;var sb=q('#sidebar'),brand=q('#tb-brand');if(!sb||!brand)return;if(!sessionStorage.getItem('aos_mobile_drawer_initialized_v11')){sessionStorage.setItem('aos_mobile_drawer_initialized_v11','1');if(!sb.classList.contains('col')){sb.classList.add('col');brand.classList.add('col');if(window.AOS)AOS.collapsed=true}}}
function reconcileViewport(){setDeviceClasses();canonicalBrand();if(isCompactDevice())mobileDefault();applyPanelClass()}
function installCiaQueueGatewayBridgeV1(){
  if(window.__ASCENDA_CIA_QUEUE_GATEWAY_V1__)return;
  window.__ASCENDA_CIA_QUEUE_GATEWAY_V1__=true;
  var nativeFetch=window.fetch.bind(window);
  function token(){try{return String(sessionStorage.getItem('aos_app_token')||'').trim()}catch(_){return''}}
  function headersFor(input,init){var h=new Headers((init&&init.headers)||((input&&input.headers)||{}));h.set('Content-Type','application/json');h.set('Accept','application/json');h.delete('Prefer');return h}
  function queueTarget(input){try{var raw=typeof input==='string'?input:(input&&input.url)||'';var u=new URL(raw,location.href);return u.hostname==='ituyqwstonmhnfshnaqz.supabase.co'&&u.pathname==='/rest/v1/aos_cola_config'?u:null}catch(_){return null}}
  function fail(status,msg){return new Response(JSON.stringify({ok:false,error:msg||'CIA_QUEUE_GATEWAY_ERROR'}),{status:status||503,headers:{'Content-Type':'application/json'}})}
  window.fetch=function(input,init){
    var u=queueTarget(input);if(!u)return nativeFetch(input,init);
    var method=String((init&&init.method)||((input&&input.method)||'GET')).toUpperCase();
    var t=token();if(t.length<32){console.warn('[CIA-P2] queue gateway requires Auth V3 token');return Promise.resolve(method==='GET'?new Response('[]',{status:401,headers:{'Content-Type':'application/json'}}):fail(401,'APP_SESSION_REQUIRED'))}
    var h=headersFor(input,init);
    if(method==='GET'){
      return nativeFetch(u.origin+'/rest/v1/rpc/aos_cia_queue_config_list_admin_v1',{method:'POST',headers:h,body:JSON.stringify({p_token:t}),cache:'no-store'}).then(function(r){return r.json().then(function(d){if(!r.ok||!d||d.ok!==true){console.warn('[CIA-P2] queue list rejected',d&&d.error);return new Response('[]',{status:r.status||403,headers:{'Content-Type':'application/json'}})}var rows=Array.isArray(d.rows)?d.rows:[];var f=u.searchParams.get('asesor')||'';if(f.indexOf('eq.')===0){var a=f.slice(3).toUpperCase();rows=rows.filter(function(x){return String(x.asesor||'').toUpperCase()===a})}return new Response(JSON.stringify(rows),{status:200,headers:{'Content-Type':'application/json','X-Ascenda-CIA':'queue-gateway-v1'}})})}).catch(function(e){console.warn('[CIA-P2] queue list unavailable',e&&e.message);return new Response('[]',{status:503,headers:{'Content-Type':'application/json'}})})
    }
    if(method==='PATCH'){
      var body={};try{body=JSON.parse((init&&init.body)||'{}')}catch(_){return Promise.resolve(fail(400,'INVALID_QUEUE_PAYLOAD'))}
      var f=u.searchParams.get('asesor')||'';var asesor=f.indexOf('eq.')===0?f.slice(3):'';
      return nativeFetch(u.origin+'/rest/v1/rpc/aos_cia_queue_config_set_admin_v1',{method:'POST',headers:h,body:JSON.stringify({p_token:t,p_asesor:asesor,p_tipo_cola:body.tipo_cola||'global',p_filtro_valor:body.filtro_valor||''}),cache:'no-store'}).then(function(r){return r.json().then(function(d){if(!r.ok||!d||d.ok!==true)return fail(r.status||403,(d&&d.error)||'QUEUE_UPDATE_REJECTED');return new Response('',{status:204,headers:{'X-Ascenda-CIA':'queue-gateway-v1'}})})}).catch(function(e){return fail(503,(e&&e.message)||'QUEUE_GATEWAY_UNAVAILABLE')})
    }
    return Promise.resolve(fail(405,'QUEUE_METHOD_NOT_ALLOWED'));
  };
}
function installBookingLinkCenterV38(){
  if(window.__ASCENDA_BOOKING_V38_LOADER__)return;
  window.__ASCENDA_BOOKING_V38_LOADER__=true;
  var s=document.createElement('script');
  s.src='/booking-link-center-v37.js?v=20260916-v38';
  s.async=false;
  s.onerror=function(){window.__ASCENDA_BOOKING_V38_LOADER__=false;console.warn('[BOOKING-V3.8] link center asset unavailable');};
  document.head.appendChild(s);
}
function installCoordV7(){
  if(window.__ASCENDA_COORD_V72_LOADER__)return;
  window.__ASCENDA_COORD_V72_LOADER__=true;
  var s=document.createElement('script');
  s.src='/coord-lock-search-v1.js?v=20260916-v72';
  s.async=false;
  s.onerror=function(){window.__ASCENDA_COORD_V72_LOADER__=false;console.warn('[COORD-V7.2] asset unavailable');};
  document.head.appendChild(s);
}
function boot(){reconcileViewport();var ws=q('#workspace');if(ws){var obs=new MutationObserver(function(){applyPanelClass()});obs.observe(ws,{childList:true,subtree:false})}var timer=0;window.addEventListener('resize',function(){clearTimeout(timer);timer=setTimeout(reconcileViewport,80)});window.addEventListener('orientationchange',function(){setTimeout(reconcileViewport,120)});installBookingLinkCenterV38();installCoordV7()}
installCiaQueueGatewayBridgeV1();
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
})();