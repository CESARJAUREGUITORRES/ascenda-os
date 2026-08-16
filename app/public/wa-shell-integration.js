// ASCENDA Conversations — mount WA-3 inside the canonical ASCENDA shell.
(function(){
'use strict';
var BOOT_TRIES=0,BOOT_MAX=50;

function contains(arr,id){return Array.isArray(arr)&&arr.some(function(x){return x&&x.type==='item'&&x.id===id;});}
function insertAfter(arr,afterId,item){
  if(!Array.isArray(arr)||contains(arr,item.id))return;
  var idx=arr.findIndex(function(x){return x&&x.type==='item'&&x.id===afterId;});
  if(idx<0)arr.push(item);else arr.splice(idx+1,0,item);
}
function perms(){try{return (window.AOS&&AOS.ctx&&Array.isArray(AOS.ctx.paneles_acceso))?AOS.ctx.paneles_acceso:[];}catch(e){return [];}}
function allowed(viewId){
  var p=perms(),ctx=(window.AOS&&AOS.ctx)||{};
  if(viewId==='admin-whatsapp')return AOS.role==='ADMIN'&&Number(ctx.nivel||99)<=2&&p.indexOf('admin-whatsapp')>=0;
  if(viewId==='whatsapp-agent')return p.indexOf('whatsapp-agent')>=0;
  return false;
}
function markActive(viewId){
  document.querySelectorAll('.ni').forEach(function(n){n.classList.remove('act-asesor','act-admin');});
  var nd=document.getElementById('nav-'+viewId);
  if(nd)nd.classList.add(AOS.role==='ADMIN'?'act-admin':'act-asesor');
}
function mountWhatsApp(viewId){
  if(!allowed(viewId)){
    return window.__AOS_WA_BASE_NAV(AOS.role==='ADMIN'?'admin-home':'advisor-home');
  }
  if(AOS.activeView===viewId)return;
  AOS.activeView=viewId;
  markActive(viewId);
  var ws=document.getElementById('workspace');
  if(!ws)return;
  try{if(typeof window.aosCleanupPanelRuntime==='function')window.aosCleanupPanelRuntime();}catch(e){}
  ws.innerHTML='<iframe id="aos-wa-workspace" title="ASCENDA WhatsApp" src="/admin-whatsapp.html?embedded=1" style="display:block;width:100%;height:100%;border:0;background:#f2f5fb" referrerpolicy="same-origin"></iframe>';
  var frame=document.getElementById('aos-wa-workspace');
  frame.addEventListener('load',function(){
    try{
      var d=frame.contentDocument;
      if(!d)return;
      var top=d.querySelector('.top');if(top)top.style.display='none';
      var layout=d.querySelector('.layout');if(layout)layout.style.height='100%';
      var notice=d.querySelector('.notice');if(notice)notice.style.top='10px';
      d.documentElement.style.height='100%';d.body.style.height='100%';
    }catch(e){console.warn('[AOS-WA-SHELL] embed styling skipped',e);}
  });
}
function boot(){
  BOOT_TRIES++;
  if(!window.AOS||!AOS.ctx||typeof window.buildSidebar!=='function'||typeof window.navigateTo!=='function'){
    if(BOOT_TRIES<BOOT_MAX)setTimeout(boot,100);
    return;
  }
  var p=perms();
  insertAfter(window.SIDEBAR_ADMIN,'admin-calls',{type:'item',id:'admin-whatsapp',ico:'chat',lbl:'WhatsApp Hub',requiresPanel:true,badge:'',badgeColor:'#16A34A'});
  if(p.indexOf('whatsapp-agent')>=0){
    insertAfter(window.SIDEBAR_ASESOR,'advisor-calls',{type:'item',id:'whatsapp-agent',ico:'chat',lbl:'WhatsApp',badge:'',badgeColor:'#16A34A'});
  }
  if(window.VIEW_MAP){VIEW_MAP['admin-whatsapp']='ViewWhatsApp';VIEW_MAP['whatsapp-agent']='ViewWhatsApp';}
  if(!window.__AOS_WA_BASE_NAV){
    window.__AOS_WA_BASE_NAV=window.navigateTo;
    var wrapped=function(viewId){
      if(viewId==='admin-whatsapp'||viewId==='whatsapp-agent')return mountWhatsApp(viewId);
      return window.__AOS_WA_BASE_NAV(viewId);
    };
    wrapped.__waShellWrapped=true;
    window.navigateTo=wrapped;
  }
  window.buildSidebar();
  var hash=String(location.hash||'').replace(/^#/,'');
  if(hash==='admin-whatsapp'||hash==='whatsapp-agent'){
    setTimeout(function(){window.navigateTo(hash);},0);
  }
}
boot();
})();
