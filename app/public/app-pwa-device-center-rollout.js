(function(){
'use strict';
var PANEL_ID='devices-notifications';
var tries=0;
function normalizePanels(v){
  if(Array.isArray(v))return v.slice();
  if(typeof v==='string'){try{var p=JSON.parse(v);return Array.isArray(p)?p:[];}catch(_){return [];}}
  return [];
}
function persistPanels(p){
  try{
    var s=JSON.parse(localStorage.getItem('aos_session')||'{}');
    s.paneles_acceso=p;
    localStorage.setItem('aos_session',JSON.stringify(s));
  }catch(_){}
}
function repairAdminDeviceCenter(){
  tries++;
  if(!window.AOS||!AOS.ctx||AOS.role!=='ADMIN'){
    if(tries<20)setTimeout(repairAdminDeviceCenter,250);
    return;
  }
  var p=normalizePanels(AOS.ctx.paneles_acceso);
  if(p.indexOf(PANEL_ID)<0)p.push(PANEL_ID);
  AOS.ctx.paneles_acceso=p;
  persistPanels(p);
  if(typeof window.buildSidebar==='function'){
    try{window.buildSidebar();}catch(e){console.warn('[APP-PWA] Device Center sidebar rebuild failed',e);}
  }
  var nav=document.getElementById('nav-'+PANEL_ID);
  if(nav){
    nav.setAttribute('data-app-pwa-rollout','20260914-p01');
    return;
  }
  var anchor=document.getElementById('nav-admin-config');
  if(!anchor||!anchor.parentNode)return;
  var item=document.createElement('div');
  item.className='ni';
  item.id='nav-'+PANEL_ID;
  item.setAttribute('data-view',PANEL_ID);
  item.setAttribute('data-app-pwa-rollout','20260914-p01');
  item.innerHTML='<div class="ni-ico">🔔</div><span class="ni-lbl">Dispositivos y avisos</span>';
  item.addEventListener('click',function(){
    if(typeof window.navigateTo==='function')window.navigateTo(PANEL_ID);
  });
  anchor.parentNode.insertBefore(item,anchor.nextSibling);
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',repairAdminDeviceCenter);
else repairAdminDeviceCenter();
setTimeout(repairAdminDeviceCenter,1000);
})();