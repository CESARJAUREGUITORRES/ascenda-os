// ASCENDA Conversations — S13 chronological chat UX hardening.
// Defense-in-depth: normalize WA-3 message ordering in the client and decorate the timeline.
(function(){
'use strict';
if(window.__AOS_WA_CHAT_UX_S13)return;
window.__AOS_WA_CHAT_UX_S13=true;

function eventMs(m){
  if(!m)return 0;
  var candidates=m.direction==='OUTBOUND'?[m.sent_at,m.created_at,m.provider_timestamp,m.delivered_at,m.read_at]:[m.provider_timestamp,m.received_at,m.created_at,m.sent_at];
  for(var i=0;i<candidates.length;i++){var t=Date.parse(String(candidates[i]||''));if(Number.isFinite(t))return t;}
  return 0;
}
function sortMessages(rows){return (Array.isArray(rows)?rows.slice():[]).sort(function(a,b){var d=eventMs(a)-eventMs(b);if(d)return d;return String(a&&a.id||'').localeCompare(String(b&&b.id||''));});}

var baseFetch=window.fetch.bind(window);
window.fetch=function(input,init){
  var method=String((init&&init.method)||(input&&input.method)||'GET').toUpperCase(),u=null;
  try{u=new URL(typeof input==='string'?input:input.url,location.href);}catch(_){}
  var isTimeline=!!(u&&u.origin===location.origin&&method==='GET'&&/^\/api\/wa3\/conversations\/[^/]+\/messages$/.test(u.pathname));
  if(!isTimeline)return baseFetch(input,init);
  return baseFetch(input,init).then(function(r){
    if(!r||!r.ok)return r;
    return r.clone().json().then(function(d){
      if(!d||!Array.isArray(d.messages))return r;
      d.messages=sortMessages(d.messages);
      var h=new Headers(r.headers);h.delete('content-length');h.set('Cache-Control','no-store');
      return new Response(JSON.stringify(d),{status:r.status,statusText:r.statusText,headers:h});
    }).catch(function(){return r;});
  });
};

function injectStyle(){
  if(document.getElementById('aos-wa13-chat-style'))return;
  var s=document.createElement('style');s.id='aos-wa13-chat-style';
  s.textContent='#wa8-msgs{background:linear-gradient(180deg,#f2f5fb 0%,#eef3f8 100%)!important;padding:18px 20px 20px!important}.wa8-msg{margin:5px 0!important}.wa8-msg.wa13-cont{margin-top:2px!important}.wa8-bubble{max-width:min(72%,680px)!important;padding:8px 10px 6px!important;border-radius:13px 13px 13px 5px!important;box-shadow:0 1px 1px rgba(13,27,62,.04)!important}.wa8-msg.out .wa8-bubble{border-radius:13px 13px 5px 13px!important;background:#dcf8ec!important;border-color:#c7eadc!important}.wa8-mstat{display:flex!important;justify-content:flex-end!important;align-items:center!important;gap:4px!important;min-height:12px!important;margin-top:3px!important;font-size:8px!important;white-space:nowrap!important}.wa13-check{font-weight:900;color:#7c8da8;letter-spacing:-1px}.wa13-check.read{color:#1d8bf1}.wa13-failed{color:#dc2626;font-weight:900}.wa13-date-sep{display:flex;justify-content:center;margin:12px 0 9px;pointer-events:none}.wa13-date-sep span{font-size:8px;font-weight:800;color:#6f7f9e;background:rgba(255,255,255,.9);border:1px solid #dce4ef;border-radius:999px;padding:4px 9px;box-shadow:0 1px 2px rgba(13,27,62,.03)}';
  document.head.appendChild(s);
}
function parseMeta(raw){var parts=String(raw||'').split(' · '),status=(parts.shift()||'').trim(),rest=parts.join(' · ').trim(),m=rest.match(/\b\d{2}\/\d{2}\b/);return {status:status,time:rest,date:m?m[0]:''};}
function statusHtml(status,out){status=String(status||'').toLowerCase();if(!out)return '';if(status==='read')return '<span class="wa13-check read">✓✓</span>';if(status==='delivered')return '<span class="wa13-check">✓✓</span>';if(status==='sent'||status==='accepted')return '<span class="wa13-check">✓</span>';if(status==='failed')return '<span class="wa13-failed">!</span>';return status?'<span class="wa13-check">'+status.replace(/[<>]/g,'')+'</span>':'';}
function decorate(){
  injectStyle();var box=document.getElementById('wa8-msgs');if(!box)return;
  Array.prototype.forEach.call(box.querySelectorAll('.wa13-date-sep'),function(n){n.remove();});
  var rows=Array.prototype.slice.call(box.querySelectorAll('.wa8-msg')),lastDate='',lastDir='';
  rows.forEach(function(row){
    var stat=row.querySelector('.wa8-mstat');if(!stat)return;
    var raw=stat.getAttribute('data-wa13-source')||stat.textContent||'';stat.setAttribute('data-wa13-source',raw);
    var meta=parseMeta(raw),out=row.classList.contains('out'),dir=out?'out':'in';
    if(meta.date&&meta.date!==lastDate){var sep=document.createElement('div');sep.className='wa13-date-sep';sep.innerHTML='<span>'+meta.date+'</span>';row.parentNode.insertBefore(sep,row);lastDate=meta.date;lastDir='';}
    row.classList.toggle('wa13-cont',dir===lastDir);lastDir=dir;
    stat.innerHTML=statusHtml(meta.status,out)+(meta.time?'<span>'+meta.time+'</span>':'');
  });
}
var pending=false;
function schedule(){if(pending)return;pending=true;requestAnimationFrame(function(){pending=false;decorate();});}
var obs=new MutationObserver(schedule);obs.observe(document.documentElement,{childList:true,subtree:true});
window.addEventListener('focus',schedule);document.addEventListener('visibilitychange',function(){if(!document.hidden)schedule();});
window.AOS_WA_CHAT_UX={version:'S13',sortMessages:sortMessages,decorate:decorate,eventMs:eventMs};
schedule();
})();
