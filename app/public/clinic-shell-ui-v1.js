/* ASCENDA CLINIC — SHELL UI V1.3
   Presentation-only adapter. Existing drawer navigation and business behavior remain authoritative. */
(function(){
'use strict';
if(window.__ASCENDA_CLINIC_UI_V13__)return;
window.__ASCENDA_CLINIC_UI_V11__=true;

function q(s,r){return (r||document).querySelector(s)}
function isCompactDevice(){
  if(!window.matchMedia)return innerWidth<=820;
  var narrow=window.matchMedia('(max-width:820px)').matches;
  var touchLandscape=window.matchMedia('(max-width:1200px)').matches &&
    (window.matchMedia('(pointer:coarse)').matches||window.matchMedia('(hover:none)').matches);
  return narrow||touchLandscape;
}
function setDeviceClasses(){
  var root=document.documentElement;
  var compact=isCompactDevice();
  root.classList.toggle('clinic-compact-ui',compact);
  root.classList.toggle('clinic-landscape',compact&&innerWidth>innerHeight);
  return compact;
}
function canonicalBrand(){
  document.title='Ascenda Clinic';
  var apple=q('meta[name="apple-mobile-web-app-title"]');
  if(apple)apple.setAttribute('content','Ascenda Clinic');
  var brand=q('#tb-brand .bn-txt');
  if(brand&&brand.dataset.clinic!=='11'){
    brand.dataset.clinic='11';
    brand.innerHTML='Ascenda<span>Clinic</span>';
  }
}
function ensureHomeHero(){
  var root=q('#workspace .ah');
  var existing=root&&q('.clinic-home-hero',root);
  if(!isCompactDevice()){
    if(existing)existing.remove();
    return;
  }
  if(!root||existing)return;
  var h=document.createElement('section');
  h.className='clinic-home-hero';
  h.setAttribute('aria-label','Bienvenida Ascenda Clinic');
  h.innerHTML='<div class="clinic-home-copy"><div class="clinic-home-eyebrow">ASCENDA CLINIC</div><div class="clinic-home-title">Bienvenido de nuevo</div><div class="clinic-home-sub">Gestiona, controla y haz crecer tu clínica desde un solo lugar.</div></div><div class="clinic-home-mark" aria-hidden="true"><span></span><span></span><span></span><span></span></div>';
  root.insertBefore(h,root.firstChild);
}
function applyPanelClass(){
  var ws=q('#workspace');if(!ws)return;
  var active=(window.AOS&&AOS.activeView)?String(AOS.activeView):'';
  if(active)ws.setAttribute('data-active-view',active);else ws.removeAttribute('data-active-view');
  var child=ws.firstElementChild;
  if(child)child.classList.add('clinic-responsive-panel');
  ensureHomeHero();
}
function mobileDefault(){
  if(!isCompactDevice())return;
  var sb=q('#sidebar'),brand=q('#tb-brand');
  if(!sb||!brand)return;
  if(!sessionStorage.getItem('aos_mobile_drawer_initialized_v11')){
    sessionStorage.setItem('aos_mobile_drawer_initialized_v11','1');
    if(!sb.classList.contains('col')){
      sb.classList.add('col');
      brand.classList.add('col');
      if(window.AOS)AOS.collapsed=true;
    }
  }
}
function reconcileViewport(){
  setDeviceClasses();
  canonicalBrand();
  if(isCompactDevice())mobileDefault();
  applyPanelClass();
}
function installBookingV32AdvisorLink(){
  if(window.__ASCENDA_BOOKING_V32_MODAL_PATCH__)return;
  if(typeof window.openAgendarModal!=='function'||typeof window.rpc!=='function')return;
  var original=window.openAgendarModal;
  window.openAgendarModal=function(){
    original.apply(this,arguments);
    var code=window.AOS&&AOS.ctx?String(AOS.ctx.idAsesor||'').trim():'';
    if(!code)return;
    window.rpc('aos_booking_advisor_permanent_link_v32',{p_asesor:code}).then(function(r){
      if(!r||!r.ok||!r.token)return;
      var url=window.location.origin+'/agendar?t='+encodeURIComponent(r.token);
      if(typeof window.mostrarLinkGenerado==='function')window.mostrarLinkGenerado(url,false);
      var label=document.querySelector('#agendar-link-result > div');
      if(label)label.textContent='✅ Tu link permanente de asesor';
    }).catch(function(e){console.warn('[BOOKING-V3.2] permanent advisor link unavailable',e)});
  };
  window.__ASCENDA_BOOKING_V32_MODAL_PATCH__=true;
}
function boot(){
  reconcileViewport();
  var ws=q('#workspace');
  if(ws){
    var obs=new MutationObserver(function(){applyPanelClass()});
    obs.observe(ws,{childList:true,subtree:false});
  }
  var timer=0;
  window.addEventListener('resize',function(){clearTimeout(timer);timer=setTimeout(reconcileViewport,80)});
  window.addEventListener('orientationchange',function(){setTimeout(reconcileViewport,120)});
  var bookingPatchTimer=setInterval(function(){installBookingV32AdvisorLink();if(window.__ASCENDA_BOOKING_V32_MODAL_PATCH__)clearInterval(bookingPatchTimer)},250);
  setTimeout(function(){clearInterval(bookingPatchTimer)},10000);
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
})();