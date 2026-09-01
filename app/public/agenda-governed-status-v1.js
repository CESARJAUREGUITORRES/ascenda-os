/* ASCENDA OS · Agenda Governed Status V1
 * Replaces the legacy browser PATCH + DELETE + POST chain with one atomic,
 * permissioned database action. Other Agenda operations remain untouched.
 */
(function(){
'use strict';

function cacheToken(){
  if(!('caches' in window))return Promise.resolve('');
  return caches.open('aos-phase2-auth').then(function(c){return c.match('/__aos_app_token');}).then(function(r){return r?r.text():'';}).catch(function(){return '';});
}
function strongToken(){
  var t='';try{t=String(sessionStorage.getItem('aos_app_token')||'').trim();}catch(_){}
  if(t.length>=32)return Promise.resolve(t);
  return cacheToken().then(function(x){
    x=String(x||'').trim();
    if(x.length>=32)try{sessionStorage.setItem('aos_app_token',x);}catch(_){}
    return x;
  });
}
function toast(a,b,c){try{if(window.AOS_showToast)window.AOS_showToast(a,b||'',c||'');}catch(_){} }
function apiError(code){
  var map={
    AGENDA_2FA_PANEL_REQUIRED:'Sesión 2FA o permiso de Agenda requerido.',
    APPOINTMENT_NOT_FOUND:'La cita ya no existe o cambió. Recarga Agenda.',
    DOCTOR_AUTHORITY_REQUIRED:'La cita no tiene una doctora válida asignada.',
    ATTENDING_NURSE_REQUIRED:'Selecciona quién realizará la atención.',
    INVALID_APPOINTMENT_STATUS:'Estado de cita no válido.'
  };
  return map[code]||code||'No se pudo actualizar la cita.';
}
function selectedStatus(){
  var v='';
  var host=document.getElementById('det-estados');
  if(host)host.querySelectorAll('.est-btn.act').forEach(function(b){v=b.getAttribute('data-val')||'';});
  return v;
}
function sendNoShowEmail(c){
  var num=String(c&& (c.numero_limpio||c.numero)||'').replace(/\D/g,'');
  if(!num||!window._SB||!window._SK)return;
  fetch(window._SB+'/rest/v1/aos_pacientes?select=Email,nombres&numero_limpio=eq.'+num,{headers:{apikey:window._SK,Authorization:'Bearer '+window._SK}})
    .then(function(r){return r.ok?r.json():[];}).then(function(rows){
      var p=rows&&rows[0];if(!p||!p.Email)return;
      return fetch('https://ascenda-os-production.up.railway.app/api/send-template',{
        method:'POST',headers:{'Content-Type':'application/json','X-ASCENDA-Session':(sessionStorage.getItem('aos_app_token')||'')},
        body:JSON.stringify({to:p.Email,template:'no_asistencia',nombre:p.nombres||c.nombre||'',tratamiento:c.tratamiento||'',sede:c.sede||'',fecha:c.fecha_cita||''})
      });
    }).catch(function(){});
}
function install(){
  if(typeof window.agGuardarEstado!=='function'||!window.AG||!window._SB||!window._SK)return false;
  if(window.agGuardarEstado.__agendaGovernedV1)return true;

  function governedSave(){
    if(!window.AG||!AG.sel)return;
    if(AG._guardando)return;
    var est=selectedStatus();
    var nota=((document.getElementById('det-nota')||{}).value||'').trim();
    var asistente=(document.getElementById('det-asistente')||{}).value||'';
    if(!est){toast('Selecciona un estado','','toast-alerta');return;}
    AG._guardando=true;

    strongToken().then(function(token){
      if(String(token||'').length<32)throw new Error('AGENDA_2FA_PANEL_REQUIRED');
      var ctrl=typeof AbortController!=='undefined'?new AbortController():null;
      var timer=ctrl?setTimeout(function(){ctrl.abort();},20000):null;
      return fetch(window._SB+'/rest/v1/rpc/aos_agenda_set_status_v1',{
        method:'POST',cache:'no-store',signal:ctrl?ctrl.signal:undefined,
        headers:{apikey:window._SK,Authorization:'Bearer '+window._SK,'Content-Type':'application/json'},
        body:JSON.stringify({p_token:token,p_cita_id:String(AG.sel.id),p_estado:est,p_asistente:asistente,p_nota:nota})
      }).then(function(r){
        if(timer)clearTimeout(timer);
        return r.json().catch(function(){return null;}).then(function(d){
          if(!r.ok||!d||d.ok!==true){var code=d&&d.error?d.error:('HTTP_'+r.status);throw new Error(code);}
          return d;
        });
      });
    }).then(function(d){
      AG._guardando=false;
      toast('Estado actualizado',est,'');
      if((est==='ASISTIO'||est==='EFECTIVA')&&d.attentionId){toast('✅ Atención sincronizada','Registro clínico creado/actualizado','');}
      if(est==='NO ASISTIO')sendNoShowEmail(AG.sel);
      if(typeof window.agCloseDet==='function')window.agCloseDet();
      if(typeof window.agLoad==='function')window.agLoad();
    }).catch(function(e){
      AG._guardando=false;
      var code=e&&e.name==='AbortError'?'AGENDA_TIMEOUT':String(e&&e.message||'AGENDA_ERROR');
      toast('No se guardó la cita',code==='AGENDA_TIMEOUT'?'La operación tardó demasiado. Reintenta; no se duplicará.':apiError(code),'toast-alerta');
      console.error('[AGENDA-GOVERNED]',code);
    });
  }
  governedSave.__agendaGovernedV1=true;
  governedSave.__legacy=window.agGuardarEstado;
  window.agGuardarEstado=governedSave;
  window.__AOS_AGENDA_GOVERNED_STATUS_V1__='v1';
  console.log('[ASCENDA][AGENDA] governed status runtime active');
  return true;
}

window.__AOS_INSTALL_AGENDA_GOVERNED_STATUS_V1__=install;
var attempts=0;
(function wait(){attempts++;if(install())return;if(attempts<200&&document.getElementById('ag-content'))setTimeout(wait,50);})();
})();
