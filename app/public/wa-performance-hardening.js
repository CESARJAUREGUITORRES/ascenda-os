// ASCENDA Conversations — WA-3 read coalescing / adaptive in-memory cache.
// P0 #485: foreground stability, stale-client backoff and service-vs-auth UI separation.
(function(){
'use strict';
if(window.AOS_WA_PERF&&window.AOS_WA_PERF.installed)return;
var baseFetch=window.fetch.bind(window);
var cache=new Map(),inflight=new Map(),failures=new Map(),epoch=0;
var lastVerifiedAt=0,authDeniedUntil=0,serviceObserver=null;
var AUTH_BACKOFF_MS=120000,RECENT_VERIFY_MS=15000,STALE_MAX_MS=120000;
var metrics={requests:0,network:0,cache_hits:0,coalesced:0,invalidations:0,stale_retries:0,backoff_hits:0,auth_backoff_hits:0,service_card_patches:0,transient_auth_remaps:0};
var rules=[
  {test:function(u){return u.pathname==='/api/wa3/inbox';},visible:8000,hidden:60000},
  {test:function(u){return u.pathname==='/api/wa3/queue-summary';},visible:12000,hidden:60000},
  {test:function(u){return u.pathname==='/api/wa3/team-summary';},visible:20000,hidden:60000},
  {test:function(u){return /^\/api\/wa3\/conversations\/[0-9a-f-]{36}\/messages$/i.test(u.pathname);},visible:5000,hidden:60000}
];
function methodOf(input,init){return String(init&&init.method||(input&&input.method)||'GET').toUpperCase();}
function urlOf(input){try{return new URL(typeof input==='string'?input:(input&&input.url)||'',location.href);}catch(_){return null;}}
function ruleFor(u){if(!u||u.origin!==location.origin)return null;for(var i=0;i<rules.length;i++)if(rules[i].test(u))return rules[i];return null;}
function ttlFor(rule){return document.hidden?rule.hidden:rule.visible;}
function keyFor(u){return u.pathname+u.search;}
function snapshot(resp,body){var hs=[];try{resp.headers.forEach(function(v,k){hs.push([k,v]);});}catch(_){}return {status:resp.status,statusText:resp.statusText,headers:hs,body:body};}
function materialize(s,kind,statusOverride){var h=new Headers(s.headers||[]);h.set('X-AOS-WA-Perf',kind||'HIT');var status=statusOverride||s.status;return new Response(s.body,{status:status,statusText:status===503?'Service Unavailable':s.statusText,headers:h});}
function synthetic(status,error,kind){return new Response(JSON.stringify({ok:false,error:error,retryable:status>=500}),{status:status,headers:{'Content-Type':'application/json','Cache-Control':'no-store','X-AOS-WA-Perf':kind||'SYNTHETIC'}});}
function invalidate(reason){epoch++;cache.clear();inflight.clear();failures.clear();metrics.invalidations++;try{window.dispatchEvent(new CustomEvent('aos-wa-perf-invalidated',{detail:{reason:reason||'unknown'}}));}catch(_){} }
function cacheableResponse(resp){return !!resp&&resp.ok===true&&resp.status>=200&&resp.status<300;}
function readCached(key,rule){var x=cache.get(key);if(!x)return null;if(Date.now()-x.at>=ttlFor(rule))return null;return x.snapshot;}
function readStale(key){var x=cache.get(key);if(!x)return null;if(Date.now()-x.at>STALE_MAX_MS){cache.delete(key);return null;}return x.snapshot;}
function store(key,s){cache.set(key,{at:Date.now(),snapshot:s});}
function failure(key){var x=failures.get(key);if(!x){x={count:0,until:0};failures.set(key,x);}return x;}
function markFailure(key){var x=failure(key);x.count=Math.min(6,x.count+1);var wait=Math.min(60000,15000*Math.pow(2,x.count-1));x.until=Date.now()+wait;return wait;}
function clearFailure(key){failures.delete(key);}
function backoffOpen(key){var x=failures.get(key);return !!(x&&Date.now()<x.until);}
function parseBody(body){try{return body?JSON.parse(body):{};}catch(_){return {};}}
function trueAuthDenial(status,data){if(status!==401&&status!==403)return false;var e=String(data&&data.error||'');return e==='WA3_2FA_PANEL_REQUIRED'||e==='AOS_2FA_SESSION_MISSING'||e==='PUSH_APP_SESSION_REQUIRED';}
function recentlyVerified(){return lastVerifiedAt&&Date.now()-lastVerifiedAt<RECENT_VERIFY_MS;}
function serviceCode(code){var c=String(code||'');return c==='WA3_AUTH_UPSTREAM_UNAVAILABLE'||c==='WA3_INBOX_UNAVAILABLE'||c==='WA3_BOOTSTRAP_UNAVAILABLE'||c==='WA3_MESSAGES_UNAVAILABLE'||c==='WA3_TEAM_SUMMARY_UNAVAILABLE'||c==='WA3_QUEUE_SUMMARY_UNAVAILABLE'||c==='WA3_SERVICE_BACKOFF'||c==='WA3V2_INNER_UNAVAILABLE'||/^HTTP_5\d\d$/.test(c);}
function repairServiceCard(){
  if(!document||typeof document.querySelector!=='function')return;
  var box=document.querySelector('.wa8-authbox');if(!box)return;
  var bold=box.querySelector('b'),code=String(bold&&bold.textContent||'').trim();if(!serviceCode(code))return;
  var h=box.querySelector('h3'),p=box.querySelector('p'),b=box.querySelector('button');
  if(h)h.textContent='WhatsApp Hub temporalmente no disponible';
  if(p)p.innerHTML='Tu sesión de ASCENDA sigue activa. El servicio de WhatsApp no respondió a tiempo y se reintentará sin cerrar tu sesión.<br><b>'+String(code).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];})+'</b>';
  if(b){b.textContent='Reintentar WhatsApp';b.onclick=function(){var v=window.AOS&&AOS.activeView||'admin-whatsapp';if(typeof window.navigateTo==='function')window.navigateTo(v);else location.reload();};}
  if(!box.dataset.aosP0485){box.dataset.aosP0485='1';metrics.service_card_patches++;}
}
function installServiceGuard(tries){
  if(!document||typeof document.getElementById!=='function'||typeof MutationObserver!=='function')return;
  var ws=document.getElementById('workspace');if(!ws){if((tries||0)<80)setTimeout(function(){installServiceGuard((tries||0)+1);},250);return;}
  if(serviceObserver)serviceObserver.disconnect();serviceObserver=new MutationObserver(repairServiceCard);serviceObserver.observe(ws,{childList:true,subtree:true});repairServiceCard();
}
window.fetch=function(input,init){
  metrics.requests++;
  var method=methodOf(input,init),u=urlOf(input);
  if(method!=='GET'){
    if(u&&u.origin===location.origin&&u.pathname.indexOf('/api/wa3/')===0&&u.pathname!=='/api/wa3/presence')invalidate(method+' '+u.pathname);
    metrics.network++;
    return baseFetch(input,init);
  }
  var rule=ruleFor(u);
  if(!rule){metrics.network++;return baseFetch(input,init);}
  if(Date.now()<authDeniedUntil){metrics.auth_backoff_hits++;return Promise.resolve(synthetic(403,'WA3_2FA_PANEL_REQUIRED','AUTH-BACKOFF'));}
  var key=keyFor(u),hit=readCached(key,rule);
  if(hit){metrics.cache_hits++;return Promise.resolve(materialize(hit,'HIT'));}
  if(backoffOpen(key)){
    metrics.backoff_hits++;
    var stale=readStale(key);if(stale)return Promise.resolve(materialize(stale,'STALE-BACKOFF'));
    return Promise.resolve(synthetic(503,'WA3_SERVICE_BACKOFF','BACKOFF'));
  }
  if(inflight.has(key)){
    metrics.coalesced++;
    return inflight.get(key).then(function(s){if(s)return materialize(s,'COALESCED');metrics.stale_retries++;return window.fetch(input,init);});
  }
  metrics.network++;
  var requestEpoch=epoch;
  var pipeline=baseFetch(input,init).then(function(resp){
    return resp.text().then(function(body){
      var data=parseBody(body),status=Number(resp.status||0),s=snapshot(resp,body);
      if(status===403&&String(data&&data.error||'')==='WA3_2FA_PANEL_REQUIRED'&&recentlyVerified()){
        metrics.transient_auth_remaps++;markFailure(key);
        s.status=503;s.statusText='Service Unavailable';s.body=JSON.stringify({ok:false,error:'WA3_AUTH_UPSTREAM_UNAVAILABLE',retryable:true});
        return {cache:null,response:materialize(s,'AUTH-UPSTREAM-REMAP',503),stale:false};
      }
      if(cacheableResponse(resp)){
        lastVerifiedAt=Date.now();authDeniedUntil=0;clearFailure(key);
        var fresh=requestEpoch===epoch;if(fresh)store(key,s);
        return {cache:fresh?s:null,response:fresh?materialize(s,'MISS'):null,stale:!fresh};
      }
      if(trueAuthDenial(status,data))authDeniedUntil=Date.now()+AUTH_BACKOFF_MS;
      if(status===408||status===429||status>=500)markFailure(key);
      return {cache:null,response:materialize(s,'ERROR'),stale:false};
    }).catch(function(){return {cache:null,response:resp,stale:false};});
  }).catch(function(e){markFailure(key);throw e;});
  var shared=pipeline.then(function(x){return x.cache;}).catch(function(){return null;});
  inflight.set(key,shared);
  shared.finally(function(){if(inflight.get(key)===shared)inflight.delete(key);});
  return pipeline.then(function(x){if(x.stale){metrics.stale_retries++;return window.fetch(input,init);}return x.response;});
};
function fresh(){invalidate('foreground');}
window.addEventListener('online',fresh);
document.addEventListener('visibilitychange',function(){if(!document.hidden)fresh();});
installServiceGuard(0);
window.AOS_WA_PERF={installed:true,invalidate:invalidate,repairServiceCard:repairServiceCard,stats:function(){return Object.assign({cache_entries:cache.size,inflight:inflight.size,backoff_keys:failures.size,epoch:epoch,hidden:document.hidden,last_verified_at:lastVerifiedAt||null,auth_backoff_until:authDeniedUntil||null},metrics);}};
})();
