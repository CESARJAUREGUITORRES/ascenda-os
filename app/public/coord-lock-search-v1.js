// COORD-V7 — admin chat lock + conversation search.
(function(){
'use strict';
if(window.__AOS_COORD_V7__)return;window.__AOS_COORD_V7__=1;

function esc(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function ensureStyle(){
  if(document.getElementById('coord-v7-style'))return;
  var s=document.createElement('style');s.id='coord-v7-style';
  s.textContent='.cv7-tools{display:flex;gap:6px;align-items:center;margin-left:auto}.cv7-btn{height:32px;padding:0 10px;border-radius:9px;border:1px solid #e5e7eb;background:#fff;color:#475569;font:700 10px "DM Sans",sans-serif;cursor:pointer}.cv7-btn:hover{background:#f8fafc}.cv7-btn.lock{border-color:#fecaca;color:#b91c1c;background:#fff7f7}.cv7-btn.unlock{border-color:#bbf7d0;color:#047857;background:#f0fdf4}.cv7-badge{display:inline-flex;align-items:center;gap:4px;margin-left:7px;padding:3px 7px;border-radius:999px;background:#fff7ed;color:#9a3412;font-size:8px;font-weight:800}.cv7-search{padding:9px 14px;background:#fff;border-bottom:1px solid #e5e7eb;display:flex;gap:8px;align-items:center}.cv7-search input{flex:1;padding:9px 12px;border:1px solid #cbd5e1;border-radius:9px;font-size:11px;outline:none}.cv7-search input:focus{border-color:#0a4fbf;box-shadow:0 0 0 3px rgba(10,79,191,.08)}.cv7-results{max-height:190px;overflow:auto;background:#fff;border-bottom:1px solid #e5e7eb}.cv7-item{padding:9px 14px;border-bottom:1px solid #f1f5f9;cursor:pointer}.cv7-item:hover{background:#f8fafc}.cv7-meta{font-size:8px;color:#94a3b8;margin-bottom:3px}.cv7-text{font-size:10px;color:#334155;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.cv7-locked{padding:13px 18px;background:#fff7ed;border-top:1px solid #fed7aa;color:#9a3412;font-size:10px;font-weight:700;text-align:center}.cv7-lockdot{font-size:10px;margin-left:4px}';
  document.head.appendChild(s);
}
function api(name,p,cb){if(typeof window.rpc==='function'){window.rpc(name,p,cb);return;}cb&&cb({ok:false,error:'RPC_UNAVAILABLE'});}
function adminCh(){try{return window.D&&D.ch&&D.ch.find(function(x){return x.id===D.ac;});}catch(_){return null;}}
function advisorCh(){try{return window.AD&&AD.ch&&AD.ch.find(function(x){return x.id===AD.ac;});}catch(_){return null;}}
function currentChannel(){return adminCh()||advisorCh();}
function isAdminView(){return !!document.getElementById('zChat');}
function isAdvisorView(){return !!document.getElementById('aChat');}
function locked(){var ch=currentChannel();return !!(ch&&ch.bloqueado);}

var state={open:false,q:'',matches:[],timer:null,channel:null};

function searchToggle(){
  var ch=currentChannel();if(!ch)return;
  if(state.channel!==ch.id){state.open=false;state.q='';state.matches=[];}
  state.channel=ch.id;state.open=!state.open;
  decorate();
  if(state.open)setTimeout(function(){var i=document.getElementById('cv7-search-input');if(i)i.focus();},0);
}
function searchRun(v){
  var ch=currentChannel();if(!ch)return;
  state.channel=ch.id;state.q=String(v||'');clearTimeout(state.timer);
  if(state.q.trim().length<2){state.matches=[];renderResults();return;}
  state.timer=setTimeout(function(){
    api('aos_coord_search_messages_v1',{p_token:'__worker__',p_canal:ch.id,p_query:state.q.trim()},function(r){
      state.matches=(r&&r.ok&&Array.isArray(r.matches))?r.matches:[];renderResults();
    });
  },220);
}
function searchPick(id){
  var el=document.querySelector('[data-mid="'+id+'"]');
  if(el){el.scrollIntoView({behavior:'smooth',block:'center'});el.style.outline='2px solid #f59e0b';el.style.outlineOffset='3px';setTimeout(function(){el.style.outline='';el.style.outlineOffset='';},1800);}
}
function renderResults(){
  var b=document.getElementById('cv7-results'),cnt=document.getElementById('cv7-count');if(!b)return;
  var rows=state.matches||[];if(cnt)cnt.textContent=rows.length+' resultado'+(rows.length===1?'':'s');
  if(!state.q||state.q.trim().length<2){b.innerHTML='';return;}
  if(!rows.length){b.innerHTML='<div style="padding:12px 14px;font-size:10px;color:#94a3b8">Sin coincidencias en este chat</div>';return;}
  b.innerHTML=rows.slice(0,30).map(function(m){var d=new Date(m.created_at),ds=d.toLocaleDateString('es-PE')+' · '+d.toLocaleTimeString('es-PE',{hour:'2-digit',minute:'2-digit'});return '<div class="cv7-item" data-search-id="'+esc(m.id)+'"><div class="cv7-meta">'+esc(m.de)+' · '+esc(ds)+'</div><div class="cv7-text">'+esc(m.mensaje)+'</div></div>';}).join('');
  Array.prototype.forEach.call(b.querySelectorAll('[data-search-id]'),function(x){x.onclick=function(){searchPick(x.getAttribute('data-search-id'));};});
}
function mountSearch(host){
  var old=document.getElementById('cv7-search-wrap');if(old)old.remove();
  if(!state.open||!host)return;
  var wrap=document.createElement('div');wrap.id='cv7-search-wrap';
  wrap.innerHTML='<div class="cv7-search"><span>🔍</span><input id="cv7-search-input" placeholder="Buscar nombre, DNI, teléfono, tratamiento, observación..." value="'+esc(state.q)+'"><span id="cv7-count" style="font-size:9px;color:#64748b;min-width:58px;text-align:right"></span><button class="cv7-btn" id="cv7-close-search">✕</button></div><div class="cv7-results" id="cv7-results"></div>';
  host.parentNode.insertBefore(wrap,host.nextSibling);
  document.getElementById('cv7-search-input').oninput=function(){searchRun(this.value);};
  document.getElementById('cv7-close-search').onclick=searchToggle;renderResults();
}
function lockToggle(){
  var ch=adminCh();if(!ch)return;var next=!ch.bloqueado;
  var msg=next?'¿Bloquear este chat? Nadie podrá escribir ni adjuntar archivos; solo seguirán entrando reportes automáticos de citas.':'¿Desbloquear este chat y permitir mensajes nuevamente?';
  var go=function(){api('aos_coord_set_channel_lock_v1',{p_token:'__worker__',p_canal:ch.id,p_locked:next},function(r){if(!r||!r.ok){alert('No se pudo '+(next?'bloquear':'desbloquear')+' el chat.');return;}ch.bloqueado=!!r.locked;ch.bloqueado_por=r.locked_by||null;ch.bloqueado_at=r.locked_at||null;if(window.D&&D.drafts&&ch.bloqueado)D.drafts[ch.id]='';decorate();if(typeof window.rCL==='function')rCL();});};
  if(typeof window.aosConfirm==='function')window.aosConfirm(msg,go);else if(confirm(msg))go();
}
function markMessages(){
  var arr=isAdminView()?(window.D&&D.ms):(window.AD&&AD.ms);if(!arr)return;
  var nodes=document.querySelectorAll(isAdminView()?'.Zm':'.Am'),idx=0;
  arr.filter(function(m){return !m.eliminado;}).forEach(function(m){if(nodes[idx])nodes[idx].setAttribute('data-mid',m.id);idx++;});
}
function enforceLockedComposer(){
  if(!locked())return;
  var composer=document.querySelector(isAdminView()?'.ZMf':'.AMf');if(composer){var bar=document.createElement('div');bar.className='cv7-locked';bar.textContent='🔒 Chat bloqueado · Solo se publican reportes automáticos de citas';composer.replaceWith(bar);}
}
function decorateAdmin(){
  var ch=adminCh(),head=document.querySelector('#zChat .ZMh');if(!ch||!head)return;
  var old=head.querySelector('.cv7-tools');if(old)old.remove();
  var tools=document.createElement('div');tools.className='cv7-tools';
  tools.innerHTML='<button class="cv7-btn" data-a="search">🔍 Buscar</button><button class="cv7-btn '+(ch.bloqueado?'unlock':'lock')+'" data-a="lock">'+(ch.bloqueado?'🔓 Desbloquear':'🔒 Bloquear')+'</button>';
  head.appendChild(tools);tools.querySelector('[data-a="search"]').onclick=searchToggle;tools.querySelector('[data-a="lock"]').onclick=lockToggle;
  var title=head.querySelector('.ZMn');if(title&&ch.bloqueado&&!title.querySelector('.cv7-badge'))title.insertAdjacentHTML('beforeend','<span class="cv7-badge">🔒 Solo reportes</span>');
  mountSearch(head);enforceLockedComposer();markMessages();
}
function decorateAdvisor(){
  var ch=advisorCh(),head=document.querySelector('#aChat .AMh');if(!ch||!head)return;
  var old=head.querySelector('.cv7-tools');if(old)old.remove();
  var tools=document.createElement('div');tools.className='cv7-tools';tools.innerHTML='<button class="cv7-btn" data-a="search">🔍 Buscar</button>';
  head.appendChild(tools);tools.querySelector('[data-a="search"]').onclick=searchToggle;
  var title=head.querySelector('.AMn');if(title&&ch.bloqueado&&!title.querySelector('.cv7-badge'))title.insertAdjacentHTML('beforeend','<span class="cv7-badge">🔒 Solo reportes</span>');
  mountSearch(head);enforceLockedComposer();markMessages();
}
function decorate(){ensureStyle();if(isAdminView())decorateAdmin();else if(isAdvisorView())decorateAdvisor();}

function wrap(name,guard){
  var fn=window[name];if(typeof fn!=='function'||fn.__cv7)return;
  var w=function(){if(guard&&guard()===false)return;var r=fn.apply(this,arguments);setTimeout(decorate,0);return r;};w.__cv7=1;window[name]=w;
}
function install(){
  ensureStyle();
  if(isAdminView()){
    wrap('rChat');
    wrap('sMsg',function(){if(locked()){alert('Este chat está bloqueado. Solo ingresan reportes automáticos de citas.');return false;}});
    wrap('upFile',function(){if(locked()){alert('Este chat está bloqueado.');return false;}});
    wrap('upBlob',function(){if(locked()){alert('Este chat está bloqueado.');return false;}});
  }
  if(isAdvisorView()){
    wrap('aRChat');
    wrap('aSend',function(){if(locked()){alert('Este chat está bloqueado. Solo ingresan reportes automáticos de citas.');return false;}});
    wrap('aUpFile',function(){if(locked()){alert('Este chat está bloqueado.');return false;}});
    wrap('aUpBlob',function(){if(locked()){alert('Este chat está bloqueado.');return false;}});
  }
  decorate();
}
var obs=new MutationObserver(function(){install();});obs.observe(document.documentElement,{childList:true,subtree:true});
setInterval(install,1200);install();
})();