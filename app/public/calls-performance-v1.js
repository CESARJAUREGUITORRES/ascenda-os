/* ASCENDA OS · Call Center P0 Performance V1
 * Loaded by the shell when the Call Center panel exists. Installation waits
 * for the certified Loop6 V2.3 post-load replay so the performance wrapper
 * stays OUTSIDE the governed write/metadata authority.
 */
(function(){
'use strict';

function stable(v){
  if(v===null||typeof v!=='object')return JSON.stringify(v);
  if(Array.isArray(v))return '['+v.map(stable).join(',')+']';
  return '{'+Object.keys(v).sort().map(function(k){return JSON.stringify(k)+':'+stable(v[k]);}).join(',')+'}';
}

function install(){
  if(window.__AOS_CC_LOOP6_POSTLOAD_READY__!=='v2.3-postload')return false;
  if(typeof window._rpc!=='function')return false;
  if(window._rpc.__ccPerfV1)return true;

  var base=window._rpc;
  var cache=new Map();
  var pending=new Map();
  var ttl={
    aos_panel_asesor:2500,
    aos_monitoreo_equipo:2500,
    aos_historico_asesor_anual:10000,
    aos_horarios_semana:30000
  };

  function clearOperationalCache(){cache.clear();}
  function deliver(waiters,kind,value){
    waiters.forEach(function(w){
      try{
        if(kind==='ok'){if(w.ok)w.ok(value);}
        else if(w.fail)w.fail(value);
      }catch(e){console.error('[CC-PERF] callback',e);}
    });
  }

  function perfRpc(fn,p,ok,fail){
    // calls.js still invokes _v2. The certified selector is aos_siguiente_lead;
    // because `base` is Loop6, CONTACT_DEBT/lead lineage metadata is preserved.
    var actual=fn==='aos_siguiente_lead_v2'?'aos_siguiente_lead':fn;
    var isWrite=/^aos_callcenter_(commit|confirm)_/.test(actual);
    var ms=ttl[actual]||0;

    if(!ms){
      return base(actual,p,function(d){
        if(isWrite&&d&&d.ok===true)clearOperationalCache();
        if(ok)ok(d);
      },fail);
    }

    var key=actual+'|'+stable(p||{}),now=Date.now(),hit=cache.get(key);
    if(hit&&now-hit.at<=ms){
      Promise.resolve().then(function(){if(ok)ok(hit.data);});
      return;
    }

    var inflight=pending.get(key);
    if(inflight){inflight.push({ok:ok,fail:fail});return;}

    var waiters=[{ok:ok,fail:fail}];
    pending.set(key,waiters);
    return base(actual,p,function(d){
      pending.delete(key);
      cache.set(key,{at:Date.now(),data:d});
      deliver(waiters,'ok',d);
    },function(e){
      pending.delete(key);
      deliver(waiters,'fail',e);
    });
  }

  perfRpc.__ccPerfV1=true;
  perfRpc.__base=base;
  window._rpc=perfRpc;
  window.__AOS_CC_PERF_V1__={version:'v1',installedAt:new Date().toISOString(),clear:clearOperationalCache};
  console.log('[ASCENDA][CC-PERF] P0 read coalescing + governed lead selector active');
  return true;
}

window.__AOS_CC_INSTALL_PERF_V1__=install;
var attempts=0;
(function waitForGovernedRuntime(){
  attempts++;
  if(install())return;
  if(attempts<200&&document.getElementById('cc-m-cita-manual'))setTimeout(waitForGovernedRuntime,50);
})();
})();
