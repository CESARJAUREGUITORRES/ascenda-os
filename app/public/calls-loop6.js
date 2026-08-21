/* ASCENDA OS · MKT-INTEGRITY-HOTFIX-V3 · LOOP 6
 * Loaded after calls.html legacy inline runtime.
 * Replaces only appointment persistence/decision semantics; no service-role material in browser.
 */
(function(){
'use strict';
if(window.__AOS_CC_LOOP6__) return;
window.__AOS_CC_LOOP6__='v1';

function cc6Token(){
  return (window.AOS_getToken&&window.AOS_getToken()) || sessionStorage.getItem('aos_app_token') || (window.CC&&CC.token) || '';
}
function cc6Rpc(fn,p){
  return new Promise(function(resolve,reject){
    if(typeof window._rpc!=='function'){reject(new Error('RPC_UNAVAILABLE'));return;}
    window._rpc(fn,p,function(d){resolve(d);},function(e){reject(e||new Error('RPC_FAILED'));});
  });
}
function cc6Uuid(){
  if(window.crypto&&typeof window.crypto.randomUUID==='function') return window.crypto.randomUUID();
  return 'cc6-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2)+'-'+Math.random().toString(36).slice(2);
}
function cc6Stable(obj){
  return JSON.stringify(obj,Object.keys(obj).sort());
}
function cc6PendingKey(action,payload){
  var fp=action+'|'+cc6Stable(payload);
  try{
    var old=JSON.parse(sessionStorage.getItem('aos_cc6_pending_action')||'null');
    if(old&&old.fp===fp&&old.key) return {key:old.key,fp:fp};
  }catch(_e){}
  var out={key:'cc6-'+cc6Uuid(),fp:fp};
  try{sessionStorage.setItem('aos_cc6_pending_action',JSON.stringify(out));}catch(_e2){}
  return out;
}
function cc6ClearPending(fp){
  try{
    var old=JSON.parse(sessionStorage.getItem('aos_cc6_pending_action')||'null');
    if(!fp||!old||old.fp===fp) sessionStorage.removeItem('aos_cc6_pending_action');
  }catch(_e){try{sessionStorage.removeItem('aos_cc6_pending_action');}catch(_e2){}}
}
function cc6Toast(t,s,cls){if(window.AOS_showToast)AOS_showToast(t,s||'',cls||'');}
function cc6SetBusy(v){
  if(!window.CC)return;
  CC.guardando=!!v;
  ['#cc-m-cita .mconf.gr','#cc-m-cita-manual .mconf.gr'].forEach(function(sel){var b=document.querySelector(sel);if(b)b.disabled=!!v;});
}
function cc6Esc(s){return typeof window.escH==='function'?window.escH(s):String(s||'').replace(/[&<>"']/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function cc6Prepare(num){
  return cc6Rpc('aos_callcenter_prepare_action_v1',{p_token:cc6Token(),p_numero:String(num||'').replace(/\D/g,'')});
}
function cc6EvidenceLabel(prep){
  var e=(prep&&prep.evidence)||{},out=[];
  if(e.priorSale) out.push('venta previa'+(e.lastSale&&e.lastSale.fecha?' '+e.lastSale.fecha:''));
  if(e.priorAttention) out.push('atención previa'+(e.lastAttention&&e.lastAttention.fecha?' '+e.lastAttention.fecha:''));
  if(e.priorAttendedAppointment) out.push('cita asistida/efectiva'+(e.lastAttendedAppointment&&e.lastAttendedAppointment.fecha?' '+e.lastAttendedAppointment.fecha:''));
  return out.length?out.join(' · '):'sin evidencia fuerte previa';
}

/* Capture Contact Debt lead identity after the legacy callback has populated CC.lead. */
if(typeof window._rpc==='function'&&!window._rpc.__cc6wrapped){
  var _rpc0=window._rpc;
  function wrappedRpc(fn,p,ok,fail){
    return _rpc0(fn,p,function(res){
      if(ok)ok(res);
      if(fn==='aos_siguiente_lead'&&res&&res.ok&&res.lead&&window.CC&&CC.lead&&String(CC.lead.num||'')===String(res.lead.num||'')){
        CC.lead.leadId=res.lead.id!=null?Number(res.lead.id):null;
        CC.lead.anuncio=res.lead.anuncio||((res.anuncio&&res.anuncio.nombre)||'');
        CC.lead.horaIngreso=res.lead.hora_ingreso||null;
        CC.lead.attributionSource=res.lead.attributionSource||'UNRESOLVED';
        CC.lead.contactDebtBucket=res.lead.contactDebtBucket||res.contactDebtBucket||null;
        CC.lead.waitMinutes=res.lead.waitMinutes||res.waitMinutes||0;
        setTimeout(function(){cc6ClassifyCurrentLead();},0);
      }
    },fail);
  }
  wrappedRpc.__cc6wrapped=true;
  window._rpc=wrappedRpc;
}

function cc6ClassifyCurrentLead(){
  if(!window.CC||!CC.lead||!CC.lead.num)return;
  var num=CC.lead.num;
  cc6Prepare(num).then(function(prep){
    if(!CC.lead||String(CC.lead.num)!==String(num))return;
    CC.loop6Patient=prep;
    CC.loop6Blocked=!!(prep&&prep.error==='IDENTITY_CONFLICT');
    var tier=document.getElementById('cc-tier');
    var ctx=document.getElementById('cc-contexto');
    if(CC.loop6Blocked){
      if(tier)tier.textContent='REVIEW · IDENTIDAD';
      if(ctx){ctx.style.display='block';ctx.innerHTML='<div class="ctx-bloque" style="border-left-color:#DC2626;background:#FEF2F2"><div class="ctx-tit" style="color:#DC2626">⚠️ Identidad ambigua</div><div class="ctx-row"><span class="ctx-val">No registrar una conversión automática. Revisar la identidad antes de continuar.</span></div></div>';}
      return;
    }
    if(prep&&prep.patientState==='CONVERTED_PATIENT'){
      if(tier)tier.textContent='PACIENTE EXISTENTE';
      if(ctx){
        var current=ctx.innerHTML||'';
        var note='<div class="ctx-bloque" id="cc6-patient-context" style="border-left-color:#D97706;background:#FFF7ED"><div class="ctx-tit" style="color:#D97706">♻️ Paciente convertido</div><div class="ctx-row"><span class="ctx-val">'+cc6Esc(cc6EvidenceLabel(prep))+' · Si la gestión es real usa Reactivación/Seguimiento; si sólo programa, usa Solo agendar.</span></div></div>';
        if(current.indexOf('cc6-patient-context')<0){ctx.style.display='block';ctx.innerHTML=current+note;}
      }
    }
  }).catch(function(e){console.warn('[CC6] patient state unavailable',e);});
}

function cc6EnsureSelectors(){
  var cita=document.querySelector('#cc-m-cita .mg');
  if(cita&&!document.getElementById('cc6-contact-mode')){
    var wrap=document.createElement('div');wrap.className='mf full';
    wrap.innerHTML='<div class="ml">Origen de esta conversación</div><select class="ms2" id="cc6-contact-mode"><option value="COMMERCIAL">📞 Llamada comercial</option><option value="CALLBACK">↩️ Cliente devolvió llamada / entrante</option></select>';
    cita.insertBefore(wrap,cita.firstChild);
  }
  var manual=document.querySelector('#cc-m-cita-manual .mg');
  if(manual&&!document.getElementById('cc6-manual-mode')){
    var mw=document.createElement('div');mw.className='mf full';
    mw.innerHTML='<div class="ml">Qué gestión realizó</div><select class="ms2" id="cc6-manual-mode"><option value="COMMERCIAL">📞 Llamada comercial</option><option value="CALLBACK">↩️ Callback / entrante</option><option value="AGENDA_ONLY">📅 Solo agendar</option></select>';
    manual.insertBefore(mw,manual.firstChild);
  }
}

function cc6PayloadFromCita(){
  var tipo='CONSULTA NUEVA';document.querySelectorAll('#cc-tipo-cita-grp .tb').forEach(function(t){if(t.classList.contains('act'))tipo=t.getAttribute('data-val')||tipo;});
  var num=window.CC&&CC.lead?String(CC.lead.num||'').replace(/\D/g,''):'';
  return {
    numero:num,
    lead_id:(CC.lead&&CC.lead.leadId)||null,
    tratamiento:(document.getElementById('cc-c-trat')||{}).value||((CC.lead&&CC.lead.trat)||''),
    anuncio:(CC.lead&&CC.lead.anuncio)||'',
    source_mode:(CC.lead&&CC.lead.manual)?'MANUAL':'QUEUE',
    nombre:(document.getElementById('cc-c-nombre')||{}).value||'',
    apellido:(document.getElementById('cc-c-apellido')||{}).value||'',
    dni:(document.getElementById('cc-c-dni')||{}).value||'',
    correo:(document.getElementById('cc-c-correo')||{}).value||'',
    tipo_atencion:(document.getElementById('cc-c-tipo-at')||{}).value||'',
    sede:(document.getElementById('cc-c-sede')||{}).value||'',
    fecha_cita:(document.getElementById('cc-c-fecha')||{}).value||'',
    hora_cita:(document.getElementById('cc-c-hora')||{}).value||'',
    tipo_cita:tipo,
    doctora:(document.getElementById('cc-c-doctora')||{}).value||'',
    obs:(document.getElementById('cc-c-obs')||{}).value||'',
    duracion_seg:(CC.leadStartTs?Math.max(0,Math.round((Date.now()-CC.leadStartTs)/1000)):0),
    desde_dispositivo:/Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent)?'movil':'web',
    followup_id:(CC.lead&&CC.lead.fromSeg&&CC.lead.segId)?CC.lead.segId:null
  };
}
function cc6PayloadFromManual(){
  var tipo='CONSULTA NUEVA';var grp=document.getElementById('cm-tipo-cita-grp');if(grp)grp.querySelectorAll('.tb').forEach(function(t){if(t.classList.contains('act'))tipo=t.getAttribute('data-val')||tipo;});
  return {
    numero:String((document.getElementById('cm-num')||{}).value||'').replace(/\D/g,''),
    lead_id:null,
    tratamiento:(document.getElementById('cm-trat')||{}).value||'',
    anuncio:'',source_mode:'MANUAL',
    nombre:(document.getElementById('cm-nombre')||{}).value||'',
    apellido:(document.getElementById('cm-apellido')||{}).value||'',
    dni:(document.getElementById('cm-dni')||{}).value||'',
    correo:(document.getElementById('cm-correo')||{}).value||'',
    tipo_atencion:(document.getElementById('cm-tipo-at')||{}).value||'',
    sede:(document.getElementById('cm-sede')||{}).value||'',
    fecha_cita:(document.getElementById('cm-fecha')||{}).value||'',
    hora_cita:(document.getElementById('cm-hora')||{}).value||'',
    tipo_cita:tipo,
    doctora:(document.getElementById('cm-doctora')||{}).value||'',
    obs:(document.getElementById('cm-obs')||{}).value||'',
    duracion_seg:0,
    desde_dispositivo:/Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent)?'movil':'web'
  };
}
function cc6ValidatePayload(p){
  if(!p.numero||p.numero.length<7)return 'Número inválido';
  if(!p.fecha_cita)return 'Falta fecha de cita';
  if(!p.hora_cita)return 'Falta hora de cita';
  return '';
}

function cc6ExistingPatientModal(prep,payload,done){
  var old=document.getElementById('cc6-existing-patient-modal');if(old)old.remove();
  var e=(prep&&prep.evidence)||{};
  var m=document.createElement('div');m.id='cc6-existing-patient-modal';m.className='mov open';m.style.zIndex='1200';
  var name=((payload.nombre||'')+' '+(payload.apellido||'')).trim()||payload.numero;
  m.innerHTML='<div class="modal" style="max-width:500px"><div class="mhd"><span style="font-size:22px">⚠️</span><div><div class="mtit">PACIENTE EXISTENTE DETECTADO</div><div style="font-size:10px;color:#9AAAC8">'+cc6Esc(name)+' · '+cc6Esc(payload.numero)+'</div></div></div>'+
  '<div style="padding:9px;background:#FFF7ED;border:1px solid #FED7AA;border-radius:9px;font-size:10px;color:#92400E;line-height:1.5;margin-bottom:10px"><b>Evidencia:</b> '+cc6Esc(cc6EvidenceLabel(prep))+'<br>Esta persona ya tiene evidencia de conversión previa. Elige qué gestión hiciste ahora.</div>'+
  '<div style="display:grid;gap:7px">'+
  '<button data-action="REACTIVATION" style="padding:11px;border-radius:9px;border:1px solid #BBF7D0;background:#F0FDF4;text-align:left;cursor:pointer"><b>♻️ Reactivación comercial</b><br><span style="font-size:9px;color:#6B7BA8">Llamada real para recuperar al paciente. Conserva gestión y Agenda, sin nueva adquisición.</span></button>'+
  '<button data-action="PATIENT_FOLLOWUP" style="padding:11px;border-radius:9px;border:1px solid #BFDBFE;background:#EBF2FF;text-align:left;cursor:pointer"><b>📞 Seguimiento de paciente</b><br><span style="font-size:9px;color:#6B7BA8">Gestión real de seguimiento. No crea nueva conversión Marketing.</span></button>'+
  '<button data-action="AGENDA_ONLY" style="padding:11px;border-radius:9px;border:1px solid #E2E8F0;background:#F8FAFC;text-align:left;cursor:pointer"><b>📅 Solo agendar cita</b><br><span style="font-size:9px;color:#6B7BA8">Agenda únicamente. No suma llamada ni cita comercial.</span></button></div>'+
  '<div style="font-size:9px;color:#9AAAC8;margin-top:9px">Si sólo necesitas programar una sesión, control o cita habitual, selecciona <b>Solo agendar cita</b>.</div><div class="mfoot"><button class="mcanc" id="cc6-existing-cancel">Cancelar</button></div></div>';
  document.body.appendChild(m);
  m.querySelectorAll('[data-action]').forEach(function(b){b.onclick=function(){var a=this.getAttribute('data-action');m.remove();done(a);};});
  document.getElementById('cc6-existing-cancel').onclick=function(){m.remove();cc6SetBusy(false);};
}
function cc6ManualChoice(payload,done){
  var mode=((document.getElementById('cc6-manual-mode')||{}).value||'COMMERCIAL');
  if(mode==='AGENDA_ONLY'){done('AGENDA_ONLY');return;}
  done(mode==='CALLBACK'?'CALLBACK_INBOUND_APPOINTMENT':'COMMERCIAL_CALL_APPOINTMENT');
}

function cc6Commit(action,payload,sourceModal){
  if(action==='CALLBACK_INBOUND_APPOINTMENT')payload.source_mode='CALLBACK';
  if(action==='AGENDA_ONLY'&&payload.source_mode==='QUEUE')payload.source_mode='MANUAL';
  var pending=cc6PendingKey(action,payload);
  return cc6Rpc('aos_callcenter_commit_action_v1',{p_token:cc6Token(),p_idempotency_key:pending.key,p_action_type:action,p_payload:payload}).then(function(res){
    if(!res||res.ok!==true){var er=new Error((res&&res.error)||'CALLCENTER_ACTION_FAILED');er.payload=res;throw er;}
    cc6ClearPending(pending.fp);
    if(sourceModal&&typeof window.closeCCModal==='function')closeCCModal(sourceModal);
    var isCommercial=action==='COMMERCIAL_CALL_APPOINTMENT'||action==='CALLBACK_INBOUND_APPOINTMENT';
    var label=action==='AGENDA_ONLY'?'Cita agendada · no suma llamada':action==='REACTIVATION'?'Reactivación + cita guardadas':action==='PATIENT_FOLLOWUP'?'Seguimiento + cita guardados':action==='CALLBACK_INBOUND_APPOINTMENT'?'Callback + cita guardados':'Cita confirmada';
    if(window.AOS_playSound)AOS_playSound(isCommercial?'venta':'notif');
    cc6Toast(label,res.origin||'Guardado','toast-venta');
    if(payload.correo&&typeof window.enviarEmailConfirmacionCita==='function')enviarEmailConfirmacionCita({correo:payload.correo,nombre:payload.nombre,apellido:payload.apellido,fecha_cita:payload.fecha_cita,hora_cita:payload.hora_cita,tratamiento:payload.tratamiento,sede:payload.sede,dni:payload.dni,numero_limpio:payload.numero});
    if(typeof window.loadHistorial==='function')loadHistorial();
    if(typeof window.loadMetrics==='function')loadMetrics();
    if(typeof window.recargarCalendario==='function')recargarCalendario();
    if(window.AOS_pollNow)AOS_pollNow();
    if(typeof window.loadLead==='function'&&action!=='AGENDA_ONLY')loadLead();
    return res;
  }).catch(function(err){
    console.error('[CC6] commit',action,err,err&&err.payload);
    var msg=(err&&err.payload&&err.payload.error)||(err&&err.message)||'Error al guardar';
    if(msg==='PATIENT_ACTION_REQUIRED')msg='Paciente existente: selecciona Reactivación, Seguimiento o Solo agendar.';
    if(msg==='IDENTITY_CONFLICT')msg='Identidad ambigua: requiere revisión antes de guardar.';
    cc6Toast('No se guardó',msg,'toast-alerta');
    throw err;
  });
}

window.ccConfirmarCita=function(){
  if(window.CC&&CC.guardando)return;
  cc6EnsureSelectors();
  var p=cc6PayloadFromCita(),bad=cc6ValidatePayload(p);if(bad){cc6Toast('⚠️ '+bad,'','toast-alerta');return;}
  cc6SetBusy(true);
  cc6Prepare(p.numero).then(function(prep){
    if(!prep||prep.ok!==true){throw Object.assign(new Error((prep&&prep.error)||'PATIENT_STATE_FAILED'),{payload:prep});}
    CC.loop6Patient=prep;
    if(prep.patientState==='CONVERTED_PATIENT'){
      cc6ExistingPatientModal(prep,p,function(action){cc6Commit(action,p,'cc-m-cita').finally(function(){cc6SetBusy(false);});});
      return;
    }
    var mode=((document.getElementById('cc6-contact-mode')||{}).value||'COMMERCIAL');
    var action=mode==='CALLBACK'?'CALLBACK_INBOUND_APPOINTMENT':'COMMERCIAL_CALL_APPOINTMENT';
    cc6Commit(action,p,'cc-m-cita').finally(function(){cc6SetBusy(false);});
  }).catch(function(e){cc6SetBusy(false);var msg=(e&&e.payload&&e.payload.error)||(e&&e.message)||'No se pudo clasificar';cc6Toast('No se guardó',msg,'toast-alerta');});
};

window.guardarCitaManual=function(){
  if(window.CC&&CC.guardando)return;
  cc6EnsureSelectors();
  var p=cc6PayloadFromManual(),bad=cc6ValidatePayload(p);if(bad){cc6Toast('⚠️ '+bad,'','toast-alerta');return;}
  cc6SetBusy(true);
  cc6Prepare(p.numero).then(function(prep){
    if(!prep||prep.ok!==true){throw Object.assign(new Error((prep&&prep.error)||'PATIENT_STATE_FAILED'),{payload:prep});}
    if(prep.patientState==='CONVERTED_PATIENT'){
      cc6ExistingPatientModal(prep,p,function(action){cc6Commit(action,p,'cc-m-cita-manual').finally(function(){cc6SetBusy(false);});});
      return;
    }
    cc6ManualChoice(p,function(action){cc6Commit(action,p,'cc-m-cita-manual').finally(function(){cc6SetBusy(false);});});
  }).catch(function(e){cc6SetBusy(false);var msg=(e&&e.payload&&e.payload.error)||(e&&e.message)||'No se pudo clasificar';cc6Toast('No se guardó',msg,'toast-alerta');});
};

cc6EnsureSelectors();
/* The legacy inline ccInit already requested a lead before this override loaded. Refresh once
 * so the Contact Debt response is captured with lead_id/anuncio/attribution metadata. */
setTimeout(function(){if(typeof window.loadLead==='function')loadLead();},80);
console.log('[ASCENDA][CC6] explicit semantics + atomic persistence override ready');
})();
