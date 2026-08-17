// ASCENDA Conversations — PHASE S S6 native auth + UX bridge.
// Runs before WA-3 inline app code inside the same-origin embedded Hub.
(function(){
'use strict';
var RETRYABLE={403:1,502:1,503:1,504:1};
var CACHE_NAME='aos-phase2-auth',CACHE_KEY='/__aos_app_token';
var tokenReady=null;
function valid(t){return String(t||'').trim().length>=32?String(t).trim():'';}
function localToken(){try{return valid(sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||'');}catch(_){return '';}}
function parentToken(){try{if(window.parent&&window.parent!==window){var p=window.parent.sessionStorage;return valid(p.getItem('aos_app_token')||p.getItem('aos_si_token')||'');}}catch(_){}return '';}
function saveToken(t){t=valid(t);if(!t)return '';try{sessionStorage.setItem('aos_app_token',t);}catch(_){}return t;}
function cacheToken(){
  if(!('caches' in window))return Promise.resolve('');
  return caches.open(CACHE_NAME).then(function(c){return c.match(CACHE_KEY);}).then(function(r){return r?r.text():'';}).then(function(t){return saveToken(t);}).catch(function(){return '';});
}
function recoverToken(force){
  if(tokenReady&&!force)return tokenReady;
  tokenReady=Promise.resolve().then(function(){var t=localToken()||parentToken();if(t)return saveToken(t);return cacheToken();}).then(function(t){
    window.__AOS_WA_AUTH_BRIDGE={ready:!!t,source:t?(parentToken()?'session':'cache'):'none',version:'S6'};
    return t;
  });
  return tokenReady;
}
recoverToken(false);

var baseFetch=window.fetch.bind(window);
function isWaApi(input){
  var raw='';try{raw=typeof input==='string'?input:String(input&&input.url||'');}catch(_){return false;}
  try{var u=new URL(raw,location.href);return u.origin===location.origin&&u.pathname.indexOf('/api/wa3/')===0;}catch(_){return raw.indexOf('/api/wa3/')>=0;}
}
function isBootstrap(input){var raw='';try{raw=typeof input==='string'?input:String(input&&input.url||'');}catch(_){return false;}return raw.indexOf('/api/wa3/bootstrap')>=0;}
function withAuth(input,init,t){
  var next=Object.assign({},init||{}),h;
  try{h=new Headers((init&&init.headers)||(input&&input.headers)||{});}catch(_){h=new Headers();}
  if(valid(t))h.set('X-AOS-App-Token',valid(t));
  h.set('Accept','application/json');
  next.headers=h;
  next.cache='no-store';
  return baseFetch(input,next);
}
window.fetch=function(input,init){
  if(!isWaApi(input))return baseFetch(input,init);
  var attempt=0;
  function run(force){
    attempt++;
    return recoverToken(!!force).then(function(t){return withAuth(input,init,t);}).then(function(r){
      if(r.ok)return r;
      if(r.status===403&&attempt<3)return run(true);
      if(isBootstrap(input)&&RETRYABLE[r.status]&&attempt<6){
        var wait=Math.min(1500,220*attempt);
        return new Promise(function(resolve){setTimeout(resolve,wait);}).then(function(){return run(false);});
      }
      return r;
    });
  }
  return run(false);
};

function esc(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function addStyle(){
  if(document.getElementById('wa-s6-style'))return;
  var s=document.createElement('style');s.id='wa-s6-style';s.textContent='\
  .center{position:relative}.wa-s6-toolbar{position:absolute;right:12px;top:9px;z-index:8;display:flex;gap:6px}.wa-s6-toolbar button{width:30px;height:30px;border:1px solid var(--bd);border-radius:9px;background:#fff;color:var(--nav);font-size:14px;cursor:pointer;box-shadow:0 2px 8px rgba(7,29,74,.06)}.wa-s6-toolbar button:hover{background:#edf4ff;border-color:#9cb6e3}.layout.wa-left-closed{grid-template-columns:0 minmax(0,1fr) 330px}.layout.wa-left-closed .left{display:none}.layout.wa-right-closed{grid-template-columns:320px minmax(0,1fr) 0}.layout.wa-right-closed .right{display:none}.layout.wa-left-closed.wa-right-closed{grid-template-columns:0 minmax(0,1fr) 0}.chathead{padding-right:88px}.msgs{padding:20px 24px}.msg{max-width:min(78%,760px)}.bubble{font-size:12px;line-height:1.5}.composer textarea{min-height:46px;resize:none;font-size:12px}.wa-lead360{margin:10px 11px 0;border:1px solid #dbe6f5;border-radius:14px;background:linear-gradient(180deg,#fff,#f8fbff);padding:12px}.wa-lead360 .leadtop{display:flex;align-items:center;gap:9px}.wa-lead360 .avatar360{width:34px;height:34px;border-radius:50%;display:grid;place-items:center;background:linear-gradient(135deg,#0a4fbf,#00bfa6);color:#fff;font-weight:900;font-size:11px}.wa-lead360 .leadname{font-weight:900;font-size:12px}.wa-lead360 .leadphone{font-size:9px;color:var(--mut);margin-top:2px}.wa-lead360 .chips{display:flex;flex-wrap:wrap;gap:5px;margin-top:9px}.wa-lead360 .chip{font-size:8px;font-weight:900;padding:4px 6px;border-radius:9px;background:#edf2f8;color:#52617d}.wa-lead360 .chip.ok{background:#eaf8f1;color:#16803b}.wa-lead360 .chip.warn{background:#fff5dd;color:#9b6100}.wa-lead360 .facts{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin-top:10px}.wa-lead360 .fact{border:1px solid #edf1f7;border-radius:9px;padding:7px;background:#fff}.wa-lead360 .fk{font-size:7px;text-transform:uppercase;letter-spacing:.5px;color:#93a0b8;font-weight:900}.wa-lead360 .fv{font-size:9px;color:#263c62;font-weight:800;margin-top:2px;word-break:break-word}@media(max-width:1050px){.layout.wa-left-closed,.layout.wa-right-closed,.layout.wa-left-closed.wa-right-closed{grid-template-columns:1fr}.wa-s6-toolbar{display:none}}';document.head.appendChild(s);
}
function apiJson(url){return window.fetch(url,{headers:{Accept:'application/json'},cache:'no-store'}).then(function(r){return r.json().then(function(d){if(!r.ok||d.ok===false)throw new Error(d.error||('HTTP_'+r.status));return d;});});}
var leadTimer=null,bootCache=null,bootAt=0;
function bootData(){if(bootCache&&Date.now()-bootAt<15000)return Promise.resolve(bootCache);return apiJson('/api/wa3/bootstrap').then(function(d){bootCache=d;bootAt=Date.now();return d;});}
function currentId(){var x=document.querySelector('.conv.on');return x?x.getAttribute('data-id'):'';}
function initials(n){return String(n||'WA').trim().split(/\s+/).slice(0,2).map(function(x){return x.charAt(0);}).join('').toUpperCase()||'WA';}
function scheduleLead(){clearTimeout(leadTimer);leadTimer=setTimeout(renderLead360,120);}
function renderLead360(){
  var right=document.querySelector('.right'),side=document.getElementById('side'),id=currentId();if(!right||!side)return;
  var old=document.getElementById('wa-lead360');if(!id){if(old)old.remove();return;}
  Promise.all([apiJson('/api/wa3/inbox?limit=120'),bootData()]).then(function(xs){
    var rows=xs[0].rows||[],b=xs[1]||{},r=rows.find(function(x){return x.id===id;});if(!r)return;
    var box=(b.boxes||[]).find(function(x){return x.id===r.box_id;})||null;
    var owner=(b.users||[]).find(function(x){return x.id===r.owner_user_id;})||null;
    var mode=r.state==='HUMAN_ACTIVE'?'HUMANO':(r.state==='AI_COPILOT'?'COPILOT':(r.owner_user_id?'ASIGNADO':'COLA'));
    var bot=b.control&&b.control.ai_send_enabled?'BOT ON':'BOT OFF';
    var html='<div class="leadtop"><div class="avatar360">'+esc(initials(r.contact_name))+'</div><div><div class="leadname">'+esc(r.contact_name||'Lead WhatsApp')+'</div><div class="leadphone">+'+esc(r.contact_number||'')+'</div></div></div>'+
      '<div class="chips"><span class="chip ok">'+esc(mode)+'</span><span class="chip '+(bot==='BOT ON'?'warn':'')+'">'+esc(bot)+'</span><span class="chip">'+esc(box?box.name:'Sin box')+'</span></div>'+
      '<div class="facts"><div class="fact"><div class="fk">Owner</div><div class="fv">'+esc(owner?owner.nombre:'Sin owner')+'</div></div><div class="fact"><div class="fk">Estado</div><div class="fv">'+esc(r.state||'NEW')+'</div></div><div class="fact"><div class="fk">Campaña</div><div class="fv">'+esc(r.campaign_source||'No registrada')+'</div></div><div class="fact"><div class="fk">Lead Meta</div><div class="fv">'+esc(r.lead_id||'—')+'</div></div><div class="fact"><div class="fk">Anuncio</div><div class="fv">'+esc(r.ad_id||'—')+'</div></div><div class="fact"><div class="fk">No leídos</div><div class="fv">'+esc(r.unread_count||0)+'</div></div></div>';
    var card=old||document.createElement('div');card.id='wa-lead360';card.className='wa-lead360';card.innerHTML=html;if(!old)right.insertBefore(card,side);
  }).catch(function(){});
}
function installUi(){
  addStyle();var layout=document.querySelector('.layout'),center=document.querySelector('.center');if(!layout||!center)return;
  if(!document.getElementById('wa-s6-toolbar')){
    var tb=document.createElement('div');tb.id='wa-s6-toolbar';tb.className='wa-s6-toolbar';tb.innerHTML='<button id="wa-left-toggle" title="Mostrar/ocultar conversaciones">☰</button><button id="wa-right-toggle" title="Mostrar/ocultar Lead 360 y routing">◫</button>';center.appendChild(tb);
    var leftOpen=localStorage.getItem('aos_wa_left_open')!=='0',rightOpen=localStorage.getItem('aos_wa_right_open')!=='0';
    function apply(){layout.classList.toggle('wa-left-closed',!leftOpen);layout.classList.toggle('wa-right-closed',!rightOpen);localStorage.setItem('aos_wa_left_open',leftOpen?'1':'0');localStorage.setItem('aos_wa_right_open',rightOpen?'1':'0');}
    document.getElementById('wa-left-toggle').onclick=function(){leftOpen=!leftOpen;apply();};document.getElementById('wa-right-toggle').onclick=function(){rightOpen=!rightOpen;apply();};apply();
  }
  var list=document.getElementById('list'),head=document.getElementById('chathead');if(window.MutationObserver){var mo=new MutationObserver(scheduleLead);if(list)mo.observe(list,{subtree:true,childList:true,attributes:true,attributeFilter:['class']});if(head)mo.observe(head,{subtree:true,childList:true});}
  document.addEventListener('click',function(e){if(e.target&&e.target.closest&&e.target.closest('.conv'))scheduleLead();},true);scheduleLead();
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',installUi,{once:true});else installUi();
})();
