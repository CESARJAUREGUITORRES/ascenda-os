// ASCENDA Conversations — S13 human advisor alerts + PWA-native notifications.
// Alerts only for inbound messages owned by the current actor in HUMAN_ACTIVE mode.
(function(){
'use strict';
if(window.__AOS_WA_HUMAN_ALERTS_V2)return;
window.__AOS_WA_HUMAN_ALERTS_V2=true;

var TICK_MS=2200;
var S={actorId:null,seen:Object.create(null),seeded:false,busy:false,timer:null,audio:null,lastBootAt:0,enabled:true,volume:.72};
try{S.enabled=localStorage.getItem('aos_wa_human_alerts')!=='0';var stored=Number(localStorage.getItem('aos_wa_alert_volume'));if(Number.isFinite(stored))S.volume=Math.min(1,Math.max(.2,stored));}catch(_){}

function token(){try{return String(sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||'').trim();}catch(_){return '';}}
function api(path){var t=token();if(t.length<32)return Promise.reject(new Error('AOS_2FA_SESSION_MISSING'));return fetch(path,{method:'GET',headers:{Accept:'application/json','X-AOS-App-Token':t},cache:'no-store',credentials:'same-origin'}).then(function(r){return r.text().then(function(txt){var d={};try{d=txt?JSON.parse(txt):{};}catch(_){d={};}if(!r.ok||d.ok===false){var e=new Error(d.error||('HTTP_'+r.status));e.status=r.status;throw e;}return d;});});}
function isWaView(){try{return window.AOS&&(AOS.activeView==='admin-whatsapp'||AOS.activeView==='whatsapp-agent');}catch(_){return false;}}
function actorView(){try{return window.AOS&&AOS.role==='ADMIN'?'admin-whatsapp':'whatsapp-agent';}catch(_){return 'admin-whatsapp';}}
function qualifies(r){return !!(r&&S.actorId&&r.owner_user_id===S.actorId&&r.state==='HUMAN_ACTIVE'&&r.last_message_direction==='INBOUND'&&r.last_message_id);}
function safeName(r){return String(r&&r.contact_name||'un lead').trim().slice(0,80)||'un lead';}

function primeAudio(){if(!S.enabled)return;try{var C=window.AudioContext||window.webkitAudioContext;if(!C)return;if(!S.audio)S.audio=new C();if(S.audio.state==='suspended')S.audio.resume().catch(function(){});}catch(_){}}
function pulse(c,out,now,at,freq,dur,level,type){var g=c.createGain(),o=c.createOscillator();g.gain.setValueAtTime(.0001,now+at);g.gain.exponentialRampToValueAtTime(Math.max(.001,level),now+at+.008);g.gain.exponentialRampToValueAtTime(.0001,now+at+dur);o.type=type||'sine';o.frequency.setValueAtTime(freq,now+at);o.connect(g);g.connect(out);o.start(now+at);o.stop(now+at+dur+.02);}
function chime(){if(!S.enabled)return;primeAudio();var c=S.audio;if(!c||c.state!=='running')return;try{var now=c.currentTime,master=c.createGain(),comp=c.createDynamicsCompressor();master.gain.setValueAtTime(S.volume,now);comp.threshold.setValueAtTime(-18,now);comp.knee.setValueAtTime(12,now);comp.ratio.setValueAtTime(6,now);comp.attack.setValueAtTime(.003,now);comp.release.setValueAtTime(.16,now);master.connect(comp);comp.connect(c.destination);pulse(c,master,now,0,880,.12,.56,'sine');pulse(c,master,now,0,1760,.09,.14,'triangle');pulse(c,master,now,.115,1174.66,.19,.64,'sine');pulse(c,master,now,.115,2349.32,.13,.13,'triangle');setTimeout(function(){try{master.disconnect();comp.disconnect();}catch(_){}},500);}catch(_){}}
function openConversation(id){if(!id)return;try{localStorage.setItem('aos_wa_selected',id);}catch(_){}var tries=0;function go(){tries++;try{if(typeof window.navigateTo==='function'){window.navigateTo(actorView());return;}}catch(_){}if(tries<30)setTimeout(go,100);}go();}
function persistentNotification(r){if(!S.enabled||typeof Notification==='undefined'||Notification.permission!=='granted')return Promise.reject(new Error('NOTIFICATION_PERMISSION_MISSING'));var opts={body:'Nuevo mensaje de '+safeName(r)+'.',tag:'aos-wa-human-'+r.id,renotify:true,silent:false,icon:'/icons/icon-192x192.png',badge:'/icons/icon-192x192.png',data:{kind:'AOS_WA_HUMAN',conversationId:r.id,view:actorView()}};if(navigator.serviceWorker&&navigator.serviceWorker.ready){return navigator.serviceWorker.ready.then(function(reg){return reg.showNotification('Nuevo WhatsApp asignado',opts);});}try{var n=new Notification('Nuevo WhatsApp asignado',opts);n.onclick=function(){try{window.focus();openConversation(r.id);}catch(_){}try{n.close();}catch(_){}};return Promise.resolve();}catch(e){return Promise.reject(e);}}
function fire(r){var background=document.hidden||!isWaView();if(background){persistentNotification(r).catch(function(){chime();});}else{chime();}}
function inspect(rows){rows=Array.isArray(rows)?rows:[];if(!S.seeded){rows.forEach(function(r){if(r&&r.id)S.seen[r.id]=String(r.last_message_id||'');});S.seeded=true;return;}rows.forEach(function(r){if(!r||!r.id)return;var cur=String(r.last_message_id||''),prev=Object.prototype.hasOwnProperty.call(S.seen,r.id)?String(S.seen[r.id]||''):null;S.seen[r.id]=cur;if(!cur)return;if(prev===null){if(qualifies(r))fire(r);return;}if(cur!==prev&&qualifies(r))fire(r);});}
function ensureActor(){if(S.actorId&&Date.now()-S.lastBootAt<60000)return Promise.resolve(S.actorId);return api('/api/wa3/bootstrap').then(function(d){S.actorId=d&&d.actor&&d.actor.id||null;S.lastBootAt=Date.now();return S.actorId;});}
function tick(){if(S.busy||!S.enabled||token().length<32)return;S.busy=true;ensureActor().then(function(){if(!S.actorId)return null;return api('/api/wa3/inbox?limit=120');}).then(function(d){if(d)inspect(d.rows||[]);}).catch(function(e){if(e&&e.status===403){S.actorId=null;S.seeded=false;S.seen=Object.create(null);}}).finally(function(){S.busy=false;});}
function start(){if(S.timer)return;tick();S.timer=setInterval(tick,TICK_MS);}
function stop(){if(S.timer)clearInterval(S.timer);S.timer=null;}
function enable(){S.enabled=true;try{localStorage.setItem('aos_wa_human_alerts','1');}catch(_){}primeAudio();start();if(typeof Notification!=='undefined'&&Notification.permission==='default'){try{return Notification.requestPermission().then(function(p){return {enabled:true,notification_permission:p,volume:S.volume};});}catch(_){}}return Promise.resolve({enabled:true,notification_permission:typeof Notification==='undefined'?'unsupported':Notification.permission,volume:S.volume});}
function disable(){S.enabled=false;try{localStorage.setItem('aos_wa_human_alerts','0');}catch(_){}stop();return {enabled:false};}
function setVolume(v){v=Number(v);if(!Number.isFinite(v))return status();S.volume=Math.min(1,Math.max(.2,v));try{localStorage.setItem('aos_wa_alert_volume',String(S.volume));}catch(_){}return status();}
function status(){return {enabled:S.enabled,actor_id:S.actorId,notification_permission:typeof Notification==='undefined'?'unsupported':Notification.permission,seeded:S.seeded,volume:S.volume,pwa_notifications:!!(navigator.serviceWorker&&navigator.serviceWorker.ready)};}
function test(){primeAudio();chime();return status();}
function consumeDeepLink(){try{var u=new URL(location.href),id=u.searchParams.get('wa_conv');if(!id)return;localStorage.setItem('aos_wa_selected',id);u.searchParams.delete('wa_conv');history.replaceState(null,'',u.pathname+(u.search||'')+(u.hash||''));setTimeout(function(){openConversation(id);},250);}catch(_){} }

document.addEventListener('pointerdown',function(e){primeAudio();var n=e.target&&e.target.closest?e.target.closest('#nav-admin-whatsapp,#nav-whatsapp-agent'):null;if(n&&S.enabled&&typeof Notification!=='undefined'&&Notification.permission==='default'){try{Notification.requestPermission().catch(function(){});}catch(_){}}},{capture:true});
window.addEventListener('focus',function(){tick();});
document.addEventListener('visibilitychange',function(){if(!document.hidden)tick();});
if(navigator.serviceWorker&&navigator.serviceWorker.addEventListener){navigator.serviceWorker.addEventListener('message',function(e){var d=e&&e.data||{};if(d.type==='AOS_WA_OPEN_CONVERSATION'&&d.conversationId)openConversation(d.conversationId);});}
window.AOS_WA_ALERTS={start:start,stop:stop,enable:enable,disable:disable,status:status,test:test,setVolume:setVolume};
consumeDeepLink();
start();
})();
