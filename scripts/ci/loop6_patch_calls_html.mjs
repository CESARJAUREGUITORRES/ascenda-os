import fs from 'node:fs';

const htmlPath='app/public/calls.html';
const jsPath='app/public/calls-loop6.js';
const callsJsPath='app/public/calls.js';
const marker='<script src="/calls-loop6.js?v=20260821-loop6-v2.3"></script>';
const oldMarkers=[
  '<script src="/calls-loop6.js?v=20260821-loop6-v2.2"></script>',
  '<script src="/calls-loop6.js?v=20260821-loop6"></script>',
  '<script src="/calls-loop6-policy-v2.js?v=20260821-loop6-policy-v2"></script>'
];
const anchor='<!-- KronIA Chat — en app.html (persistente entre paneles) -->';
const guard="if(window.__AOS_CC_LOOP6_V2__!=='v2.3'){alert('ASCENDA Call Center se actualizó. Recarga esta pantalla antes de registrar una cita.');return;}";

function patchLegacy(path){
  let text=fs.readFileSync(path,'utf8');
  let changed=false;
  text=text.replaceAll("if(window.__AOS_CC_LOOP6_V2__!=='v2.2'){alert('ASCENDA Call Center se actualizó. Recarga esta pantalla antes de registrar una cita.');return;}",guard);
  for(const sig of ['function ccConfirmarCita(){','function guardarCitaManual(){']){
    const guarded=`${sig}\n  ${guard}`;
    const guardedCr=`${sig}\r\n  ${guard}`;
    if(text.includes(guarded)||text.includes(guardedCr)) continue;
    if(!text.includes(sig)) throw new Error(`Loop6 legacy function not found in ${path}: ${sig}`);
    text=text.replace(sig,`${sig}\n  ${guard}`);
    changed=true;
  }
  if(changed||!text.includes("__AOS_CC_LOOP6_V2__!=='v2.2'")) fs.writeFileSync(path,text,'utf8');
}

let html=fs.readFileSync(htmlPath,'utf8');
let htmlChanged=false;
for(const old of oldMarkers){
  if(html.includes(old)){
    html=html.split(old+'\n').join('').split(old+'\r\n').join('').split(old).join('');
    htmlChanged=true;
  }
}
const count=html.split(marker).length-1;
if(count>1) throw new Error(`LOOP6 v2.3 loader duplicated: ${count}`);
if(count===0){
  if(!html.includes(anchor)) throw new Error('LOOP6 loader anchor not found');
  html=html.replace(anchor,`${marker}\n${anchor}`);
  htmlChanged=true;
}
if(htmlChanged) fs.writeFileSync(htmlPath,html,'utf8');

patchLegacy(htmlPath);
patchLegacy(callsJsPath);

let runtime=fs.readFileSync(jsPath,'utf8');
runtime=runtime.replace("window.__AOS_CC_LOOP6_V2__='v2.2';","window.__AOS_CC_LOOP6_V2__='v2.3';");
if(!runtime.includes("window.__AOS_CC_LOOP6_V2__='v2.3';")) throw new Error('Loop6 v2.3 runtime marker not found');

const ensureStart=runtime.indexOf('function cc6EnsureSelectors(){');
const ensureEnd=runtime.indexOf('function cc6PayloadFromCita()',ensureStart);
if(ensureStart<0||ensureEnd<0) throw new Error('cc6EnsureSelectors boundaries not found');
const ensureFn=`function cc6EnsureSelectors(){
  var obsolete=document.getElementById('cc6-contact-mode');
  if(obsolete){var ow=obsolete.closest('.mf');if(ow)ow.remove();else obsolete.remove();}
  var manual=document.querySelector('#cc-m-cita-manual .mg');
  if(manual&&!document.getElementById('cc6-manual-mode')){
    var mw=document.createElement('div');mw.className='mf full';
    mw.innerHTML='<div class="ml">Qué gestión realizó</div><select class="ms2" id="cc6-manual-mode"><option value="COMMERCIAL">📞 Llamada comercial</option><option value="CALLBACK">↩️ Seguimiento / callback / entrante</option><option value="AGENDA_ONLY">📅 Solo agendar</option></select>';
    manual.insertBefore(mw,manual.firstChild);
  }
}
`;
runtime=runtime.slice(0,ensureStart)+ensureFn+runtime.slice(ensureEnd);

