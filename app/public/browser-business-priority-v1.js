/* ASCENDA OS · Business Priority Mode P0-B/P0-C + P0 #630
 * Browser read scheduler. It never intercepts or delays governed writes.
 * P0 #630 adds server-advertised incident load shedding: while
 * AOS_FOREGROUND_PRIORITY_MODE is active, known analytical/dashboard RPCs are
 * answered locally and WA presence is rate-limited so Auth, Call Center,
 * Agenda, patient operations and business writes get the database capacity.
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
var incidentMode=true; // fail safe until the same-origin status endpoint answers.
var incidentStatusReady=false;
var lastPresenceAttemptAt=0;
var PRESENCE_RECOVERY_INTERVAL_MS=90000;

window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__={
  version:'p0-630-v1.0',
  policy:'critical-immediate__incident-secondary-shed__analytics-bounded__failure-cooldown',
  incidentMode:true
};

function urlOf(input){return typeof input==='string'?input:(input&&input.url)||'';}
function rpcName(url){var m=String(url||'').match(/\/rest\/v1\/rpc\/([^?]+)/);return m&&m[1]||'';}
function pathnameOf(input){try{return new URL(urlOf(input),location.href).pathname;}catch(_e){return '';}}
function methodOf(input,init){return String((init&&init.method)||(input&&input.method)||'GET').toUpperCase();}
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

function recoveryResponse(status,body){
  var payload=JSON.stringify(body||{}),headers={'Content-Type':'application/json','Cache-Control':'no-store','X-Ascenda-Business-Priority':'P0_DB_RECOVERY'};
  if(typeof Response!=='undefined')return new Response(payload,{status:status,headers:headers});
  return {
    status:status,ok:status>=200&&status<300,headers:{get:function(k){return headers[k]||headers[String(k||'').toLowerCase()]||null;}},
    clone:function(){return recoveryResponse(status,body);},
    json:function(){return Promise.resolve(body||{});},
    text:function(){return Promise.resolve(payload);}
  };
}

var RECOVERY_SHED_READS={
  aos_panel_admin:1,
  aos_panel_asesor:1,
  aos_monitoreo_equipo:1,
  aos_historico_asesor_anual:1,
  aos_ticker_mkt:1,
  aos_kpi_flujo_clinico:1,
  aos_actividad_minutos:1,
  aos_actividad_benchmark:1,
  aos_actividad_reciente:1,
  aos_comisiones_asesor:1,
  aos_sentinel_owner_feed_v1:1
};
function isRecoveryShedRead(name){return !!(RECOVERY_SHED_READS[name]||/^aos_marketing_/.test(name));}
function recoveryShedRpc(name){
  return recoveryResponse(503,{ok:false,error:'BUSINESS_PRIORITY_RECOVERY_SHED',retryable:true,scope:name||'analytics'});
}

var incidentStatusPromise=baseFetch('/api/business-priority/status',{method:'GET',cache:'no-store',credentials:'same-origin'})
  .then(function(r){return r&&r.ok?r.json():null;})
  .then(function(d){incidentMode=!!(d&&d.foregroundPriorityMode===true);incidentStatusReady=true;window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.incidentMode=incidentMode;return incidentMode;})
  .catch(function(){incidentMode=true;incidentStatusReady=true;window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.incidentMode=true;return true;});
function withIncidentStatus(task){return incidentStatusReady?Promise.resolve(task(incidentMode)):incidentStatusPromise.then(task);}

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

/* Expensive read-only analytics observed in production. Keep these progressive
 * outside incidents; during P0 recovery the subset above is shed completely.
 * Patient search/history, next-lead and every aos_callcenter_* RPC are excluded.
 */
var HEAVY_ANALYTICS={
  aos_ticker_mkt:1,
  aos_kpi_flujo_clinico:1,
  aos_actividad_minutos:1,
  aos_actividad_benchmark:1,
  aos_actividad_reciente:1,
  aos_historico_asesor_anual:1,
  aos_comisiones_asesor:1,
  aos_sentinel_owner_feed_v1:1
};
var PRIMARY_READ={aos_panel_admin:1,aos_panel_asesor:1};

window.fetch=function(input,init){
  var url=urlOf(input),name=rpcName(url),path=pathnameOf(input),method=methodOf(input,init);

  // WA presence is useful but not revenue-critical. During a DB incident keep
  // at most one real heartbeat per browser every 90s; the other 30s ticks are
  // acknowledged locally and cannot consume PostgREST connections.
  if(method==='POST'&&path==='/api/wa3/presence'){
    return withIncidentStatus(function(active){
      if(!active)return baseFetch(input,init);
      var now=Date.now();
      if(now-lastPresenceAttemptAt<PRESENCE_RECOVERY_INTERVAL_MS)return recoveryResponse(200,{ok:true,recovery_suppressed:true});
      lastPresenceAttemptAt=now;
      return baseFetch(input,init);
    });
  }

  if(!name)return baseFetch(input,init);

  // Revenue-critical / governed operations are always immediate and never
  // failure-cooled or incident-shed. Lead selection is mutable.
  if(name==='aos_siguiente_lead'||name==='aos_siguiente_lead_v2'||name==='aos_siguiente_lead_v3'||/^aos_callcenter_/.test(name)){
    return baseFetch(input,init);
  }

  if(isRecoveryShedRead(name)){
    return withIncidentStatus(function(active){if(active)return recoveryShedRpc(name);return dispatchRead(name,input,init);});
  }
  return dispatchRead(name,input,init);
};

function dispatchRead(name,input,init){
  var key=requestKey(name,input,init);

  if(ccMounted()&&name==='aos_horarios_semana'){
    return singleFlight(key,function(){return queueCalendar(function(){return transportWithCooldown(key,input,init);});});
  }

  if(ccMounted()&&SECONDARY_CC[name]){
    return singleFlight(key,function(){
      return waitLeadBoundary(2500).then(function(){
        if(HEAVY_ANALYTICS[name])return queueAnalytics(function(){return transportWithCooldown(key,input,init);});
        return transportWithCooldown(key,input,init);
      });
    });
  }

  if(HEAVY_ANALYTICS[name]||/^aos_marketing_/.test(name)){
    return singleFlight(key,function(){return queueAnalytics(function(){return transportWithCooldown(key,input,init);});});
  }

  if(PRIMARY_READ[name]){
    return singleFlight(key,function(){return transportWithCooldown(key,input,init);});
  }

  return baseFetch(input,init);
}

window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.pending=pending;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.failureCooldown=failureCooldown;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.calendarQueue=calendarQueue;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.analyticsQueue=analyticsQueue;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.incidentStatusPromise=incidentStatusPromise;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.limits={calendar:CALENDAR_MAX_CONCURRENCY,analytics:MAX_ANALYTICS_CONCURRENCY,failureCooldownMs:FAILURE_COOLDOWN_MS,presenceRecoveryIntervalMs:PRESENCE_RECOVERY_INTERVAL_MS};
console.log('[BUSINESS-PRIORITY] P0 #630 DB recovery load-shed governor active');
})();
