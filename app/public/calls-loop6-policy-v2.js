/* ASCENDA OS · LOOP 6 POLICY V2
 * UI-only companion. Server remains authoritative for credit and ownership.
 */
(function(){
'use strict';
if(window.__AOS_CC_LOOP6_POLICY_V2__)return;
window.__AOS_CC_LOOP6_POLICY_V2__='v2';
function esc(s){return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
function lima(ts){if(!ts)return'';try{return new Intl.DateTimeFormat('es-PE',{timeZone:'America/Lima',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit',hour12:false}).format(new Date(ts));}catch(_e){return String(ts);}}
function closeModal(){var x=document.getElementById('cc6-policy-modal');if(x)x.remove();}
function show(title,html,kind){
  closeModal();
  var bg=kind==='ok'?'#ECFDF5':kind==='warn'?'#FFF7ED':'#FEF2F2';
  var bd=kind==='ok'?'#A7F3D0':kind==='warn'?'#FED7AA':'#FECACA';
  var fg=kind==='ok'?'#047857':kind==='warn'?'#9A3412':'#B91C1C';
  var ov=document.createElement('div');ov.id='cc6-policy-modal';ov.className='mov open';ov.style.zIndex='1400';
  ov.innerHTML='<div class="modal" style="max-width:520px"><div class="mhd"><div><div class="mtit">'+esc(title)+'</div><div style="font-size:9px;color:#9AAAC8">Validado por ASCENDA</div></div></div><div style="padding:11px;border:1px solid '+bd+';background:'+bg+';border-radius:10px;font-size:10px;line-height:1.6;color:'+fg+'">'+html+'</div><div class="mfoot"><button class="mconf gr" id="cc6-policy-ok">Entendido</button></div></div>';
  document.body.appendChild(ov);document.getElementById('cc6-policy-ok').onclick=closeModal;
}
function who(res){var s='';if(res&&res.executedBy)s+='<br><b>Ejecutado por:</b> '+esc(res.executedBy);if(res&&res.creditedAdvisor)s+='<br><b>Crédito/propiedad:</b> '+esc(res.creditedAdvisor);return s;}
function feedback(res){
  if(!res)return;
  if(res.ok===false&&res.error==='ACTIVE_APPOINTMENT_EXISTS'){
    var a=res.activeAppointment||{};show('Ya existe una cita activa','No se creó una segunda conversión ni una cita duplicada.'+(a.advisor?'<br><b>Asesor:</b> '+esc(a.advisor):'')+(a.date?'<br><b>Cita:</b> '+esc(a.date)+(a.time?' · '+esc(String(a.time).slice(0,5)):''):'') ,'stop');return;
  }
  if(res.ok!==true)return;
  var r=res.eligibilityReason||'';
  if(r==='REACTIVATION_BEFORE_15D')show('Reactivación todavía no elegible','La Agenda quedó registrada, pero <b>no suma nueva llamada + cita comercial</b>. El paciente continúa bajo seguimiento de la clínica.'+(res.policy&&res.policy.reactivationEligibleFrom?'<br><b>Elegible desde:</b> '+esc(lima(res.policy.reactivationEligibleFrom)):'')+who(res),'warn');
  else if(r==='NO_SHOW_PROTECTED_72H')show('Oportunidad protegida','La recuperación quedó como apoyo. No genera una segunda conversión y la Agenda conserva al asesor anterior.'+(res.policy&&res.policy.lastNoShow&&res.policy.lastNoShow.protectedUntil?'<br><b>Protegida hasta:</b> '+esc(lima(res.policy.lastNoShow.protectedUntil)):'')+who(res),'warn');
  else if(r==='ORIGINAL_OWNER_FOLLOWUP_EXISTS')show('El asesor original mantiene la oportunidad','Existe seguimiento registrado del propietario original. La ayuda queda trazada, pero <b>no se transfiere el crédito</b>.'+who(res),'warn');
  else if(r==='ORIGINAL_OWNER_REBOOK')show('Reagenda de oportunidad propia','La cita quedó como seguimiento de la oportunidad anterior y <b>no crea una segunda conversión</b>.'+who(res),'warn');
  else if(r==='NO_SHOW_RECOVERY_72H')show('Recuperación comercial válida','Pasaron 72 horas sin seguimiento registrado del propietario anterior. ASCENDA transfirió la oportunidad y registró <b>+1 llamada +1 cita</b>.'+who(res),'ok');
  else if(r==='AGENDA_ONLY')show('Agenda registrada','Se creó la Agenda con <b>0 llamada + 0 cita comercial</b>. La ejecución queda trazada.'+who(res),'ok');
}
function patchLabels(){
  ['cc6-manual-mode','cc6-contact-mode'].forEach(function(id){var s=document.getElementById(id);if(!s)return;var o=s.querySelector('option[value="CALLBACK"]');if(o)o.textContent='↩️ Seguimiento / callback / entrante';});
  var m=document.getElementById('cc6-existing-patient-modal');if(m&&!m.querySelector('[data-policy-note]')){var n=document.createElement('div');n.setAttribute('data-policy-note','1');n.style.cssText='margin-top:8px;padding:8px;border-radius:8px;background:#F8FAFC;border:1px solid #E2E8F0;font-size:9px;color:#64748B;line-height:1.5';n.innerHTML='<b>Validación automática:</b> ASCENDA comprobará 15 días, cita activa y propiedad NO ASISTIO durante 72 h. El selector no puede forzar crédito.';var f=m.querySelector('.mfoot');if(f&&f.parentNode)f.parentNode.insertBefore(n,f);}
}
var ob=new MutationObserver(patchLabels);ob.observe(document.documentElement,{childList:true,subtree:true});setTimeout(patchLabels,0);
function install(){if(typeof window._rpc!=='function'||window._rpc.__cc6policyv2)return false;var prev=window._rpc;function wrapped(fn,p,ok,fail){return prev(fn,p,function(res){if(ok)ok(res);if(fn==='aos_callcenter_commit_action_v1')setTimeout(function(){feedback(res);},0);},fail);}wrapped.__cc6policyv2=true;wrapped.__cc6wrapped=prev.__cc6wrapped||false;window._rpc=wrapped;return true;}
if(!install())setTimeout(install,100);
})();
