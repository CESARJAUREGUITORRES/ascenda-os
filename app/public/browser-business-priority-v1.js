/* ASCENDA OS · Business Priority Mode P0-B/P0-C
 * Browser-only read scheduler. It never intercepts governed writes.
 */
(function(){
'use strict';
if(window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__)return;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__={version:'p0-bc-v1'};

var baseFetch=window.fetch.bind(window);
var pending=new Map();
var calendarQueue=[];
var calendarActive=0;
var CALENDAR_MAX_CONCURRENCY=2;

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

var SECONDARY={
  aos_panel_asesor:1,
  aos_monitoreo_equipo:1,
  aos_historico_asesor_anual:1
};

window.fetch=function(input,init){
  var url=urlOf(input),name=rpcName(url);
  if(!name||!ccMounted())return baseFetch(input,init);

  // Revenue-critical operations are always immediate. No writes are delayed.
  if(name==='aos_siguiente_lead'||name==='aos_siguiente_lead_v2'||/^aos_callcenter_/.test(name)){
    return baseFetch(input,init);
  }

  // Calendar is progressive: max two week reads at once, only after the lead
  // boundary has resolved. This removes the 5-6 request startup fan-out.
  if(name==='aos_horarios_semana'){
    var ck=requestKey(name,input,init);
    return singleFlight(ck,function(){return queueCalendar(function(){return baseFetch(input,init);});});
  }

  // Secondary KPI/history reads yield to the next-lead critical path.
  if(SECONDARY[name]){
    var sk=requestKey(name,input,init);
    return singleFlight(sk,function(){return waitLeadBoundary(2500).then(function(){return baseFetch(input,init);});});
  }

  return baseFetch(input,init);
};

window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.pending=pending;
window.__AOS_BUSINESS_PRIORITY_BROWSER_V1__.calendarQueue=calendarQueue;
console.log('[BUSINESS-PRIORITY] Call Center critical-path scheduler active');
})();
