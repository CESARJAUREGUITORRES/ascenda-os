// ASCENDA Conversations — S12 human advisor alerts.
// Alerts only for inbound messages owned by the current actor in HUMAN_ACTIVE mode.
(function(){
'use strict';
if(window.__AOS_WA_HUMAN_ALERTS_V1)return;
window.__AOS_WA_HUMAN_ALERTS_V1=true;

var TICK_MS=2500;
var S={actorId:null,seen:Object.create(null),seeded:false,busy:false,timer:null,audio:null,lastBootAt:0,enabled:true};
try{S.enabled=localStorage.getItem('aos_wa_human_alerts')!=='0';}catch(_){}

function token(){try{return String(sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||'').trim();}catch(_){return '';}}
function api(path){var t=token();if(t.length<32)return Promise.reject(new Error('AOS_2FA_SESSION_MISSING'));return fetch(path,{method:'GET',headers:{Accept:'application/json','X-AOS-App-Token':t},cache:'no-store',credentials:'same-origin'}).then(function(r){return r.text().then(function(txt){var d={};try{d=txt?JSON.parse(txt):{};}catch(_){d={};}if(!r.ok||d.ok===false){var e=new Error(d.error||('HTTP_'+r.status));e.status=r.status;throw e;}return d;});});}
function isWaView(){try{return window.AOS&&(AOS.activeView==='admin-whatsapp'||AOS.activeView==='whatsapp-agent');}catch(_){return false;}}
function qualifies(r){return !!(r&&S.actorId&&r.owner_user_id===S.actorId&&r.state==='HUMAN_ACTIVE'&&r.last_message_direction==='INBOUND'&&r.last_message_id);}
function safeName(r){return String(r&&r.contact_name||'un lead').trim().slice(0,80)||'un lead';}

function primeAudio(){if(!S.enabled)return;try{var C=window.AudioContext||window.webkitAudioContext;if(!C)return;if(!S.audio)S.audio=new C();if(S.audio.state==='suspended')S.audio.resume().catch(function(){});}catch(_){}}
function chime(){if(!S.enabled)return;primeAudio();var c=S.audio;if(!c||c.state!=='running')return;try{var now=c.currentTime,g=c.createGain();g.gain.setValueAtTime(0.0001,now);g.gain.exponentialRampToValueAtTime(0.18,now+0.012);g.gain.exponentialRampToValueAtTime(0.0001,now+0.34);g.connect(c.destination);[[880,0,0.13],[1174.66,0.14,0.17]].forEach(function(n){var o=c.createOscillator();o.type='sine';o.frequency.setValueAtTime(n[0],now+n[1]);o.connect(g);o.start(now+n[1]);o.stop(now+n[1]+n[2]);});}catch(_){}}
function notification(r){if(!S.enabled||typeof Notification==='undefined'||Notification.permission!=='granted')return;try{var n=new Notification('Nuevo WhatsApp asignado',{body:'Nuevo mensaje de '+safeName(r)+'.',tag:'aos-wa-human-'+r.id,renotify:true,silent:true,icon:'/icons/icon-192x192.png'});n.onclick=function(){try{window.focus();localStorage.setItem('aos_wa_selected',r.id);var view=(window.AOS&&AOS.role==='ADMIN')?'admin-whatsapp':'whatsapp-agent';if(typeof window.navigateTo==='function')window.navigateTo(view);}catch(_){}try{n.close();}catch(_){}};}catch(_){}}
function fire(r){chime();if(document.hidden||!isWaView())notification(r);}
function inspect(rows){rows=Array.isArray(rows)?rows:[];if(!S.seeded){rows.forEach(function(r){if(r&&r.id)S.seen[r.id]=String(r.last_message_id||'');});S.seeded=true;return;}rows.forEach(function(r){if(!r||!r.id)return;var cur=String(r.last_message_id||''),prev=Object.prototype.hasOwnProperty.call(S.seen,r.id)?String(S.seen[r.id]||''):null;S.seen[r.id]=cur;if(!cur)return;if(prev===null){if(qualifies(r))fire(r);return;}if(cur!==prev&&qualifies(r))fire(r);});}
function ensureActor(){if(S.actorId&&Date.now()-S.lastBootAt<60000)return Promise.resolve(S.actorId);return api('/api/wa3/bootstrap').then(function(d){S.actorId=d&&d.actor&&d.actor.id||null;S.lastBootAt=Date.now();return S.actorId;});}
function tick(){if(S.busy||!S.enabled||token().length<32)return;S.busy=true;ensureActor().then(function(){if(!S.actorId)return null;return api('/api/wa3/inbox?limit=120');}).then(function(d){if(d)inspect(d.rows||[]);}).catch(function(e){if(e&&e.status===403){S.actorId=null;S.seeded=false;S.seen=Object.create(null);}}).finally(function(){S.busy=false;});}
function start(){if(S.timer)return;tick();S.timer=setInterval(tick,TICK_MS);}
function stop(){if(S.timer)clearInterval(S.timer);S.timer=null;}
function enable(){S.enabled=true;try{localStorage.setItem('aos_wa_human_alerts','1');}catch(_){}primeAudio();start();if(typeof Notification!=='undefined'&&Notification.permission==='default'){try{return Notification.requestPermission().then(function(p){return {enabled:true,notification_permission:p};});}catch(_){}}return Promise.resolve({enabled:true,notification_permission:typeof Notification==='undefined'?'unsupported':Notification.permission});}
function disable(){S.enabled=false;try{localStorage.setItem('aos_wa_human_alerts','0');}catch(_){}stop();return {enabled:false};}
function status(){return {enabled:S.enabled,actor_id:S.actorId,notification_permission:typeof Notification==='undefined'?'unsupported':Notification.permission,seeded:S.seeded};}
function test(){primeAudio();chime();return status();}

document.addEventListener('pointerdown',function(e){primeAudio();var n=e.target&&e.target.closest?e.target.closest('#nav-admin-whatsapp,#nav-whatsapp-agent'):null;if(n&&S.enabled&&typeof Notification!=='undefined'&&Notification.permission==='default'){try{Notification.requestPermission().catch(function(){});}catch(_){}}},{capture:true});
window.addEventListener('focus',function(){tick();});
document.addEventListener('visibilitychange',function(){if(!document.hidden)tick();});
window.AOS_WA_ALERTS={start:start,stop:stop,enable:enable,disable:disable,status:status,test:test};
start();
})();
