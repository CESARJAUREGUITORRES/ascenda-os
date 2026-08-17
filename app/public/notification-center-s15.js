// ASCENDA S15 — unified in-app notification center.
(function(){
'use strict';
if(window.__AOS_NOTIFICATION_CENTER_S15)return;
window.__AOS_NOTIFICATION_CENTER_S15=true;

var CHANNELS={
  WHATSAPP:{emoji:'🟢',label:'WhatsApp'},SALES:{emoji:'💰',label:'Ventas'},COMMISSION:{emoji:'📈',label:'Comisiones'},
  AGENDA:{emoji:'📅',label:'Agenda'},CHAT:{emoji:'💬',label:'Chat'},TASKS:{emoji:'✅',label:'Tareas'},
  SENTINEL:{emoji:'🛡️',label:'Sentinel'},SYSTEM:{emoji:'🔔',label:'ASCENDA'}
};

function E(v){return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
function channel(v){return String(v||'SYSTEM').toUpperCase();}
function meta(v){return CHANNELS[channel(v)]||{emoji:'🔔',label:channel(v)||'ASCENDA'};}
function routeView(route){try{var s=String(route||''),i=s.indexOf('#');if(i<0)return'';return decodeURIComponent(s.slice(i+1).split('?')[0]);}catch(_){return'';}}
function go(route,entityId){
  var view=routeView(route);
  try{if(view&&typeof window.navigateTo==='function'){window.navigateTo(view);return;}}catch(_){}
  try{if(route)location.href=route;}catch(_){}
}
function toast(payload){
  payload=payload||{};var m=meta(payload.channel),old=document.getElementById('_aosUnifiedNotif');if(old)old.remove();
  var d=document.createElement('div');d.id='_aosUnifiedNotif';d.setAttribute('role','status');
  d.style.cssText='position:fixed;top:64px;right:16px;z-index:10050;width:min(390px,calc(100vw - 32px));opacity:0;transform:translateY(-10px);transition:opacity .2s,transform .2s;cursor:pointer';
  d.innerHTML='<div style="background:#fff;border:1px solid #DDE4F5;border-radius:16px;padding:12px 14px;box-shadow:0 12px 36px rgba(7,29,74,.18);display:flex;gap:11px;align-items:flex-start">'+
    '<div style="width:38px;height:38px;border-radius:12px;background:#F0F4FC;display:flex;align-items:center;justify-content:center;font-size:18px;flex-shrink:0">'+m.emoji+'</div>'+
    '<div style="flex:1;min-width:0"><div style="font-size:9px;font-weight:800;color:#6B7BA8;text-transform:uppercase;letter-spacing:.7px">'+E(m.label)+'</div>'+
    '<div style="font-size:12px;font-weight:800;color:#0D1B3E;margin-top:2px">'+E(payload.title||'ASCENDA')+'</div>'+
    '<div style="font-size:10px;color:#6B7BA8;margin-top:3px;line-height:1.4;max-height:42px;overflow:hidden">'+E(payload.body||'')+'</div></div></div>';
  d.onclick=function(){go(payload.route,payload.entity_id);try{d.remove();}catch(_){}};
  document.body.appendChild(d);requestAnimationFrame(function(){d.style.opacity='1';d.style.transform='translateY(0)';});
  setTimeout(function(){if(!d.isConnected)return;d.style.opacity='0';d.style.transform='translateY(-10px)';setTimeout(function(){try{d.remove();}catch(_){}},250);},6500);
}

function currentUser(){
  try{var s=JSON.parse(localStorage.getItem('aos_session')||'{}');return String(s.nombre||'').toUpperCase();}catch(_){}
  try{return String(window.AOS&&AOS.ctx&&AOS.ctx.nombre||'').toUpperCase();}catch(_){return'';}
}
function sbRpc(name,payload){
  var SB='https://ituyqwstonmhnfshnaqz.supabase.co',SK='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYXNlIiwicmVmIjoiaXR1eXF3c3Rvbm1obmZzaG5hcXoiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc3NDc0NDIxOCwiZXhwIjoyMDkwMzIwMjE4fQ.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';
  return fetch(SB+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:SK,Authorization:'Bearer '+SK,'Content-Type':'application/json'},body:JSON.stringify(payload||{}),cache:'no-store'}).then(function(r){if(!r.ok)throw new Error('HTTP_'+r.status);return r.json();});
}
function cardIcon(n){return meta(n&&n.channel).emoji;}
function applyAdminLoadPatch(){
  if(typeof window.lNo!=='function'||window.lNo.__aosS15)return;
  var fallback=window.lNo;
  var fn=function(){return sbRpc('aos_admin_notificaciones_v1',{p_limit:50}).then(function(d){if(window.D){D.no=d&&d.rows||[];if(D.rpTab==='n'&&typeof window.rNo==='function')window.rNo();}return d;}).catch(function(){try{return fallback();}catch(_){return null;}});};
  fn.__aosS15=true;fn.__aosFallback=fallback;window.lNo=fn;
  if(document.getElementById('zNL'))setTimeout(function(){try{fn();}catch(_){}},0);
}
function applyAdvisorRenderPatch(){
  if(typeof window.aNo!=='function'||window.aNo.__aosS15)return;
  var fallback=window.aNo;
  var fn=function(){
    var el=document.getElementById('aNotifs');if(!el||!window.AD)return fallback();
    if(!AD.no||!AD.no.length){el.innerHTML='<div style="padding:30px;text-align:center;font-size:11px;color:#94a3b8">Sin notificaciones</div>';return;}
    el.innerHTML=AD.no.map(function(n){var sy=cardIcon(n),ic=n.tipo==='URGENTE'?'Ana':n.tipo==='ALERTA'?'Anw':'Ani';return '<div class="ANc'+(n.leido?'':' unr')+'" style="position:relative"><div class="ANi '+ic+'">'+sy+'</div><div style="flex:1" onclick="AOS_NOTIFICATION_CENTER.readAndOpen(\''+E(n.id)+'\',\''+E(n.route||'')+'\',\''+E(n.entity_id||'')+'\')"><div style="font-weight:700;font-size:12px;color:#0f172a">'+E(n.titulo)+'</div>'+(n.contenido?'<div style="font-size:10px;color:#64748b;margin-top:2px">'+E(n.contenido)+'</div>':'')+'<div style="font-size:9px;color:#94a3b8;margin-top:3px">'+(typeof window.A==='function'?A(n.created_at):'')+(n.leido?'':' · <b style="color:#00C9A7">Nueva</b>')+'</div></div><button style="position:absolute;top:8px;right:8px;width:20px;height:20px;border-radius:6px;border:none;background:rgba(220,38,38,.06);color:#dc2626;font-size:9px;cursor:pointer" onclick="aDelN(\''+E(n.id)+'\')">✕</button></div>';}).join('');
  };
  fn.__aosS15=true;fn.__aosFallback=fallback;window.aNo=fn;
  if(document.getElementById('aNotifs'))setTimeout(function(){try{fn();}catch(_){}},0);
}
function applyAdminRenderPatch(){
  if(typeof window.rNo!=='function'||window.rNo.__aosS15)return;
  var fallback=window.rNo;
  var fn=function(){
    var el=document.getElementById('zNL');if(!el||!window.D)return fallback();
    if(!D.no||!D.no.length){el.innerHTML='<div style="padding:40px;text-align:center;font-size:12px;color:#94a3b8">Sin notificaciones</div>';return;}
    el.innerHTML=D.no.map(function(n){var sy=cardIcon(n),ic=n.tipo==='URGENTE'?'Zna':n.tipo==='ALERTA'?'Znw':'Zni';return '<div class="ZNc" onclick="AOS_NOTIFICATION_CENTER.open(\''+E(n.route||'')+'\',\''+E(n.entity_id||'')+'\')"><div class="ZNi '+ic+'">'+sy+'</div><div style="flex:1"><div style="font-weight:700;font-size:12px;color:#0f172a">'+E(n.titulo)+'</div>'+(n.contenido?'<div style="font-size:10px;color:#64748b;margin-top:3px;line-height:1.5">'+E(n.contenido)+'</div>':'')+'<div style="font-size:9px;color:#94a3b8;margin-top:4px">'+E(meta(n.channel).label)+' · '+(typeof window.A==='function'?A(n.created_at):'')+'</div></div></div>';}).join('');
  };
  fn.__aosS15=true;fn.__aosFallback=fallback;window.rNo=fn;
  if(document.getElementById('zNL'))setTimeout(function(){try{fn();}catch(_){}},0);
}
function applyReadPatch(){
  if(typeof window.aRN!=='function'||window.aRN.__aosS15)return;
  var fallback=window.aRN;
  var fn=function(id){var n=window.AD&&AD.no&&AD.no.find(function(x){return String(x.id)===String(id);});if(n)return readAndOpen(id,n.route,n.entity_id);return fallback(id);};
  fn.__aosS15=true;fn.__aosFallback=fallback;window.aRN=fn;
}
function readAndOpen(id,route,entityId){
  var u=currentUser();if(!id){go(route,entityId);return;}
  sbRpc('aos_marcar_notif_leida',{p_notif_id:id,p_usuario:u}).catch(function(){}).finally(function(){try{if(typeof window.aLoad==='function')window.aLoad();}catch(_){}go(route,entityId);});
}
function patchPanels(){applyAdminLoadPatch();applyAdvisorRenderPatch();applyAdminRenderPatch();applyReadPatch();}

if(navigator.serviceWorker&&navigator.serviceWorker.addEventListener){navigator.serviceWorker.addEventListener('message',function(e){var d=e&&e.data||{};if(d.type==='AOS_PUSH_EVENT'&&d.payload)toast(d.payload);if(d.type==='AOS_PUSH_OPEN'&&d.route)go(d.route,d.entityId);});}
setInterval(patchPanels,1000);patchPanels();
window.AOS_NOTIFICATION_CENTER={toast:toast,open:go,readAndOpen:readAndOpen,channel:meta};
})();
