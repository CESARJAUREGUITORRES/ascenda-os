/* ASCENDA CLINIC — SHELL UI V1
   Presentation-only adapter. Keeps existing drawer navigation and business logic intact. */
(function(){
'use strict';
if(window.__ASCENDA_CLINIC_UI_V1__)return;
window.__ASCENDA_CLINIC_UI_V1__=true;

function q(s,r){return (r||document).querySelector(s)}
function qa(s,r){return Array.prototype.slice.call((r||document).querySelectorAll(s))}
function isMobile(){return window.matchMedia&&window.matchMedia('(max-width:820px)').matches}

function canonicalBrand(){
  document.title='Ascenda Clinic';
  var apple=q('meta[name="apple-mobile-web-app-title"]');
  if(apple)apple.setAttribute('content','Ascenda Clinic');
  var brand=q('#tb-brand .bn-txt');
  if(brand&&brand.dataset.clinic!=='1'){
    brand.dataset.clinic='1';
    brand.innerHTML='Ascenda <span>Clinic</span>';
  }
}

function ensureHomeHero(){
  var root=q('#workspace .ah');
  if(!root||q('.clinic-home-hero',root))return;
  var h=document.createElement('section');
  h.className='clinic-home-hero';
  h.setAttribute('aria-label','Bienvenida Ascenda Clinic');
  h.innerHTML='<div class="clinic-home-copy"><div class="clinic-home-eyebrow">ASCENDA CLINIC</div><div class="clinic-home-title">Bienvenido de nuevo</div><div class="clinic-home-sub">Gestiona, controla y haz crecer tu clínica desde un solo lugar.</div></div><div class="clinic-home-mark" aria-hidden="true"><span></span><span></span><span></span><span></span></div>';
  root.insertBefore(h,root.firstChild);
}

function applyPanelClass(){
  var ws=q('#workspace');if(!ws)return;
  var child=ws.firstElementChild;
  if(!child)return;
  child.classList.add('clinic-responsive-panel');
  ensureHomeHero();
}

function mobileDefault(){
  if(!isMobile())return;
  var sb=q('#sidebar'),brand=q('#tb-brand');
  if(!sb||!brand)return;
  if(!sessionStorage.getItem('aos_mobile_drawer_initialized')){
    sessionStorage.setItem('aos_mobile_drawer_initialized','1');
    if(!sb.classList.contains('col')){
      sb.classList.add('col');
      brand.classList.add('col');
      if(window.AOS)AOS.collapsed=true;
    }
  }
}

function boot(){
  canonicalBrand();
  mobileDefault();
  applyPanelClass();
  var ws=q('#workspace');
  if(ws){
    var obs=new MutationObserver(function(){applyPanelClass()});
    obs.observe(ws,{childList:true,subtree:false});
  }
  window.addEventListener('resize',function(){canonicalBrand()});
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
})();