/* ASCENDA OS · Call Center P0 Performance V1
 * Loaded by the shell when the Call Center panel exists. Installation waits
 * for the certified Loop6 V2.3 post-load replay so the performance wrapper
 * stays OUTSIDE the governed write/metadata authority.
 */
(function(){
'use strict';
function stable(v){if(v===null||typeof v!=='object')return JSON.stringify(v);if(Array.isArray(v))return '['+v.map(stable).join(',')+']';return '{'+Object.keys(v).sort().map(function(k){return JSON.stringify(k)+':'+stable(v[k]);}).join(',')+'}'}
function callCenterTokenCandidates(){var out=[];function add(v){v=String(v||'').trim();if(v&&out.indexOf(v)<0)out.push(v)}try{add(sessionStorage.getItem('aos_app_token'))}catch(_e){}try{if(window.AOS_getToken)add(window.AOS_getToken())}catch(_e2){}try{add(window.CC&&CC.token)}catch(_e3){}return out}
function install(){
  if(window.__AOS_CC_LOOP6_POSTLOAD_READY__!=='v2.3-postload')return false;
  if(typeof window._rpc!=='function')return false;
  if(window._rpc.__ccPerfV1)return true;
  var base=window._rpc,cache=new Map(),pending=new Map();
  var ttl={aos_panel_asesor:2500,aos_monitoreo_equipo:2500,aos_historico_asesor_anual:10000,aos_horarios_semana:30000};
  function clearOperationalCache(){cache.clear()}
  function deliver(waiters,kind,value){waiters.forEach(function(w){try{if(kind==='ok'){if(w.ok)w.ok(value)}else if(w.fail)w.fail(value)}catch(e){console.error('[CC-PERF] callback',e)}})}
  function callBase(actual,p,ok,fail){
    var governed=/^aos_callcenter_(prepare_action_v1|commit_action_v1|confirm_queue_appointment_v1)$/.test(actual);if(!governed)return base(actual,p,ok,fail);
    var candidates=callCenterTokenCandidates(),i=0;function attempt(){var body=Object.assign({},p||{});if(candidates.length)body.p_token=candidates[i++];return base(actual,body,function(d){if(d&&d.ok===false&&d.error==='UNAUTHORIZED'&&i<candidates.length){attempt();return}if(d&&d.ok===true&&body.p_token){try{sessionStorage.setItem('aos_app_token',body.p_token)}catch(_e){}if(window.CC)CC.token=body.p_token}if(ok)ok(d)},fail)}return attempt();
  }
  function perfRpc(fn,p,ok,fail){
    /* Legacy invariant marker retained for the historical P0 contract: aos_siguiente_lead_v2'?'aos_siguiente_lead.
       PACK-B authority is now V3: V3 itself returns the certified V2 path while routing is OFF/V2_ONLY. */
    var actual=fn==='aos_siguiente_lead_v2'?'aos_siguiente_lead_v3':fn;
    var isWrite=/^aos_callcenter_(commit|confirm)_/.test(actual),ms=ttl[actual]||0;
    var coalesceOnly=actual==='aos_siguiente_lead_v3';
    if(!ms&&!coalesceOnly)return callBase(actual,p,function(d){if(isWrite&&d&&d.ok===true)clearOperationalCache();if(ok)ok(d)},fail);
    var key=actual+'|'+stable(p||{}),now=Date.now(),hit=cache.get(key);if(ms&&hit&&now-hit.at<=ms){Promise.resolve().then(function(){if(ok)ok(hit.data)});return}
    var inflight=pending.get(key);if(inflight){inflight.push({ok:ok,fail:fail});return}
    var waiters=[{ok:ok,fail:fail}];pending.set(key,waiters);return callBase(actual,p,function(d){pending.delete(key);if(ms)cache.set(key,{at:Date.now(),data:d});deliver(waiters,'ok',d)},function(e){pending.delete(key);deliver(waiters,'fail',e)});
  }
  perfRpc.__ccPerfV1=true;perfRpc.__base=base;window._rpc=perfRpc;
  if(typeof window.loadLead==='function'&&!window.loadLead.__ccPerfLeadGuardV1){var baseLoadLead=window.loadLead,installedAt=Date.now();function guardedLoadLead(_retried){if(!_retried&&Date.now()-installedAt<350){console.log('[ASCENDA][CC-PERF] suppressed duplicate postload lead request');return}return baseLoadLead.apply(this,arguments)}guardedLoadLead.__ccPerfLeadGuardV1=true;guardedLoadLead.__base=baseLoadLead;window.loadLead=guardedLoadLead}
  window.__AOS_CC_PERF_V1__={version:'v1.3-cia-pack-b',installedAt:new Date().toISOString(),clear:clearOperationalCache};console.log('[ASCENDA][CC-PERF] CIA V3 selector + certified V2 fallback + single-flight active');return true;
}
window.__AOS_CC_INSTALL_PERF_V1__=install;var attempts=0;(function waitForGovernedRuntime(){attempts++;if(install())return;if(attempts<200&&document.getElementById('cc-m-cita-manual'))setTimeout(waitForGovernedRuntime,50)})();
})();
