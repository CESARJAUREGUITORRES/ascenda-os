// COORD-V7.2 — same-origin lock/search + stable collapsible drawers.
// No MutationObserver. No render loop. Hooks are installed idempotently.
(function(){
'use strict';
if(window.__AOS_COORD_V72__)return;
window.__AOS_COORD_V72__=1;

var S={open:false,q:'',matches:[],timer:null,channel:null};
var HOOKS={};

function esc(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function strongToken(){try{return String(sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||'').trim();}catch(_){return '';}}
function coordApi(path,body,cb){
  var h=new Headers({'Accept':'application/json','Content-Type':'application/json'}),t=strongToken();
  if(t.length>=32)h.set('X-AOS-App-Token',t);
  fetch(path,{method:'POST',headers:h,body:JSON.stringify(body||{}),cache:'no-store',credentials:'same-origin'})
    .then(function(r){return r.text().then(function(txt){var d={};try{d=txt?JSON.parse(txt):{};}catch(_){d={};}d.__status=r.status;if(!r.ok&&d.ok!==false)d.ok=false;if(!r.ok&&!d.error)d.error='HTTP_'+r.status;return d;});})
    .then(function(d){if(cb)cb(d);})
    .catch(function(){if(cb)cb({ok:false,error:'NETWORK_ERROR',__status:0});});
}
function notice(msg,type){
  var old=document.getElementById('cv71-notice');if(old)old.remove();
  var n=document.createElement('div');n.id='cv71-notice';
  var ok=type!=='error';
  n.style.cssText='position:fixed;top:72px;left:50%;transform:translateX(-50%);z-index:10050;max-width:min(440px,90vw);padding:12px 16px;border-radius:12px;background:'+(ok?'#ECFDF5':'#FFF1F2')+';border:1px solid '+(ok?'#A7F3D0':'#FECDD3')+';color:'+(ok?'#065F46':'#9F1239')+';box-shadow:0 10px 28px rgba(15,23,42,.16);font:700 11px "DM Sans",sans-serif';
  n.textContent=(ok?'✓ ':'⚠ ')+msg;document.body.appendChild(n);setTimeout(function(){if(n.parentNode)n.remove();},4200);
}
function isAdmin(){return !!document.getElementById('zChat');}
function isAdvisor(){return !!document.getElementById('aChat');}
function chAdmin(){try{return window.D&&D.ch&&D.ch.find(function(x){return x.id===D.ac;});}catch(_){return null;}}
function chAdvisor(){try{return window.AD&&AD.ch&&AD.ch.find(function(x){return x.id===AD.ac;});}catch(_){return null;}}
function ch(){return chAdmin()||chAdvisor();}
function locked(){var x=ch();return !!(x&&x.bloqueado);}
function root(){return document.querySelector(isAdmin()?'.Z':'.A');}
function left(){return document.querySelector(isAdmin()?'.ZL':'.AL');}
function right(){return document.querySelector(isAdmin()?'.ZR':'.AR');}
function boolLS(k){try{return localStorage.getItem(k)==='1';}catch(_){return false;}}
function setLS(k,v){try{localStorage.setItem(k,v?'1':'0');}catch(_){}}

function style(){
  if(document.getElementById('coord-v71-style'))return;
  var s=document.createElement('style');s.id='coord-v71-style';
  s.textContent=[
  '.cv71-tools{display:flex;gap:6px;align-items:center;margin-left:auto}',
  '.cv71-btn{height:32px;padding:0 10px;border-radius:9px;border:1px solid #e5e7eb;background:#fff;color:#475569;font:700 10px "DM Sans",sans-serif;cursor:pointer}',
  '.cv71-btn:hover{background:#f8fafc}.cv71-btn.lock{border-color:#fecaca;color:#b91c1c;background:#fff7f7}.cv71-btn.unlock{border-color:#bbf7d0;color:#047857;background:#f0fdf4}',
  '.cv71-badge{display:inline-flex;align-items:center;gap:4px;margin-left:7px;padding:3px 7px;border-radius:999px;background:#fff7ed;color:#9a3412;font-size:8px;font-weight:800}',
  '.cv71-search{padding:9px 14px;background:#fff;border-bottom:1px solid #e5e7eb;display:flex;gap:8px;align-items:center}',
  '.cv71-search input{flex:1;padding:9px 12px;border:1px solid #cbd5e1;border-radius:9px;font-size:11px;outline:none}',
  '.cv71-search input:focus{border-color:#0a4fbf;box-shadow:0 0 0 3px rgba(10,79,191,.08)}',
  '.cv71-results{max-height:190px;overflow:auto;background:#fff;border-bottom:1px solid #e5e7eb}',
  '.cv71-item{padding:9px 14px;border-bottom:1px solid #f1f5f9;cursor:pointer}.cv71-item:hover{background:#f8fafc}',
  '.cv71-meta{font-size:8px;color:#94a3b8;margin-bottom:3px}.cv71-text{font-size:10px;color:#334155;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
  '.cv71-locked{padding:13px 18px;background:#fff7ed;border-top:1px solid #fed7aa;color:#9a3412;font-size:10px;font-weight:700;text-align:center}',
  '.cv71-drawer-btn{position:absolute;z-index:30;width:28px;height:28px;border-radius:50%;border:1px solid #dbe3ef;background:#fff;box-shadow:0 3px 12px rgba(15,23,42,.12);display:flex;align-items:center;justify-content:center;cursor:pointer;color:#0a4fbf;font-size:12px}',
  '.ZL,.ZR,.AL,.AR{transition:width .18s ease,flex-basis .18s ease;position:relative;min-width:0}.ZM,.AM{min-width:0;overflow:hidden}',
  '.cv71-left-collapsed .ZL{width:72px!important}.cv71-left-collapsed .AL{width:72px!important}',
  '.cv71-left-collapsed .ZLh,.cv71-left-collapsed .ALh{display:none!important}',
  '.cv71-left-collapsed .ZLl,.cv71-left-collapsed .ALl{padding-top:40px!important}',
  '.cv71-left-collapsed .ZCi,.cv71-left-collapsed .ZCmeta,.cv71-left-collapsed .ZLsec,.cv71-left-collapsed .ACi,.cv71-left-collapsed .ACt,.cv71-left-collapsed .ACu{display:none!important}',
  '.cv71-left-collapsed .ZC,.cv71-left-collapsed .AC{justify-content:center;padding:9px 0!important;border-left-color:transparent!important}',
  '.cv71-left-collapsed .ZCa,.cv71-left-collapsed .ACa{margin:0!important}',
  '.ZR{flex:0 0 340px!important;width:340px!important;background:#fff;z-index:3}.AR{flex:0 0 340px!important;width:340px!important;background:#fff;z-index:3}.ZM,.AM{flex:1 1 auto!important;z-index:1}.cv71-right-collapsed .ZR{flex:0 0 52px!important;width:52px!important;min-width:52px!important}.cv71-right-collapsed .AR{flex:0 0 52px!important;width:52px!important;min-width:52px!important}',
  '.cv71-right-collapsed .ZR>*:not(.cv71-right-toggle),.cv71-right-collapsed .AR>*:not(.cv71-right-toggle){display:none!important}',
  '.cv71-left-toggle{right:-14px;top:10px}.cv71-right-toggle{left:8px;top:10px}.ZR>.ZRh,.AR>.ARh{padding-left:44px!important}',
  '.cv71-left-collapsed .cv71-left-toggle{right:-14px}.cv71-right-collapsed .cv71-right-toggle{left:12px;top:12px}',
  '@media(max-width:980px){.ZR,.AR{width:300px}.ZL{width:250px}.AL{width:220px}}'
  ].join('');
  document.head.appendChild(s);
}

function drawerState(){
  var r=root();if(!r)return;
  r.classList.toggle('cv71-left-collapsed',boolLS('aos_coord_left_collapsed'));
  r.classList.toggle('cv71-right-collapsed',boolLS('aos_coord_right_collapsed'));
}
function drawerButtons(){
  var l=left(),ri=right();if(!l||!ri)return;
  if(!l.querySelector('.cv71-left-toggle')){
    var b=document.createElement('button');b.className='cv71-drawer-btn cv71-left-toggle';b.title='Contraer/expandir chats';
    b.onclick=function(){var v=!boolLS('aos_coord_left_collapsed');setLS('aos_coord_left_collapsed',v);drawerState();b.textContent=v?'›':'‹';};
    l.appendChild(b);
  }
  if(!ri.querySelector('.cv71-right-toggle')){
    var b2=document.createElement('button');b2.className='cv71-drawer-btn cv71-right-toggle';b2.title='Contraer/expandir panel';
    b2.onclick=function(){var v=!boolLS('aos_coord_right_collapsed');setLS('aos_coord_right_collapsed',v);drawerState();b2.textContent=v?'‹':'›';};
    ri.appendChild(b2);
  }
  var lb=l.querySelector('.cv71-left-toggle'),rb=ri.querySelector('.cv71-right-toggle');
  if(lb)lb.textContent=boolLS('aos_coord_left_collapsed')?'›':'‹';
  if(rb)rb.textContent=boolLS('aos_coord_right_collapsed')?'‹':'›';
  drawerState();
}

function searchToggle(){
  var x=ch();if(!x)return;
  if(S.channel!==x.id){S.open=false;S.q='';S.matches=[];}
  S.channel=x.id;S.open=!S.open;decorate();
  if(S.open)setTimeout(function(){var i=document.getElementById('cv71-search-input');if(i)i.focus();},0);
}
function searchRun(v){
  var x=ch();if(!x)return;
  S.channel=x.id;S.q=String(v||'');clearTimeout(S.timer);
  if(S.q.trim().length<2){S.matches=[];results();return;}
  S.timer=setTimeout(function(){
    coordApi('/api/coord/search',{channel_id:x.id,query:S.q.trim()},function(r){
      if(!r||!r.ok){S.matches=[];results();notice(r&&r.error==='COORD_APP_SESSION_REQUIRED'?'Tu sesión necesita renovarse para buscar.':'No se pudo completar la búsqueda.','error');return;}
      S.matches=Array.isArray(r.matches)?r.matches:[];results();
    });
  },220);
}
function searchPick(id){
  var el=document.querySelector('[data-mid="'+id+'"]');if(!el)return;
  el.scrollIntoView({behavior:'smooth',block:'center'});el.style.outline='2px solid #f59e0b';el.style.outlineOffset='3px';
  setTimeout(function(){el.style.outline='';el.style.outlineOffset='';},1800);
}
function results(){
  var b=document.getElementById('cv71-results'),cnt=document.getElementById('cv71-count');if(!b)return;
  var rows=S.matches||[];if(cnt)cnt.textContent=rows.length+' resultado'+(rows.length===1?'':'s');
  if(!S.q||S.q.trim().length<2){b.innerHTML='';return;}
  if(!rows.length){b.innerHTML='<div style="padding:12px 14px;font-size:10px;color:#94a3b8">Sin coincidencias en este chat</div>';return;}
  b.innerHTML=rows.slice(0,30).map(function(m){
    var d=new Date(m.created_at),ds=d.toLocaleDateString('es-PE')+' · '+d.toLocaleTimeString('es-PE',{hour:'2-digit',minute:'2-digit'});
    return '<div class="cv71-item" data-mid-search="'+esc(m.id)+'"><div class="cv71-meta">'+esc(m.de)+' · '+esc(ds)+'</div><div class="cv71-text">'+esc(m.mensaje)+'</div></div>';
  }).join('');
  Array.prototype.forEach.call(b.querySelectorAll('[data-mid-search]'),function(n){n.onclick=function(){searchPick(n.getAttribute('data-mid-search'));};});
}
function mountSearch(head){
  var old=document.getElementById('cv71-search-wrap');if(old)old.remove();
  if(!S.open||!head)return;
  var w=document.createElement('div');w.id='cv71-search-wrap';
  w.innerHTML='<div class="cv71-search"><span>🔍</span><input id="cv71-search-input" placeholder="Buscar nombre, DNI, teléfono, tratamiento, observación..." value="'+esc(S.q)+'"><span id="cv71-count" style="font-size:9px;color:#64748b;min-width:58px;text-align:right"></span><button class="cv71-btn" id="cv71-search-close">✕</button></div><div class="cv71-results" id="cv71-results"></div>';
  head.parentNode.insertBefore(w,head.nextSibling);
  document.getElementById('cv71-search-input').oninput=function(){searchRun(this.value);};
  document.getElementById('cv71-search-close').onclick=searchToggle;results();
}

function lockToggle(){
  var x=chAdmin();if(!x)return;var next=!x.bloqueado;
  var msg=next?'¿Bloquear este chat? Nadie podrá escribir ni adjuntar archivos; solo seguirán entrando reportes automáticos de citas.':'¿Desbloquear este chat y permitir mensajes nuevamente?';
  var go=function(){coordApi('/api/coord/channel-lock',{channel_id:x.id,locked:next},function(r){
    if(!r||!r.ok){
      var e=r&&r.error||'';
      var msg=e==='FORBIDDEN_SUPERADMIN_ONLY'?'Solo el superadmin puede bloquear o desbloquear chats.':e==='COORD_APP_SESSION_REQUIRED'?'Tu sesión de Ascenda Clinic debe renovarse antes de cambiar el bloqueo.':e==='CHANNEL_NOT_FOUND'?'No se encontró este chat.':'No se pudo cambiar el estado del chat. Intenta recargar la app.';
      notice(msg,'error');return;
    }
    x.bloqueado=!!r.locked;x.bloqueado_por=r.locked_by||null;x.bloqueado_at=r.locked_at||null;
    if(window.D&&D.drafts&&x.bloqueado)D.drafts[x.id]='';
    notice(x.bloqueado?'Chat bloqueado: ahora funciona en modo solo reportes.':'Chat desbloqueado: los mensajes vuelven a estar habilitados.','ok');
    if(typeof window.rChat==='function')window.rChat();if(typeof window.rCL==='function')window.rCL();
  });};
  if(typeof window.aosConfirm==='function')window.aosConfirm(msg,go);else if(confirm(msg))go();
}

function mark(){
  var arr=isAdmin()?(window.D&&D.ms):(window.AD&&AD.ms);if(!arr)return;
  var nodes=document.querySelectorAll(isAdmin()?'.Zm':'.Am'),i=0;
  arr.filter(function(m){return !m.eliminado;}).forEach(function(m){if(nodes[i])nodes[i].setAttribute('data-mid',m.id);i++;});
}
function lockedComposer(){
  if(!locked())return;
  var sel=isAdmin()?'.ZMf':'.AMf',x=document.querySelector(sel);
  if(x&&!document.querySelector('.cv71-locked')){var b=document.createElement('div');b.className='cv71-locked';b.textContent='🔒 Chat bloqueado · Solo se publican reportes automáticos de citas';x.replaceWith(b);}
}
function adminDecor(){
  var x=chAdmin(),head=document.querySelector('#zChat .ZMh');if(!x||!head)return;
  var tools=head.querySelector('.cv71-tools');
  if(!tools){tools=document.createElement('div');tools.className='cv71-tools';head.appendChild(tools);}
  tools.innerHTML='<button class="cv71-btn" data-a="search">🔍 Buscar</button><button class="cv71-btn '+(x.bloqueado?'unlock':'lock')+'" data-a="lock">'+(x.bloqueado?'🔓 Desbloquear':'🔒 Bloquear')+'</button>';
  tools.querySelector('[data-a="search"]').onclick=searchToggle;tools.querySelector('[data-a="lock"]').onclick=lockToggle;
  var title=head.querySelector('.ZMn'),old=title&&title.querySelector('.cv71-badge');if(old)old.remove();
  if(title&&x.bloqueado)title.insertAdjacentHTML('beforeend','<span class="cv71-badge">🔒 Solo reportes</span>');
  mountSearch(head);lockedComposer();mark();
}
function advisorDecor(){
  var x=chAdvisor(),head=document.querySelector('#aChat .AMh');if(!x||!head)return;
  var tools=head.querySelector('.cv71-tools');
  if(!tools){tools=document.createElement('div');tools.className='cv71-tools';head.appendChild(tools);}
  tools.innerHTML='<button class="cv71-btn" data-a="search">🔍 Buscar</button>';tools.querySelector('[data-a="search"]').onclick=searchToggle;
  var title=head.querySelector('.AMn'),old=title&&title.querySelector('.cv71-badge');if(old)old.remove();
  if(title&&x.bloqueado)title.insertAdjacentHTML('beforeend','<span class="cv71-badge">🔒 Solo reportes</span>');
  mountSearch(head);lockedComposer();mark();
}
function decorate(){style();drawerButtons();if(isAdmin())adminDecor();else if(isAdvisor())advisorDecor();}

function wrap(name,after,guard){
  var fn=window[name];if(typeof fn!=='function')return false;
  if(fn.__cv71)return true;
  var w=function(){
    if(guard&&guard()===false)return;
    var r=fn.apply(this,arguments);
    if(after)setTimeout(after,0);
    return r;
  };
  w.__cv71=true;w.__cv71_original=fn;window[name]=w;HOOKS[name]=w;return true;
}
function install(){
  style();drawerButtons();
  if(isAdmin()){
    wrap('rChat',decorate);
    wrap('rCL',function(){drawerButtons();});
    wrap('sMsg',decorate,function(){if(locked()){alert('Este chat está bloqueado. Solo ingresan reportes automáticos de citas.');return false;}});
    wrap('upFile',null,function(){if(locked()){alert('Este chat está bloqueado.');return false;}});
    wrap('upBlob',null,function(){if(locked()){alert('Este chat está bloqueado.');return false;}});
  }else if(isAdvisor()){
    wrap('aRChat',decorate);
    wrap('aCL',function(){drawerButtons();});
    wrap('aSend',decorate,function(){if(locked()){alert('Este chat está bloqueado. Solo ingresan reportes automáticos de citas.');return false;}});
    wrap('aUpFile',null,function(){if(locked()){alert('Este chat está bloqueado.');return false;}});
    wrap('aUpBlob',null,function(){if(locked()){alert('Este chat está bloqueado.');return false;}});
  }
  decorate();
}

// Lightweight discovery only. It does not mutate the DOM unless a control is actually missing.
// This replaces the previous subtree MutationObserver that could recurse on its own DOM changes.
var tries=0,boot=setInterval(function(){tries++;install();if(tries>=30)clearInterval(boot);},500);
window.addEventListener('hashchange',function(){setTimeout(install,80);});
document.addEventListener('click',function(e){var t=e.target;if(t&&t.closest&&t.closest('[data-view],.nav-item,.sidebar-item'))setTimeout(install,120);},true);
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
})();