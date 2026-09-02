/* ASCENDA OS — Marketing P0 read-pressure bootstrap V1.2
 * Keeps the certified V4.2 controller byte-for-byte in admin-marketing-v2-core.js.
 * This bootstrap only shapes read pressure: single-flight, short-lived read cache,
 * viewport-gating for the two expensive annual analytics (History + LTV),
 * suppression of the redundant legacy aos_ltv_cohortes read once V4.2 is mounted,
 * and one-at-a-time execution for heavy monthly attribution/intent reads.
 */
(function(){
'use strict';

var RELEASE='2026-09-02-p0-marketing-read-pressure-v1.2';
var G=window.__AOS_MKT_PERF_V1;

if(!G){
  var baseFetch=window.fetch.bind(window);
  var cache=new Map();
  var inflight=new Map();
  var insightTail=Promise.resolve();
  var stats={network:0,cacheHit:0,coalesced:0,deferred:0,suppressedLegacyLtv:0,serializedInsights:0};
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
  var serialInsights={
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
      // Safety fallback: analytics eventually arrive even if browser/layout visibility is unusual.
      timer=setTimeout(finish,12000);
      if(signal&&signal.addEventListener)signal.addEventListener('abort',onAbort,{once:true});
    });
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
  function runSerializedInsight(input,init,signal){
    var queued=insightTail.catch(function(){}).then(function(){
      if(aborted(signal))throw abortError();
      stats.serializedInsights++;
      stats.network++;
      // Once a read-only insight reaches PostgREST, do not abort the HTTP request.
      // Aborting fetch does not reliably cancel the PostgreSQL statement and can let
      // the next month overlap it. The V4.2 cycle guard still discards stale results.
      return baseFetch(input,withoutSignal(init)).then(snap);
    });
    insightTail=queued.then(function(){},function(){});
    return queued;
  }

  window.fetch=function(input,init){
    var url=typeof input==='string'?input:(input&&input.url)||'';
    var fn=fnFrom(url);
    var method=String((init&&init.method)||'GET').toUpperCase();

    // V4.2 owns History/LTV rendering. The legacy mkL() still asks aos_ltv_cohortes
    // only to feed rHist/rLTV callbacks that V4.2 already intercepts and ignores.
    // Once V4.2 is mounted, return an empty successful payload locally instead of
    // spending ~0.7-1.1s of Supabase work on every month switch.
    if(method==='POST'&&fn==='aos_ltv_cohortes'&&window.__AOS_MKT4){
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
      if(serialInsights[fn])return runSerializedInsight(input,init,signal);
      stats.network++;
      return baseFetch(input,init).then(snap);
    }).then(function(x){
      cache.set(key,{ts:Date.now(),snap:x});
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