// ASCENDA Conversations — WA-3 read coalescing / adaptive in-memory cache.
(function(){
'use strict';
if(window.AOS_WA_PERF&&window.AOS_WA_PERF.installed)return;
var baseFetch=window.fetch.bind(window);
var cache=new Map(),inflight=new Map(),epoch=0;
var metrics={requests:0,network:0,cache_hits:0,coalesced:0,invalidations:0};
var rules=[
  {test:function(u){return u.pathname==='/api/wa3/inbox';},visible:4000,hidden:20000},
  {test:function(u){return u.pathname==='/api/wa3/queue-summary';},visible:4000,hidden:15000},
  {test:function(u){return u.pathname==='/api/wa3/team-summary';},visible:4000,hidden:15000},
  {test:function(u){return /^\/api\/wa3\/conversations\/[0-9a-f-]{36}\/messages$/i.test(u.pathname);},visible:3500,hidden:20000}
];
function methodOf(input,init){return String(init&&init.method||(input&&input.method)||'GET').toUpperCase();}
function urlOf(input){try{return new URL(typeof input==='string'?input:(input&&input.url)||'',location.href);}catch(_){return null;}}
function ruleFor(u){if(!u||u.origin!==location.origin)return null;for(var i=0;i<rules.length;i++)if(rules[i].test(u))return rules[i];return null;}
function ttlFor(rule){return document.hidden?rule.hidden:rule.visible;}
function keyFor(u){return u.pathname+u.search;}
function snapshot(resp,body){var hs=[];try{resp.headers.forEach(function(v,k){hs.push([k,v]);});}catch(_){}return {status:resp.status,statusText:resp.statusText,headers:hs,body:body};}
function materialize(s,kind){var h=new Headers(s.headers||[]);h.set('X-AOS-WA-Perf',kind||'HIT');return new Response(s.body,{status:s.status,statusText:s.statusText,headers:h});}
function invalidate(reason){epoch++;cache.clear();inflight.clear();metrics.invalidations++;try{window.dispatchEvent(new CustomEvent('aos-wa-perf-invalidated',{detail:{reason:reason||'unknown'}}));}catch(_){} }
function cacheableResponse(resp){return !!resp&&resp.ok===true&&resp.status>=200&&resp.status<300;}
function readCached(key,rule){var x=cache.get(key);if(!x)return null;if(Date.now()-x.at>=ttlFor(rule)){cache.delete(key);return null;}return x.snapshot;}
function store(key,s){cache.set(key,{at:Date.now(),snapshot:s});}
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
  var key=keyFor(u),hit=readCached(key,rule);
  if(hit){metrics.cache_hits++;return Promise.resolve(materialize(hit,'HIT'));}
  if(inflight.has(key)){
    metrics.coalesced++;
    return inflight.get(key).then(function(s){if(s)return materialize(s,'COALESCED');metrics.network++;return baseFetch(input,init);});
  }
  metrics.network++;
  var requestEpoch=epoch;
  var pipeline=baseFetch(input,init).then(function(resp){
    if(!cacheableResponse(resp))return {cache:null,response:resp};
    return resp.text().then(function(body){
      var s=snapshot(resp,body),fresh=requestEpoch===epoch;
      if(fresh)store(key,s);
      return {cache:fresh?s:null,response:materialize(s,fresh?'MISS':'STALE')};
    }).catch(function(){return {cache:null,response:resp};});
  });
  var shared=pipeline.then(function(x){return x.cache;}).catch(function(){return null;});
  inflight.set(key,shared);
  shared.finally(function(){if(inflight.get(key)===shared)inflight.delete(key);});
  return pipeline.then(function(x){return x.response;});
};
function fresh(){invalidate('foreground');}
window.addEventListener('focus',fresh);
window.addEventListener('online',fresh);
document.addEventListener('visibilitychange',function(){if(!document.hidden)fresh();});
window.AOS_WA_PERF={installed:true,invalidate:invalidate,stats:function(){return Object.assign({cache_entries:cache.size,inflight:inflight.size,epoch:epoch,hidden:document.hidden},metrics);}};
})();
