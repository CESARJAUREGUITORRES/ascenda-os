/* ASCENDA CLINIC — advisor blocking state persistence V1
   Keeps BREAK/BAÑO/ATENCIÓN/LIMPIEZA/CAPACITACIÓN active across background, reload and PWA resume. */
(function(){
'use strict';
if(window.__AOS_BREAK_PERSIST_V1__)return;
window.__AOS_BREAK_PERSIST_V1__=true;
var KEY='aos_blocking_state_v1',MAX_AGE=12*60*60*1000;
var COLORS={BREAK:'#D97706','BAÑO':'#D97706','BANO':'#D97706','ATENCIÓN':'#EA580C','ATENCION':'#EA580C','LIMPIEZA':'#EA580C','CAPACITACIÓN':'#7C3AED','CAPACITACION':'#7C3AED'};
var ICONS={BREAK:'☕','BAÑO':'🚻','BANO':'🚻','ATENCIÓN':'🙋','ATENCION':'🙋','LIMPIEZA':'🧹','CAPACITACIÓN':'📚','CAPACITACION':'📚'};

function sessionUser(){
  try{var s=JSON.parse(localStorage.getItem('aos_session')||'null');return s&&String(s.codigo_asesor||'').trim()||''}catch(_){return ''}
}
function read(){
  try{
    var s=JSON.parse(localStorage.getItem(KEY)||'null');
    if(!s||!s.userId||!s.estado||!s.startedAt)return null;
    var age=Date.now()-Number(s.startedAt||0);
    if(age<0||age>MAX_AGE){localStorage.removeItem(KEY);return null}
    var user=sessionUser();
    if(!user||String(s.userId)!==user)return null;
    return s;
  }catch(_){return null}
}
function write(estado,ico,startedAt){
  var user=sessionUser()||(window.AOS&&AOS.ctx&&AOS.ctx.idAsesor)||'';
  if(!user)return;
  var e=String(estado||'').toUpperCase();
  var s={userId:user,estado:e,ico:ico||ICONS[e]||'⏸️',color:COLORS[e]||'#D97706',startedAt:Number(startedAt)||Date.now(),savedAt:Date.now()};
  try{localStorage.setItem(KEY,JSON.stringify(s))}catch(_){}
  return s;
}
function clear(){try{localStorage.removeItem(KEY)}catch(_){}}
function fmt(sec){sec=Math.max(0,Number(sec)||0);return String(Math.floor(sec/60)).padStart(2,'0')+':'+String(sec%60).padStart(2,'0')}
function refreshTimer(s){
  var el=document.getElementById('eo-timer');if(!el||!s)return;
  el.textContent=fmt(Math.floor((Date.now()-Number(s.startedAt))/1000));
}
function restore(){
  var s=read();if(!s||!window.AOS||!AOS.ctx||String(AOS.ctx.idAsesor||'')!==String(s.userId))return false;
  var overlay=document.getElementById('estado-overlay');if(!overlay)return false;
  if(typeof window.setEstadoUI==='function')window.setEstadoUI(s.estado,s.color);
  if(typeof window.__AOS_BREAK_ORIGINAL_ACTIVATE__==='function'&&!overlay.classList.contains('open')){
    window.__AOS_BREAK_RESTORING__=true;
    try{window.__AOS_BREAK_ORIGINAL_ACTIVATE__(s.estado,s.ico)}finally{window.__AOS_BREAK_RESTORING__=false}
  }
  AOS.estadoBloqueo=s.estado;
  AOS.bloqueoInicio=Number(s.startedAt);
  refreshTimer(s);
  return true;
}
function hook(){
  if(typeof window._rpc!=='function'||typeof window.activarOverlayEstado!=='function'||typeof window.terminarEstadoBloqueante!=='function'){
    setTimeout(hook,20);return;
  }
  if(window.__AOS_BREAK_HOOKED__)return;
  window.__AOS_BREAK_HOOKED__=true;

  var rpc=window._rpc;
  window._rpc=function(name,p,cb){
    var state=read();
    if(name==='aos_set_estado_asesor'&&p&&p.p_estado==='LOGEADO'&&state){
      var guarded=Object.assign({},p,{p_estado:state.estado});
      return rpc.call(this,name,guarded,cb);
    }
    return rpc.apply(this,arguments);
  };

  var activate=window.activarOverlayEstado;
  window.__AOS_BREAK_ORIGINAL_ACTIVATE__=activate;
  window.activarOverlayEstado=function(edo,ico){
    var state;
    if(window.__AOS_BREAK_RESTORING__)state=read();
    else state=write(edo,ico,Date.now());
    var out=activate.apply(this,arguments);
    if(state&&window.AOS){AOS.estadoBloqueo=state.estado;AOS.bloqueoInicio=Number(state.startedAt);refreshTimer(state)}
    return out;
  };

  var finish=window.terminarEstadoBloqueante;
  window.terminarEstadoBloqueante=function(){
    var out=finish.apply(this,arguments);
    clear();
    return out;
  };

  setTimeout(restore,35);
  window.addEventListener('pageshow',function(){setTimeout(restore,0)});
  document.addEventListener('visibilitychange',function(){if(document.visibilityState==='visible')setTimeout(restore,0)});
}
hook();
})();