const queueStart=runtime.indexOf('window.ccConfirmarCita=function(){');
const queueEnd=runtime.indexOf('\nwindow.guardarCitaManual=function(){',queueStart);
if(queueStart<0||queueEnd<0) throw new Error('ccConfirmarCita override boundaries not found');
const queuePatch=`/* LOOP6_V23_AUTO_QUEUE */
function cc6QueueFinishModal(res,payload){
  cc6RemoveModal('cc6-queue-success-modal');
  var commercial=res&&res.callState==='CITA CONFIRMADA'&&res.eligibilityStatus==='ALLOW';
  var title=commercial?'✅ CITA AGENDADA CON ÉXITO':'Gestión registrada';
  var bg=commercial?'#F0FDF4':'#FFF7ED',bd=commercial?'#BBF7D0':'#FED7AA',fg=commercial?'#166534':'#92400E';
  var name=((payload.nombre||'')+' '+(payload.apellido||'')).trim()||payload.numero;
  var detail='<div style="padding:12px;background:'+bg+';border:1px solid '+bd+';border-radius:10px;color:'+fg+';line-height:1.6"><b>'+cc6Esc(name)+'</b><br>'+cc6Esc(payload.fecha_cita||'')+' · '+cc6Esc(payload.hora_cita||'')+'<br>'+cc6Esc(payload.tratamiento||'')+'<br>'+cc6Esc(payload.sede||'')+'<br>Asesor: '+cc6Esc((res&&res.executedBy)||'—')+(commercial?'':'<br><b>Regla:</b> '+cc6Esc((res&&res.eligibilityReason)||'Sin nuevo crédito comercial')+'</div>';
  var m=document.createElement('div');
  m.id='cc6-queue-success-modal';m.className='mov open';m.style.zIndex='1250';
  m.innerHTML='<div class="modal" style="max-width:520px"><div class="mhd"><span style="font-size:22px">'+(commercial?'✅':'ℹ️')+'</span><div><div class="mtit">'+cc6Esc(title)+'</div></div></div>'+detail+'<div class="mfoot"><button class="mconf gr" data-ok>CONTINUAR LLAMADAS</button></div></div>';
  document.body.appendChild(m);
  var ok=m.querySelector('[data-ok]');
  if(ok)ok.onclick=function(){
    m.remove();
    if(typeof window.loadMetrics==='function')loadMetrics();
    if(typeof window.loadHistorial==='function')loadHistorial();
    if(typeof window.recargarCalendario==='function')recargarCalendario();
    if(window.AOS_pollNow)AOS_pollNow();
    if(typeof window.loadLead==='function')loadLead();
  };
}
function cc6QueueCommit(payload,sourceModal){
  var pending=cc6PendingKey('QUEUE_AUTO_APPOINTMENT',payload);
  return cc6Rpc('aos_callcenter_confirm_queue_appointment_v1',{p_token:cc6Token(),p_idempotency_key:pending.key,p_payload:payload}).then(function(res){
    if(!res||res.ok!==true){var er=new Error((res&&res.error)||'QUEUE_CONFIRM_FAILED');er.payload=res;throw er;}
    cc6ClearPending(pending.fp);
    if(sourceModal&&typeof window.closeCCModal==='function')closeCCModal(sourceModal);
    if(window.AOS_playSound)AOS_playSound(res.callState==='CITA CONFIRMADA'?'venta':'notif');
    if(payload.correo&&typeof window.enviarEmailConfirmacionCita==='function')enviarEmailConfirmacionCita({correo:payload.correo,nombre:payload.nombre,apellido:payload.apellido,fecha_cita:payload.fecha_cita,hora_cita:payload.hora_cita,tratamiento:payload.tratamiento,sede:payload.sede,dni:payload.dni,numero_limpio:payload.numero});
    cc6QueueFinishModal(res,payload);
    return res;
  }).catch(function(err){
    console.error('[CC6V23] queue commit',err,err&&err.payload);
    var ep=err&&err.payload||{},msg=ep.error||(err&&err.message)||'No se pudo guardar la cita';
    if(msg==='ACTIVE_APPOINTMENT_EXISTS'){var a=ep.activeAppointment||{};cc6InfoModal('cc6-active-error','Ya existe una cita activa','<b>Asesor:</b> '+cc6Esc(a.advisor||'—')+'<br><b>Fecha:</b> '+cc6Esc(a.date||'—')+' · '+cc6Esc(a.time||'—')+'<br>No se creó una segunda cita.',null);throw err;}
    if(msg==='IDENTITY_CONFLICT')cc6InfoModal('cc6-identity-error','Identidad requiere revisión','Este número está vinculado a más de una identidad. No se creó Call ni Agenda.',null);
    else if(msg==='PATIENT_ACTION_REQUIRED')cc6InfoModal('cc6-patient-error','Paciente existente detectado','El servidor detectó un paciente convertido. Reabre la cita y selecciona Reactivación, Seguimiento o Solo agendar desde el modal de excepción.',null);
    else cc6Toast('No se guardó',msg,'toast-alerta');
    throw err;
  });
}
window.ccConfirmarCita=function(){
  if(window.CC&&CC.guardando)return;
  cc6EnsureSelectors();
  var p=cc6PayloadFromCita(),bad=cc6ValidatePayload(p);
  if(bad){cc6Toast('⚠️ '+bad,'','toast-alerta');return;}
  cc6SetBusy(true);
  cc6Prepare(p.numero).then(function(prep){
    if(!prep||prep.ok!==true)throw Object.assign(new Error((prep&&prep.error)||'PATIENT_STATE_FAILED'),{payload:prep});
    CC.loop6Patient=prep;
    if(cc6ActiveBlock(prep)){cc6SetBusy(false);return;}
    if(prep.patientState==='CONVERTED_PATIENT'){
      cc6ExistingPatientModal(prep,p,function(action){cc6Commit(action,p,'cc-m-cita').finally(function(){cc6SetBusy(false);});});
      return;
    }
    cc6NoShowGate(prep,function(){cc6QueueCommit(p,'cc-m-cita').finally(function(){cc6SetBusy(false);});});
  }).catch(function(e){
    cc6SetBusy(false);
    var msg=(e&&e.payload&&e.payload.error)||(e&&e.message)||'No se pudo clasificar';
    if(msg!=='ACTIVE_APPOINTMENT_EXISTS'&&msg!=='IDENTITY_CONFLICT'&&msg!=='PATIENT_ACTION_REQUIRED')cc6Toast('No se guardó',msg,'toast-alerta');
  });
};
`;
runtime=runtime.slice(0,queueStart)+queuePatch+runtime.slice(queueEnd+1);

