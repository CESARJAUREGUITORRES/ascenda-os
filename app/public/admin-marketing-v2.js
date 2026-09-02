/* ASCENDA OS — Marketing P0 read-pressure bootstrap V1.4
 * Keeps the certified V4.2 controller byte-for-byte in admin-marketing-v2-core.js.
 * Shapes read pressure only: single-flight, successful-response cache, monthly lane,
 * annual quiescence, startup suppression of obsolete LTV, and one timeout retry.
 */
(function(){
'use strict';

var RELEASE='2026-09-02-p0-marketing-read-pressure-v1.4';
var G=window.__AOS_MKT_PERF_V1;

// SPA remounts can keep an older fetch wrapper alive. Upgrade deterministically by
// restoring its original fetch and installing the current release once.
if(G&&G.release!==RELEASE&&typeof G.baseFetch==='function'){
  try{window.fetch=G.baseFetch;}catch(e){}
  try{delete window.__AOS_MKT_PERF_V1;}catch(e){window.__AOS_MKT_PERF_V1=null;}
  G=null;
}

if(!G){
  var baseFetch=window.fetch.bind(window);
  var cache=new Map();
  var inflight=new Map();
  var monthlyTail=Promise.resolve();
  var annualTail=Promise.resolve();
  var lastCriticalSettledAt=Date.now();
  var QUIET_MS=3500;
  var RETRY_MS=300;
  var stats={
    network:0,cacheHit:0,coalesced:0,deferred:0,suppressedLegacyLtv:0,
    serializedInsights:0,serializedMonthly:0,annualDeferred:0,timeoutRetries:0,
    failedNotCached:0
  };
  var targets={
    aos_marketing_dashboard:2500,
    aos_marketing_dashboard_anio:2500,
    aos_marketing_period_summary_v2:10000,
    aos_marketing_attribution_public_v3:10000,
    aos_marketing_attribution_public_v2_anio:10000,
    aos_marketing_intent_public_v2:10000,
    aos_marketing_intent_detail_public_v3:10000,
    aos_marketing_historico_public_v2:60000,
    aos_marketing_ltv_public_v2:60000
  };
  var lazy={
    aos_marketing_historico_public_v2:'#mk-hist',
    aos_marketing_ltv_public_v2:'#mk-ltv'
  };
  var monthlySerial={
    aos_marketing_period_summary_v2:true,
    aos_marketing_attribution_public_v3:true,
    aos_marketing_intent_public_v2:true,
    aos_marketing_intent_detail_public_v3:true
  };
  var annualReads={
    aos_marketing_historico_public_v2:true,
    aos_marketing_ltv_public_v2:true
  };
  var criticalReads={
    aos_marketing_dashboard:true,
    aos_marketing_period_summary_v2:true,
    aos_marketing_attribution_public_v3:true,
    aos_marketing_intent_public_v2:true,
    aos_marketing_intent_detail_public_v3:true
  };

  function fnFrom(url){
    var m=String(url||'').match(/\/rest\/v1\/rpc\/(aos_marketing_[A-Za-z0-9_]+|aos_ltv_cohortes)/);
    return m?m[1]:'';
  }
  function aborted(signal){return !!(signal&&signal.aborted);}
  function abortError(){
    try{return new DOMException('The operation was aborted.','AbortError');}
    catch(e){var x=new Error('The operation was aborted.');x.name='AbortError';return x;}
  }
  function sleep(ms,signal){
    if(aborted(signal))return Promise.reject(abortError());
    return new Promise(function(resolve,reject){
      var done=false;
      var timer=setTimeout(function(){if(done)return;done=true;clean();resolve();},ms);
      function clean(){if(signal&&signal.removeEventListener)signal.removeEventListener('abort',onAbort);}
      function onAbort(){if(done)return;done=true;clearTimeout(timer);clean();reject(abortError());}
      if(signal&&signal.addEventListener)signal.addEventListener('abort',onAbort,{once:true});
    });
  }
  function visible(el){
    if(!el||!el.getBoundingClientRect)return true;
    var r=el.getBoundingClientRect();
    var h=window.innerHeight||document.documentElement.clientHeight||800;
    return r.bottom>=-300&&r.top<=h+500;
  }
  function waitVisible(selector,signal){
    if(aborted(signal))return Promise.reject(abortError());
    var el=document.querySelector(selector);
    if(!el||visible(el)||typeof IntersectionObserver==='undefined')return Promise.resolve();
    stats.deferred++;
    return new Promise(function(resolve,reject){
      var done=false,timer=null,io=null;
      function clean(){
        if(timer)clearTimeout(timer);
        if(io)io.disconnect();
        if(signal&&signal.removeEventListener)signal.removeEventListener('abort',onAbort);
      }
      function finish(){if(done)return;done=true;clean();resolve();}
      function onAbort(){if(done)return;done=true;clean();reject(abortError());}
      io=new IntersectionObserver(function(entries){
        if(entries.some(function(x){return x.isIntersecting;}))finish();
      },{rootMargin:'500px 0px'});
      io.observe(el);
      timer=setTimeout(finish,12000);
      if(signal&&signal.addEventListener)signal.addEventListener('abort',onAbort,{once:true});
    });
  }
  function waitQuiescent(signal){
    if(aborted(signal))return Promise.reject(abortError());
    var remaining=QUIET_MS-(Date.now()-lastCriticalSettledAt);
    if(remaining<=0)return Promise.resolve();
    stats.annualDeferred++;
    return sleep(remaining,signal).then(function(){return waitQuiescent(signal);});
  }
  function snap(resp){
    return resp.clone().text().then(function(body){
      var headers=[];try{resp.headers.forEach(function(v,k){headers.push([k,v]);});}catch(e){}
      return {body:body,status:resp.status,statusText:resp.statusText,headers:headers};
    });
  }
  function toResponse(x){return new Response(x.body,{status:x.status,statusText:x.statusText,headers:x.headers});}
  function bodyKey(init){
    var b=init&&init.body;
    if(typeof b==='string')return b;
    return b==null?'':String(b);
  }
  function emptyJsonResponse(){
    return new Response('{}',{status:200,headers:{'Content-Type':'application/json'}});
  }
  function withoutSignal(init){
    var x={};
    Object.keys(init||{}).forEach(function(k){if(k!=='signal')x[k]=init[k];});
    return x;
  }
  function timeoutSnap(x){
    return !!(x&&x.status>=500&&(/\"code\"\s*:\s*\"57014\"/i.test(x.body||'')||/statement timeout/i.test(x.body||'')));
  }
  function successful(x){return !!(x&&x.status>=200&&x.status<300);}
  function networkSnap(input,init,signal,allowRetry){
    if(aborted(signal))return Promise.reject(abortError());
    stats.network++;
    // Once a read reaches PostgREST, let it finish. Browser abort does not reliably
    // cancel the server statement and can otherwise create hidden overlap.
    return baseFetch(input,withoutSignal(init)).then(snap).then(function(x){
      if(!allowRetry||!timeoutSnap(x))return x;
      stats.timeoutRetries++;
      return sleep(RETRY_MS,signal).then(function(){
        if(aborted(signal))throw abortError();
        stats.network++;
        return baseFetch(input,withoutSignal(init)).then(snap);
      });
    });
  }
  function waitAnnualDrain(signal){
    return annualTail.catch(function(){}).then(function(){if(aborted(signal))throw abortError();});
  }
  function runMonthly(input,init,signal){
    var queued=monthlyTail.catch(function(){}).then(function(){
      if(aborted(signal))throw abortError();
      return waitAnnualDrain(signal);
    }).then(function(){
      if(aborted(signal))throw abortError();
      stats.serializedMonthly++;
      stats.serializedInsights++;
      return networkSnap(input,init,signal,true);
    }).finally(function(){lastCriticalSettledAt=Date.now();});
    monthlyTail=queued.then(function(){},function(){});
    return queued;
  }
  function runCritical(input,init,signal){
    return waitAnnualDrain(signal).then(function(){
      if(aborted(signal))throw abortError();
      return networkSnap(input,init,signal,true);
    }).finally(function(){lastCriticalSettledAt=Date.now();});
  }
  function runAnnual(input,init,signal){
    return monthlyTail.catch(function(){}).then(function(){
      if(aborted(signal))throw abortError();
      return waitQuiescent(signal);
    }).then(function(){
      if(aborted(signal))throw abortError();
      var queued=annualTail.catch(function(){}).then(function(){
        if(aborted(signal))throw abortError();
        return monthlyTail.catch(function(){});
      }).then(function(){
        if(aborted(signal))throw abortError();
        return waitQuiescent(signal);
      }).then(function(){
        if(aborted(signal))throw abortError();
        return networkSnap(input,init,signal,true);
      });
      annualTail=queued.then(function(){},function(){});
      return queued;
    });
  }

  window.fetch=function(input,init){
    var url=typeof input==='string'?input:(input&&input.url)||'';
    var fn=fnFrom(url);
    var method=String((init&&init.method)||'GET').toUpperCase();

    // V4.2 owns History/LTV rendering; this legacy cohort response is discarded.
    if(method==='POST'&&fn==='aos_ltv_cohortes'){
      stats.suppressedLegacyLtv++;
      return Promise.resolve(emptyJsonResponse());
    }

    if(method!=='POST'||!Object.prototype.hasOwnProperty.call(targets,fn))return baseFetch(input,init);

    var signal=init&&init.signal;
    if(aborted(signal))return Promise.reject(abortError());
    var key=fn+'|'+bodyKey(init);
    var now=Date.now();
    var hit=cache.get(key);
    if(hit&&now-hit.ts<targets[fn]){
      stats.cacheHit++;
      return Promise.resolve(toResponse(hit.snap));
    }
    if(inflight.has(key)){
      stats.coalesced++;
      return inflight.get(key).then(toResponse);
    }

    var p=Promise.resolve();
    if(lazy[fn])p=p.then(function(){return waitVisible(lazy[fn],signal);});
    p=p.then(function(){
      if(aborted(signal))throw abortError();
      if(annualReads[fn])return runAnnual(input,init,signal);
      if(monthlySerial[fn])return runMonthly(input,init,signal);
      if(criticalReads[fn])return runCritical(input,init,signal);
      stats.network++;
      return baseFetch(input,init).then(snap);
    }).then(function(x){
      // A transient API/database error must never poison the short-lived cache.
      if(successful(x))cache.set(key,{ts:Date.now(),snap:x});
      else stats.failedNotCached++;
      return x;
    }).finally(function(){inflight.delete(key);});

    inflight.set(key,p);
    return p.then(toResponse);
  };

  G=window.__AOS_MKT_PERF_V1={
    release:RELEASE,
    stats:stats,
    clear:function(){cache.clear();},
    cacheSize:function(){return cache.size;},
    baseFetch:baseFetch
  };
}else{
  G.release=RELEASE;
}

function loadCore(){
  var old=document.getElementById('aos-marketing-v2-core');if(old)old.remove();
  var s=document.createElement('script');
  s.id='aos-marketing-v2-core';
  s.src='/admin-marketing-v2-core.js?v='+(typeof _APP_VERSION!=='undefined'?_APP_VERSION:Date.now());
  s.onerror=function(){console.error('[ASCENDA] Marketing core load failed');};
  document.head.appendChild(s);
}

loadCore();
console.log('[ASCENDA] Marketing P0 read-pressure bootstrap mounted');
})();