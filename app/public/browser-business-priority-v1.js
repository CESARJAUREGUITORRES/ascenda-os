/* ASCENDA OS · Business Priority Mode P0-B/P0-C + P0 #432
 * Browser read scheduler. It never intercepts or delays governed writes.
 * P0 #432 adds cross-panel single-flight, bounded analytics concurrency,
 * visibility-aware staggering and a short failure cooldown so a fixed +5s UI
 * retry cannot immediately re-hit Supabase after 429/5xx pressure.
 */
(function(){
'use strict';
if(window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__)return;

var baseFetch=window.fetch.bind(window);
var pending=new Map();
var failureCooldown=new Map();
var calendarQueue=[];
var calendarActive=0;
var analyticsQueue=[];
var analyticsActive=0;
var CALENDAR_MAX_CONCURRENCY=2;
var MAX_ANALYTICS_CONCURRENCY=1;
var FAILURE_COOLDOWN_MS=12000;

window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__={
  version:'p0-432-v1.0',
  policy:'critical-immediate__analytics-bounded__failure-cooldown'
};

function urlOf(input){return typeof input==='string'?input:(input&&input.url)||'';}
function rpcName(url){var m=String(url||'').match(/\/rest\/v1\/rpc\/([^?]+)/);return m&&m[1]||'';}
function ccMounted(){return !!document.getElementById('cc-m-cita-manual');}
function text(id){var e=document.getElementById(id);return e?String(e.textContent||'').trim():'';}
function leadBoundaryReady(){
  if(!ccMounted())return true;
  var n=text('cc-num');
  if(n&&n!=='Cargando...'&&n!=='Cargando…')return true;
  var no=document.getElementById('cc-no-lead');
  if(no&&no.style&&no.style.display==='block')return true;
  return false;
}
function sleep(ms){return new Promise(function(r){setTimeout(r,ms);});}
function waitLeadBoundary(maxMs){
  var start=Date.now();
  return new Promise(function(resolve){
    (function check(){
      if(leadBoundaryReady()||Date.now()-start>=maxMs){resolve();return;}
      setTimeout(check,50);
    })();
  });
}
function waitVisible(maxMs){
  if(!document.hidden)return Promise.resolve();
  var start=Date.now();
  return new Promise(function(resolve){
    (function check(){
      if(!document.hidden||Date.now()-start>=maxMs){resolve();return;}
      setTimeout(check,125);
    })();
  });
}
function stableBody(init){return String(init&&init.body||'');}
function requestKey(name,input,init){return name+'|'+urlOf(input)+'|'+stableBody(init);}
function singleFlight(key,task){
  var hit=pending.get(key);
  if(hit)return hit.then(function(r){return r.clone();});
  var p=Promise.resolve().then(task);
  pending.set(key,p);
  p.then(function(){setTimeout(function(){pending.delete(key);},0);},function(){pending.delete(key);});
  return p.then(function(r){return r.clone();});
}
function isPressureFailure(r){return !!(r&&(r.status===429||r.status>=500));}
function transportWithCooldown(key,input,init){
  var now=Date.now(),cool=failureCooldown.get(key);
  if(cool&&cool.until>now){return Promise.resolve(cool.response.clone());}
  if(cool)failureCooldown.delete(key);
  return baseFetch(input,init).then(function(r){
    if(isPressureFailure(r)){
      try{failureCooldown.set(key,{until:Date.now()+FAILURE_COOLDOWN_MS,response:r.clone()});}catch(_e){}
    }else{
      failureCooldown.delete(key);
    }
    return r;
  });
}

function pumpCalendar(){
  while(calendarActive<CALENDAR_MAX_CONCURRENCY&&calendarQueue.length){
    var job=calendarQueue.shift();
    calendarActive++;
    waitLeadBoundary(5000).then(function(){return sleep(120);}).then(job.task).then(job.resolve,job.reject).finally(function(){
      calendarActive--;
      pumpCalendar();
    });
  }
}
function queueCalendar(task){
  return new Promise(function(resolve,reject){calendarQueue.push({task:task,resolve:resolve,reject:reject});pumpCalendar();});
}

function pumpAnalytics(){
  while(analyticsActive<MAX_ANALYTICS_CONCURRENCY&&analyticsQueue.length){
    var job=analyticsQueue.shift();
    analyticsActive++;
    waitVisible(15000)
      .then(function(){return sleep(180+Math.floor(Math.random()*520));})
      .then(job.task)
      .then(job.resolve,job.reject)
      .finally(function(){analyticsActive--;pumpAnalytics();});
  }
}
function queueAnalytics(task){
  return new Promise(function(resolve,reject){analyticsQueue.push({task:task,resolve:resolve,reject:reject});pumpAnalytics();});
}

var SECONDARY_CC={
  aos_panel_asesor:1,
  aos_monitoreo_equipo:1,
  aos_historico_asesor_anual:1
};

/* Expensive read-only analytics observed in P0 #432. Keep these progressive.
 * The list intentionally excludes patient search/history, next-lead and every
 * aos_callcenter_* RPC because those are foreground/revenue-critical paths.
 */
var HEAVY_ANALYTICS={
  aos_ticker_mkt:1,
  aos_kpi_flujo_clinico:1,
  aos_actividad_minutos:1,
  aos_actividad_benchmark:1,
  aos_historico_asesor_anual:1,
  aos_sentinel_owner_feed_v1:1
};
var PRIMARY_READ={aos_panel_admin:1,aos_panel_asesor:1};

window.fetch=function(input,init){
  var url=urlOf(input),name=rpcName(url);
  if(!name)return baseFetch(input,init);

  // Revenue-critical / governed operations are always immediate and are never
  // failure-cooled. Lead selection is mutable; governed writes stay untouched.
  if(name==='aos_siguiente_lead'||name==='aos_siguiente_lead_v2'||/^aos_callcenter_/.test(name)){
    return baseFetch(input,init);
  }

  var key=requestKey(name,input,init);

  // Call Center calendar remains progressive and bounded behind the lead boundary.
  if(ccMounted()&&name==='aos_horarios_semana'){
    return singleFlight(key,function(){return queueCalendar(function(){return transportWithCooldown(key,input,init);});});
  }

  // While Call Center is mounted, secondary panel reads yield to the next-lead
  // boundary. Heavy ones then also enter the global analytics lane.
  if(ccMounted()&&SECONDARY_CC[name]){
    return singleFlight(key,function(){
      return waitLeadBoundary(2500).then(function(){
        if(HEAVY_ANALYTICS[name])return queueAnalytics(function(){return transportWithCooldown(key,input,init);});
        return transportWithCooldown(key,input,init);
      });
    });
  }

  // Cross-panel P0 #432 lane: one expensive analytical read per browser at a
  // time, staggered and visibility-aware. This prevents mount-time fan-out.
  if(HEAVY_ANALYTICS[name]){
    return singleFlight(key,function(){return queueAnalytics(function(){return transportWithCooldown(key,input,init);});});
  }

  // Primary dashboard reads stay immediate but are single-flighted. Their short
  // pressure cooldown suppresses the identical fixed +5s retry after 429/5xx.
  if(PRIMARY_READ[name]){
    return singleFlight(key,function(){return transportWithCooldown(key,input,init);});
  }

  return baseFetch(input,init);
};

window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.pending=pending;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.failureCooldown=failureCooldown;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.calendarQueue=calendarQueue;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.analyticsQueue=analyticsQueue;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.limits={calendar:CALENDAR_MAX_CONCURRENCY,analytics:MAX_ANALYTICS_CONCURRENCY,failureCooldownMs:FAILURE_COOLDOWN_MS};
console.log('[BUSINESS-PRIORITY] P0 #432 cross-panel pressure governor active');
})();