if(runtime.includes('id="cc6-contact-mode"')) throw new Error('Queue selector markup still exists');
if((runtime.match(/id="cc6-manual-mode"/g)||[]).length!==1) throw new Error('Expected exactly one manual selector');
if(!runtime.includes('aos_callcenter_confirm_queue_appointment_v1')) throw new Error('Queue RPC not wired');
if(!runtime.includes('CITA AGENDADA CON ÉXITO')) throw new Error('Queue success modal missing');
if(runtime.includes('if(window.__AOS_CC_LOOP6_V2__) return;')) throw new Error('Unsafe SPA early-return remains');
const finishStart=runtime.indexOf('function cc6QueueFinishModal('),commitStart=runtime.indexOf('function cc6QueueCommit(',finishStart),queueOverrideStart=runtime.indexOf('window.ccConfirmarCita=function(){',commitStart);
if(finishStart<0||commitStart<0||queueOverrideStart<0) throw new Error('V2.3 queue blocks missing');
const finishBlock=runtime.slice(finishStart,commitStart),commitBlock=runtime.slice(commitStart,queueOverrideStart);
if(finishBlock.includes('data-cancel')||finishBlock.includes('cc6InfoModal(')) throw new Error('Success modal must not expose Cancel');
if(!finishBlock.includes('data-ok')||!finishBlock.includes('CONTINUAR LLAMADAS')||!finishBlock.includes('loadLead()')) throw new Error('Success modal continue contract incomplete');
if(commitBlock.includes('loadLead()')) throw new Error('Next lead must not load before post-commit success confirmation');
fs.writeFileSync(jsPath,runtime,'utf8');

console.log('LOOP6_V23_PATCH=OK');
