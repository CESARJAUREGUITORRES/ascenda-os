/* ASCENDA OS · Call Center P0 Performance V1
 * Loaded by the shell when the Call Center panel exists. Installation waits
 * for the certified Loop6 V2.3 post-load replay so the performance wrapper
 * stays OUTSIDE the governed write/metadata authority.
 */
(function(){
'use strict';
function stable(v){if(v===null||typeof v!=='object')return JSON.stringify(v);if(Array.isArray(v))return '['+v.map(stable).join(',')+']';return '{'+Object.keys(v).sort().map(function(k){return JSON.stringify(k)+':'+stable(v[k]);}).join(',')+'}'}
function callCenterTokenCandidates(p){var out=[];function add(v){v=String(v||'').trim();if(v.length>=32&&out.indexOf(v)<0)out.push(v)}try{add(p&&p.p_token)}catch(_e0){}try{add(sessionStorage.getItem('aos_app_token'))}catch(_e){}try{if(window.AOS_getToken)add(window.AOS_getToken())}catch(_e2){}try{add(window.CC&&CC.token)}catch(_e3){}return out}
function cachedCallCenterToken(){if(!('caches' in window))return Promise.resolve('');return caches.open('aos-phase2-auth').then(function(c){return c.match('/__aos_app_token')}).then(function(r){return r?r.text():''}).then(function(t){t=String(t||'').trim();return t.length>=32?t:''}).catch(function(){return ''})}
function persistCallCenterToken(t){t=String(t||'').trim();if(t.length<32)return;try{sessionStorage.setItem('aos_app_token',t)}catch(_e){}if(window.CC)CC.token=t}
function install(){
  if(window.__AOS_CC_LOOP6_POSTLOAD_READY__!=='v2.3-postload')return false;
  if(typeof window._rpc!=='function')return false;
  if(window._rpc.__ccPerfV1)return true;
  var base=window._rpc,cache=new Map(),pending=new Map();
  var ttl={aos_panel_asesor:2500,aos_monitoreo_equipo:2500,aos_historico_asesor_anual:10000,aos_horarios_semana:30000};
  function clearOperationalCache(){cache.clear()}
  function deliver(waiters,kind,value){waiters.forEach(function(w){try{if(kind==='ok'){if(w.ok)w.ok(value)}else if(w.fail)w.fail(value)}catch(e){console.error('[CC-PERF] callback',e)}})}
  function directGovernedFallback(actual,p,ok,fail){
    var candidates=callCenterTokenCandidates(p),i=0,cacheTried=false,lastUnauthorized=null;
    function finishUnauthorized(){if(ok)ok(lastUnauthorized||{ok:false,error:'UNAUTHORIZED'})}
    function recoverFromCache(){
      if(cacheTried){finishUnauthorized();return}
      cacheTried=true;
      return cachedCallCenterToken().then(function(t){
        if(t&&candidates.indexOf(t)<0){candidates.push(t);attempt();return}
        finishUnauthorized();
      }).catch(function(){finishUnauthorized()});
    }
    function attempt(){
      if(i>=candidates.length){recoverFromCache();return}
      var body=Object.assign({},p||{});body.p_token=candidates[i++];
      return base(actual,body,function(d){
        if(d&&d.ok===false&&d.error==='UNAUTHORIZED'&&i<candidates.length){lastUnauthorized=d;attempt();return}
        if(d&&d.ok===false&&d.error==='UNAUTHORIZED'){lastUnauthorized=d;recoverFromCache();return}
        if(d&&d.ok===true&&body.p_token)persistCallCenterToken(body.p_token);
        if(ok)ok(d);
      },fail);
    }
    return attempt();
  }
  function sameOriginGoverned(actual,p,ok,fail){
    var payload=Object.assign({},p||{});try{delete payload.p_token}catch(_e){}
    if(typeof window.AOS_callCenterCookieRpc!=='function')return directGovernedFallback(actual,p,ok,fail);
    return window.AOS_callCenterCookieRpc(actual,payload).then(function(x){
      var d=x&&x.data,status=Number(x&&x.status||0);
      // Cookie missing/expired or older server without the route: retain the
      // certified direct-token recovery as a compatibility fallback.
      if(status===401||status===404||status===405||(d&&d.ok===false&&(d.error==='APP_SESSION_REQUIRED'||d.error==='UNAUTHORIZED'))){
        return directGovernedFallback(actual,p,ok,fail);
      }
      if(!d){if(fail)fail(new Error('CALLCENTER_BRIDGE_INVALID_RESPONSE'));return}
      if(ok)ok(d);
    }).catch(function(e){
      // Do not blindly replay a governed write after an ambiguous network
      // failure. UI receives the transport failure and operator can retry.
      if(fail)fail(e);
    });
  }
  function callBase(actual,p,ok,fail){
    var governed=/^aos_callcenter_(prepare_action_v1|commit_action_v1|confirm_queue_appointment_v1)$/.test(actual);
    if(!governed)return base(actual,p,ok,fail);
    return sameOriginGoverned(actual,p,ok,fail);
  }
  function notifyCanaryAssignment(d){
    try{
      var r=d&&d.routingV3;if(!r||r.route!=='V3'||String(r.mode||'').toUpperCase()!=='V3_CANARY')return;
      var id=String(r.assignmentId||r.contactKey||'canary'),k='aos_cia_canary_notice_'+id;
      try{if(sessionStorage.getItem(k))return;sessionStorage.setItem(k,'1')}catch(_e){}
      var msg='🧪 Prueba controlada · 1 contacto asignado. Atiéndelo normalmente.';
      if(window.AOS_showToast)window.AOS_showToast(msg,'','');
      else console.log('[ASCENDA][CIA-CANARY]',msg);
    }catch(_e){}
  }
  function perfRpc(fn,p,ok,fail){
    /* Legacy invariant marker retained for the historical P0 contract: aos_siguiente_lead_v2'?'aos_siguiente_lead'.
       PACK-B authority is now V3: V3 itself returns the certified V2 path while routing is OFF/V2_ONLY. */
    var actual=fn==='aos_siguiente_lead_v2'?'aos_siguiente_lead_v3':fn;
    var isWrite=/^aos_callcenter_(commit|confirm)_/.test(actual),ms=ttl[actual]||0;
    var coalesceOnly=actual==='aos_siguiente_lead_v3';
    if(!ms&&!coalesceOnly)return callBase(actual,p,function(d){if(actual==='aos_siguiente_lead_v3')notifyCanaryAssignment(d);if(isWrite&&d&&d.ok===true)clearOperationalCache();if(ok)ok(d)},fail);
    var key=actual+'|'+stable(p||{}),now=Date.now(),hit=cache.get(key);if(ms&&hit&&now-hit.at<=ms){Promise.resolve().then(function(){if(ok)ok(hit.data)});return}
    var inflight=pending.get(key);if(inflight){inflight.push({ok:ok,fail:fail});return}
    var waiters=[{ok:ok,fail:fail}];pending.set(key,waiters);return callBase(actual,p,function(d){pending.delete(key);if(actual==='aos_siguiente_lead_v3')notifyCanaryAssignment(d);if(ms)cache.set(key,{at:Date.now(),data:d});deliver(waiters,'ok',d)},function(e){pending.delete(key);deliver(waiters,'fail',e)});
  }
  perfRpc.__ccPerfV1=true;perfRpc.__base=base;window._rpc=perfRpc;
  if(typeof window.loadLead==='function'&&!window.loadLead.__ccPerfLeadGuardV1){var baseLoadLead=window.loadLead,installedAt=Date.now();function guardedLoadLead(_retried){if(!_retried&&Date.now()-installedAt<350){console.log('[ASCENDA][CC-PERF] suppressed duplicate postload lead request');return}return baseLoadLead.apply(this,arguments)}guardedLoadLead.__ccPerfLeadGuardV1=true;guardedLoadLead.__base=baseLoadLead;window.loadLead=guardedLoadLead}
  window.__AOS_CC_PERF_V1__={version:'v1.5-cookie-session-bridge',installedAt:new Date().toISOString(),clear:clearOperationalCache};console.log('[ASCENDA][CC-PERF] same-origin HttpOnly session bridge + token-cache fallback active');return true;
}
window.__AOS_CC_INSTALL_PERF_V1__=install;var attempts=0;(function waitForGovernedRuntime(){attempts++;if(install())return;if(attempts<200&&document.getElementById('cc-m-cita-manual'))setTimeout(waitForGovernedRuntime,50)})();
})();
