
var _SB='https://ituyqwstonmhnfshnaqz.supabase.co',_SK='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';

// ===== ENVÍO AUTOMÁTICO DE EMAIL AL CREAR CITA =====
function enviarEmailConfirmacionCita(datosCita) {
  var correo = (datosCita.correo || '').trim();
  if (!correo || correo.indexOf('@') < 0) {
    console.log('[EMAIL-CITA] Sin correo válido, skip email');
    return;
  }
  var nombre = ((datosCita.nombre || '') + ' ' + (datosCita.apellido || '')).trim();
  var fechaRaw = datosCita.fecha_cita || datosCita.fechaCita || '';
  // Formatear fecha legible
  var fechaLabel = fechaRaw;
  try {
    var dp = new Date(fechaRaw + 'T12:00:00');
    var dias = ['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'];
    var meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    fechaLabel = dias[dp.getDay()] + ' ' + dp.getDate() + ' de ' + meses[dp.getMonth()] + ', ' + dp.getFullYear();
  } catch(e) {}

  console.log('[EMAIL-CITA] Enviando confirmación a ' + correo + ' — ' + nombre);
  fetch('https://ascenda-os-production.up.railway.app/api/send-template', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      to: correo,
      template: 'confirmacion_cita',
      nombre: nombre,
      tratamiento: datosCita.tratamiento || 'Consulta',
      hora: datosCita.hora_cita || datosCita.horaCita || '',
      sede: datosCita.sede || '',
      fecha: fechaLabel,
      dni: datosCita.dni || '',
      telefono: datosCita.numero_limpio || datosCita.numero || '',
      email: correo,
      destinatario_id: (datosCita.numero_limpio || correo) + '_cita_' + fechaRaw
    })
  }).then(function(r) { return r.json(); }).then(function(d) {
    if (d && (d.ok || d.id)) {
      console.log('[EMAIL-CITA] ✅ Email enviado a ' + correo);
      if (window.AOS_showToast) AOS_showToast('📧 Email de cita enviado', correo, '');
    } else {
      console.log('[EMAIL-CITA] ⚠ Error:', JSON.stringify(d));
      if (window.AOS_showToast) AOS_showToast('⚠ Email no enviado', d && d.error ? d.error : 'Error desconocido', 'toast-alerta');
    }
  }).catch(function(e) {
    console.log('[EMAIL-CITA] ✕ Error:', e.message);
  });
}
// ===== _rpc — llamada a Supabase con timeout 15s =====
function _rpc(fn,p,ok,fail){
  var ctrl=typeof AbortController!=='undefined'?new AbortController():null;
  var tid=ctrl?setTimeout(function(){ctrl.abort();},15000):null;
  fetch(_SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json'},body:JSON.stringify(p||{}),signal:ctrl?ctrl.signal:undefined})
  .then(function(r){
    if(tid)clearTimeout(tid);
    if(!r.ok)throw new Error('HTTP '+r.status);
    return r.json();
  })
  .then(function(d){if(ok)ok(d);})
  .catch(function(e){
    if(tid)clearTimeout(tid);
    if(fail){fail(e);}else{console.error('[SB]',fn,e);}
  });
}
function _ctx(){var c=(window.AOS_getCtx&&window.AOS_getCtx())||{};var n=new Date();var hh=n.getFullYear()+'-'+String(n.getMonth()+1).padStart(2,'0')+'-'+String(n.getDate()).padStart(2,'0');return{a:(c.asesor||'').toUpperCase(),id:c.idAsesor||'',hoy:hh,mes:hh.slice(0,7)+'-01'};}

// ══════════════════════════════════════════════════════════════
// ESTADO GLOBAL
// ══════════════════════════════════════════════════════════════
var CC = { lead:null, token:'', guardando:false, subTipif:'NO CONTESTA', ficha360:null, fichaTab:'compras' };
var CAL_MES = new Date().getMonth(), CAL_ANIO = new Date().getFullYear(), CAL_DATA_MES = {};
var _segsData = [], _segFiltro = 'todos';
var MES_NOM = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
var MES_FULL = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

// ── INIT (global para re-inicialización desde app.html) ──────
function ccInit(){
  CC.lead=null;CC.guardando=false;CC.ficha360=null;CC.fichaTab='compras';
  CC.token = window.AOS_getToken ? window.AOS_getToken() : '';
  var hoy = (function(){var n=new Date();return n.getFullYear()+'-'+String(n.getMonth()+1).padStart(2,'0')+'-'+String(n.getDate()).padStart(2,'0');})();
  var fe=document.getElementById('cc-c-fecha');if(fe)fe.min=hoy;
  var fs=document.getElementById('cc-s-fecha');if(fs){fs.min=hoy;fs.value=hoy;}
  document.querySelectorAll('#cc-tipo-cita-grp .tb').forEach(function(t){t.addEventListener('click',function(){document.querySelectorAll('#cc-tipo-cita-grp .tb').forEach(function(x){x.classList.remove('act');});this.classList.add('act');});});
  poblarMeses();loadTrats();
  loadMetrics();
  // Si viene de seguimientos con un número específico, cargarlo directo
  if(window._pendingLead && window._pendingLead.num){
    var pl = window._pendingLead;
    window._pendingLead = null;
    CC.lead = {num:pl.num, trat:pl.trat||'', wa:'https://api.whatsapp.com/send?phone=51'+pl.num, rowNum:0, segId:pl.segId||'', fromSeg:true, intento:0, anuncio:''};
    document.getElementById('cc-num').textContent = pl.num;
    document.getElementById('cc-trat').textContent = pl.trat||'';
    document.getElementById('cc-meta').textContent = 'SEGUIMIENTO';
    document.getElementById('cc-tier').textContent = 'SEGUIMIENTO';
    document.getElementById('cc-no-lead').style.display = 'none';
    document.getElementById('cc-lead-panel').style.display = 'block';
    document.getElementById('cc-tipif').value = '';
    document.getElementById('cc-m-cita-num').textContent = 'Número: '+pl.num;
    document.getElementById('cc-m-seg-num').textContent = 'Número: '+pl.num;
    cargarNombrePaciente(pl.num);
  } else {
    loadLead();
  }
  loadHistorial();
  recargarCalendario();
  setTimeout(function(){loadScorePanel();}, 300);
  setTimeout(function(){var sc=document.getElementById('sc-llam');if(sc&&(sc.textContent==='—'||sc.textContent===''))loadScorePanel();}, 1500);
}
ccInit();

// ══════════════════════════════════════════════════════════════
// KPI CARDS
// ══════════════════════════════════════════════════════════════
function loadMetrics(){
  var x=_ctx();if(!x.a)return;
  _rpc('aos_panel_asesor',{p_asesor:x.a,p_id_asesor:x.id,p_hoy:x.hoy,p_mes_inicio:x.mes},function(d){if(!d)return;var set=function(id,v){var e=document.getElementById(id);if(e)e.textContent=v;};var its=(d.llamadasHoy||[]).map(function(l){return{hora:String(l.hora||'').slice(0,5),num:l.num||'',trat:l.trat||'',estado:l.estado||''};});set('m-llam',Number(d.llamHoy)||0);set('m-citas',Number(d.citasHoy)||0);var tot=Number(d.llamHoy)||0;set('m-conv',tot>0?Math.round((Number(d.citasHoy)||0)/tot*100)+'%':'0%');var sc=its.filter(function(x){return x.estado==='SIN CONTACTO'||x.estado==='NO CONTESTA';}).length;set('m-nc',sc);set('m-nc-sub',(Number(d.llamMes)||0)+' llam. mes');if(its.length)renderTipifDist(its);});
  _rpc('aos_monitoreo_equipo',{p_hoy:x.hoy},function(d){if(!d)return;var ctx=window.AOS_getCtx?window.AOS_getCtx():{};var filas=d.filas||[];var miId=(ctx.idAsesor||'');var idx=filas.findIndex(function(r){return (r.id_asesor||'')===(miId);});var pos=idx>=0?idx+1:1;var em=['🥇','🥈','🥉'];var el=document.getElementById('m-rank');if(el)el.textContent=(em[pos-1]||'')+'#'+pos;});
}

// ══════════════════════════════════════════════════════════════
// SIGUIENTE LEAD
// ══════════════════════════════════════════════════════════════
function loadLead(_retried){
  document.getElementById('cc-num').textContent='Cargando...';
  document.getElementById('cc-no-lead').style.display='none';
  document.getElementById('cc-lead-panel').style.display='none';
  var x=_ctx();
  if(!x.a||!x.id){
    /* Retry after 500ms — AOS.ctx might not be ready yet */
    if(!CC._retries)CC._retries=0;
    CC._retries++;
    if(CC._retries<=5){console.log('[CC] _ctx vacío, retry '+CC._retries+'/5...');setTimeout(loadLead,500);return;}
    document.getElementById('cc-num').textContent='Error: sin sesión';document.getElementById('cc-no-lead').style.display='block';document.getElementById('cc-no-txt').textContent='Sesión no detectada. Recarga la página.';console.error('[CC] _ctx vacío después de 5 reintentos:',JSON.stringify(x));return;
  }
  CC._retries=0;
  _rpc('aos_siguiente_lead',{p_asesor:x.a,p_id_asesor:x.id,p_hoy:x.hoy},function(res){
    if(!res||!res.ok||!res.lead){
      document.getElementById('cc-no-lead').style.display='block';
      document.getElementById('cc-no-txt').textContent=res?(res.msg||'Sin leads pendientes.'):'Sin leads pendientes.';
      document.getElementById('cc-num').textContent='—';
      document.getElementById('cc-tier').textContent='BASE OK'; return;
    }
    document.getElementById('cc-no-lead').style.display='none';
    document.getElementById('cc-lead-panel').style.display='block';
    CC.lead={num:res.lead&&res.lead.num||'',trat:res.lead&&res.lead.trat||'',intento:res.lead&&res.lead.intento||1,rowNum:0,fecha:res.lead&&String(res.lead.fecha||''),wa:'https://api.whatsapp.com/send?phone=51'+((res.lead&&res.lead.num)||'').replace(/\D/g,''),contexto:res.contexto||null};
    document.getElementById('cc-tier').textContent=res.tier||'TIER 1';
    document.getElementById('cc-num').textContent=CC.lead.num;
    document.getElementById('cc-trat').textContent=CC.lead.trat;
    document.getElementById('cc-meta').textContent='#'+CC.lead.intento+' · '+CC.lead.fecha;
    var adEl=document.getElementById('cc-anuncio');
    if(res.anuncio&&res.anuncio.nombre){adEl.innerHTML='<b>'+escH(res.anuncio.nombre)+'</b>';adEl.style.display='block';}else{adEl.innerHTML='';adEl.style.display='none';}
    var wrap=document.getElementById('pac-nombre-wrap');if(wrap)wrap.style.display='none';
    document.getElementById('cc-m-cita-num').textContent='Número: '+CC.lead.num;
    document.getElementById('cc-m-seg-num').textContent='Número: '+CC.lead.num;
    document.getElementById('cc-tipif').value='';document.getElementById('sub-tipif-wrap').classList.remove('open');
    cargarNombrePaciente(CC.lead.num);renderContexto(CC.lead.contexto);
  },function(e){
    console.error('[CC] loadLead error:',e);
    if(!_retried){console.log('[CC] Reintentando loadLead...');setTimeout(function(){loadLead(true);},2000);return;}
    document.getElementById('cc-num').textContent='—';
    document.getElementById('cc-no-lead').style.display='block';
    document.getElementById('cc-no-txt').textContent='Error cargando lead. Usa los botones de abajo.';
  });
}

// ══════════════════════════════════════════════════════════════
// HISTORIAL
// ══════════════════════════════════════════════════════════════
function loadHistorial(){
  var x=_ctx();
  if(!x.a)return;
  _rpc('aos_panel_asesor',{p_asesor:x.a,p_id_asesor:x.id,p_hoy:x.hoy,p_mes_inicio:x.mes},function(d){
    if(!d)return;
    var tbody=document.getElementById('cc-historial');
    var items=(d.llamadasHoy||[]).map(function(l){return{hora:String(l.hora||'').slice(0,5),num:l.num||'',trat:l.trat||'',estado:l.estado||''};});
    if(!items.length){tbody.innerHTML='<tr><td colspan="4" class="ld">Sin llamadas hoy</td></tr>';return;}
    var chipMap={'CITA CONFIRMADA':'est-cita','SIN CONTACTO':'est-sc','NO CONTESTA':'est-sc','NO LE INTERESA':'est-ni','SEGUIMIENTO':'est-seg','PROVINCIA':'est-base','SACAR DE LA BASE':'est-base'};
    tbody.innerHTML=items.slice(0,30).map(function(r){var est=r.estado==='NO CONTESTA'?'SIN CONTACTO':(r.estado||'—'),cls=chipMap[r.estado]||chipMap[est]||'est-base';return '<tr data-num="'+escH(r.num||'')+'" style="cursor:pointer;"><td style="white-space:nowrap;">'+escH(r.hora||'—')+'</td><td style="font-family:Exo\\ 2,sans-serif;font-weight:700;font-size:11px;">'+escH(r.num||'—')+'</td><td style="font-size:9px;color:#6B7BA8;max-width:80px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">'+escH((r.trat||'—').slice(0,14))+'</td><td><span class="est-chip '+cls+'">'+est+'</span></td></tr>';}).join('');
  },function(e){
    var tbody=document.getElementById('cc-historial');
    if(tbody)tbody.innerHTML='<tr><td colspan="4" class="ld">Error cargando historial</td></tr>';
  });
}

// ══════════════════════════════════════════════════════════════
// GUARDAR LLAMADA
// ══════════════════════════════════════════════════════════════
function ccGuardar(){
  if(CC.guardando)return;
  var tipif=document.getElementById('cc-tipif').value;
  if(!tipif){if(window.AOS_showToast)AOS_showToast('⚠️ Falta tipificación','Seleccioná una tipificación','');else alert('Falta tipificación');return;}
  if(tipif==='CITA CONFIRMADA'||tipif==='SEGUIMIENTO')return;
  CC.guardando=true;var btn=document.getElementById('cc-btn-guardar');btn.disabled=true;btn.innerHTML='<span class="sp-sm"></span> Guardando...';
  var payload={numero:CC.lead?CC.lead.num:'',estado:tipif,subEstado:tipif==='SIN CONTACTO'?CC.subTipif:'',obs:document.getElementById('cc-obs').value.trim(),tratamiento:CC.lead?CC.lead.trat:'',rowNum:CC.lead?(CC.lead.rowNum||0):0};
  var x=_ctx();var now=new Date();
  var row={fecha:x.hoy,numero:payload.numero,numero_limpio:(payload.numero||'').replace(/\D/g,''),tratamiento:payload.tratamiento,estado:payload.estado,sub_estado:payload.subEstado||'',observacion:payload.obs||'',hora_llamada:String(now.getHours()).padStart(2,'0')+':'+String(now.getMinutes()).padStart(2,'0')+':'+String(now.getSeconds()).padStart(2,'0'),asesor:x.a,id_asesor:x.id,intento:CC.lead?(CC.lead.intento||0)+1:1,anuncio:CC.lead?CC.lead.anuncio||'':'',created_at:now.toISOString()};
  fetch(_SB+'/rest/v1/aos_llamadas',{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(row)}).then(function(r){
    CC.guardando=false;btn.disabled=false;btn.innerHTML='\x3csvg width="13" height="13" viewBox="0 0 20 20" fill="none">\x3cpath d="M4 10l5 5 7-9" stroke="white" stroke-width="2" stroke-linecap="round"/>\x3c/svg>Guardar resultado';
    if(!r.ok){r.text().then(function(t){console.error('[AOS] Save error:',r.status,t);});throw new Error('HTTP '+r.status);}
    document.getElementById('cc-tipif').value='';document.getElementById('cc-obs').value='';document.getElementById('sub-tipif-wrap').classList.remove('open');
    if(window.AOS_playSound)AOS_playSound('notif');if(window.AOS_showToast)AOS_showToast('\u2713 Guardado','Llamada registrada.','');
    loadLead();loadHistorial();loadMetrics();
  }).catch(function(e){CC.guardando=false;btn.disabled=false;btn.innerHTML='\x3csvg width="13" height="13" viewBox="0 0 20 20" fill="none">\x3cpath d="M4 10l5 5 7-9" stroke="white" stroke-width="2" stroke-linecap="round"/>\x3c/svg>Guardar resultado';console.error('[AOS] Error guardando llamada:',e);if(window.AOS_showToast)AOS_showToast('Error',e&&e.message?e.message:'Error','toast-alerta');});
}

function ccConfirmarCita(){
  var tipoCita='';document.querySelectorAll('#cc-tipo-cita-grp .tb').forEach(function(t){if(t.classList.contains('act'))tipoCita=t.getAttribute('data-val');});
  if(!document.getElementById('cc-c-fecha').value){if(window.AOS_showToast)AOS_showToast('⚠️ Falta fecha','Seleccioná la fecha.','');else alert('Falta la fecha');return;}
  var p={numero:CC.lead?CC.lead.num:'',estado:'CITA CONFIRMADA',nombre:document.getElementById('cc-c-nombre').value.trim(),apellido:document.getElementById('cc-c-apellido').value.trim(),dni:document.getElementById('cc-c-dni').value.trim(),correo:document.getElementById('cc-c-correo').value.trim(),tipoAtencion:document.getElementById('cc-c-tipo-at').value,sede:document.getElementById('cc-c-sede').value,fechaCita:document.getElementById('cc-c-fecha').value,horaCita:document.getElementById('cc-c-hora').value,tratamiento:document.getElementById('cc-c-trat').value,tipoCita:tipoCita||'CONSULTA NUEVA',obs:document.getElementById('cc-c-obs').value.trim(),rowNum:CC.lead?(CC.lead.rowNum||0):0};
  var x=_ctx();var now=new Date();var numL=(p.numero||'').replace(/\D/g,'');
  var rowL={fecha:x.hoy,numero:p.numero,numero_limpio:numL,tratamiento:CC.lead?CC.lead.trat:'',estado:'CITA CONFIRMADA',observacion:p.obs||'',hora_llamada:String(now.getHours()).padStart(2,'0')+':'+String(now.getMinutes()).padStart(2,'0')+':'+String(now.getSeconds()).padStart(2,'0'),asesor:x.a,id_asesor:x.id,intento:CC.lead?(CC.lead.intento||0)+1:1,created_at:now.toISOString()};
  var rowC={numero_limpio:numL,numero:p.numero,nombre:p.nombre||'',apellido:p.apellido||'',dni:p.dni||'',correo:p.correo||'',tipo_atencion:p.tipoAtencion||'',sede:p.sede||'',fecha_cita:p.fechaCita,hora_cita:p.horaCita||'',tratamiento:p.tratamiento||'',tipo_cita:p.tipoCita||'CONSULTA NUEVA',asesor:x.a,id_asesor:x.id,estado_cita:'PENDIENTE',origen_cita:'CALL_CENTER',ts_creado:now.toISOString()};
  console.log('[AOS-DEBUG] ccConfirmarCita rowC:',JSON.stringify(rowC));console.log('[AOS-DEBUG] ccConfirmarCita rowL:',JSON.stringify(rowL));
  Promise.all([fetch(_SB+'/rest/v1/aos_llamadas',{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(rowL)}),fetch(_SB+'/rest/v1/aos_agenda_citas',{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(rowC)})]).then(function(){
    if(CC.lead&&CC.lead.segId&&CC.lead.fromSeg){fetch(_SB+'/rest/v1/aos_seguimientos?'+encodeURIComponent('"ID"')+'=eq.'+CC.lead.segId,{method:'PATCH',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify({"ESTADO":"COMPLETADO","TS_ACTUALIZADO":new Date().toISOString()})});}
    closeCCModal('cc-m-cita');document.getElementById('cc-tipif').value='';document.getElementById('cc-obs').value='';if(window.AOS_playSound)AOS_playSound('venta');if(window.AOS_showToast)AOS_showToast('Cita confirmada'+(CC.lead&&CC.lead.fromSeg?' · Seguimiento cerrado':''),'Excelente','toast-venta');
    // Enviar email de confirmación automáticamente
    enviarEmailConfirmacionCita(rowC);
    loadLead();loadHistorial();loadMetrics();if(window.AOS_pollNow)AOS_pollNow();}).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e&&e.message?e.message:'Error','toast-alerta');});
}

function ccConfirmarSeguimiento(){
  var fecha=document.getElementById('cc-s-fecha').value,hora=document.getElementById('cc-s-hora').value||'10:00';
  if(!fecha){if(window.AOS_showToast)AOS_showToast('⚠️ Falta fecha','','');else alert('Falta la fecha');return;}
  var proxTs=new Date(fecha+'T'+hora+':00').toISOString();
  var p={numero:CC.lead?CC.lead.num:'',estado:'SEGUIMIENTO',obs:document.getElementById('cc-s-obs').value.trim(),tratamiento:CC.lead?CC.lead.trat:'',proxReintentoTs:proxTs,rowNum:CC.lead?(CC.lead.rowNum||0):0};
  var x=_ctx();var now=new Date();var numL=(p.numero||'').replace(/\D/g,'');
  var rowL={fecha:x.hoy,numero:p.numero,numero_limpio:numL,tratamiento:p.tratamiento||'',estado:'SEGUIMIENTO',observacion:p.obs||'',hora_llamada:String(now.getHours()).padStart(2,'0')+':'+String(now.getMinutes()).padStart(2,'0')+':'+String(now.getSeconds()).padStart(2,'0'),asesor:x.a,id_asesor:x.id,prox_rein:p.proxReintentoTs,created_at:now.toISOString()};
  var segPromise;
  if(CC.lead&&CC.lead.segId&&CC.lead.fromSeg){
    segPromise=fetch(_SB+'/rest/v1/aos_seguimientos?'+encodeURIComponent('"ID"')+'=eq.'+CC.lead.segId,{method:'PATCH',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify({"FECHA_PROGRAMADA":fecha,"HORA_PROGRAMADA":hora,"OBS_RECONTACTO":p.obs||'',"ESTADO":"PENDIENTE","TS_ACTUALIZADO":now.toISOString()})});
  } else {
    var rowS={"NUMERO":numL,"TRATAMIENTO":p.tratamiento||'',"ASESOR":x.a,"ID_ASESOR":x.id,"FECHA_PROGRAMADA":fecha,"HORA_PROGRAMADA":hora,"OBS_RECONTACTO":p.obs||'',"ESTADO":"PENDIENTE"};
    segPromise=fetch(_SB+'/rest/v1/aos_seguimientos',{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(rowS)});
  }
  Promise.all([fetch(_SB+'/rest/v1/aos_llamadas',{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(rowL)}),segPromise]).then(function(){closeCCModal('cc-m-seg');document.getElementById('cc-tipif').value='';document.getElementById('cc-obs').value='';document.getElementById('sub-tipif-wrap').classList.remove('open');if(window.AOS_playSound)AOS_playSound('notif');if(window.AOS_showToast)AOS_showToast('Seguimiento '+(CC.lead&&CC.lead.fromSeg?'reprogramado':'programado'),fecha+' a las '+hora,'');loadLead();loadHistorial();loadMetrics();}).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e&&e.message?e.message:'Error','toast-alerta');});
}

// ══════════════════════════════════════════════════════════════
// SCORE — UNA SOLA LLAMADA para la tabla anual
// ══════════════════════════════════════════════════════════════
function poblarMeses(){
  var now=new Date(),html='',aHtml='';
  for(var i=0;i<24;i++){var d=new Date(now.getFullYear(),now.getMonth()-i,1),v=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0');html+='<option value="'+v+'"'+(i===0?' selected':'')+'>'+(MES_NOM[d.getMonth()]||'').toUpperCase()+' '+d.getFullYear()+'</option>';}
  var s1=document.getElementById('score-mes-sel');if(s1)s1.innerHTML=html;
  var yr=now.getFullYear();for(var y=yr;y>=yr-3;y--)aHtml+='<option value="'+y+'"'+(y===yr?' selected':'')+'>'+y+'</option>';
  var sa=document.getElementById('score-anio-sel');if(sa)sa.innerHTML=aHtml;
}

function loadScorePanel(){
  var sel=document.getElementById('score-mes-sel'),now=new Date();
  var mes=sel&&sel.value?parseInt(sel.value.split('-')[1],10):now.getMonth()+1;
  var anio=sel&&sel.value?parseInt(sel.value.split('-')[0],10):now.getFullYear();
  var td=document.getElementById('tipif-dist');if(td)td.innerHTML='<div class="ld"><span class="sp-sm"></span></div>';
  var set=function(id,v){var e=document.getElementById(id);if(e)e.textContent=v;};
  // Total + Leads + Tipificaciones — 1 sola llamada a Supabase
  (function(){var x=_ctx();var mesStr=anio+'-'+(mes<10?'0'+mes:String(mes))+'-01';var mk=anio+'-'+(mes<10?'0'+mes:String(mes));var now2=new Date(),esAct=(mes===now2.getMonth()+1&&anio===now2.getFullYear());_rpc('aos_panel_asesor',{p_asesor:x.a,p_id_asesor:x.id,p_hoy:x.hoy,p_mes_inicio:mesStr},function(d){
    if(!d)return;
    var rM=(d.resumenAnual||[]).filter(function(r){return String(r.mesKey||'').slice(0,7)===mk;})[0]||null;
    var vM=(d.ventasAnual||[]).filter(function(v){return String(v.mesKey||'').slice(0,7)===mk;})[0]||null;
    var ll=esAct?(Number(d.llamMes)||0):(rM?Number(rM.llamadas):0);
    var cc=esAct?(Number(d.citasMes)||0):(rM?Number(rM.citas):0);
    var aa=esAct?(Number(d.asistMes)||0):0;
    var vv=esAct?(Number(d.ventasMes)||0):(vM?Number(vM.ventas):0);
    var ff=esAct?(parseFloat(d.factMes)||0):(vM?parseFloat(vM.fact)||0:0);
    set('sc-llam',ll);set('sc-citas',cc);set('sc-asist',aa);set('sc-ventas',vv);
    set('sc-pct',ll>0?Math.round(cc/ll*100)+'%':'');
    set('sc-fact',ff>0?'S/'+parseFloat(ff).toFixed(0):'');
    var n=Number(d.leadsNuevos)||0,l=Number(d.leadsLlamados)||0,lc=Number(d.leadsCitas)||0;
    set('sc2-leads',n);set('sc2-llam',l);set('sc2-pct',n>0?Math.round(l/n*100)+'%':'');
    set('sc2-citas',lc);set('sc2-ventas','—');set('sc2-fact','—');
    var items=[];(d.tipifMes||[]).forEach(function(t){for(var i=0;i<Number(t.cnt||0);i++)items.push({estado:t.estado||''});});
    if(items.length)renderTipifDist(items);else{var td2=document.getElementById('tipif-dist');if(td2)td2.innerHTML='<div class="ld">Sin llamadas</div>';}
  });})();
  loadTablaAnual();
}

function renderTipifDist(items){
  var td=document.getElementById('tipif-dist');if(!td)return;
  var counts={},total=items.length||1;
  items.forEach(function(x){var e=x.estado==='NO CONTESTA'?'SIN CONTACTO':(x.estado||'—');counts[e]=(counts[e]||0)+1;});
  var cols={'CITA CONFIRMADA':'#16A34A','SIN CONTACTO':'#DC2626','NO LE INTERESA':'#7C3AED','SEGUIMIENTO':'#0A4FBF','PROVINCIA':'#D97706','SACAR DE LA BASE':'#9AAAC8'};
  var sorted=Object.keys(counts).sort(function(a,b){return counts[b]-counts[a];});
  td.innerHTML=sorted.map(function(e){var n=counts[e],p=Math.round(n/total*100),c=cols[e]||'#9AAAC8';return '<div class="tipif-row"><div class="tipif-lbl">'+e.slice(0,13)+'</div><div class="tipif-bar"><div class="tipif-fill" style="width:'+p+'%;background:'+c+';"></div></div><div class="tipif-cnt">'+n+'</div></div>';}).join('')||'<div class="ld">Sin llamadas</div>';
}

// TABLA ANUAL — UNA sola llamada a api_getHistoricoAnualAsesorT
function loadTablaAnual(){
  var ae=document.getElementById('score-anio-sel'),anio=ae?parseInt(ae.value,10):new Date().getFullYear();
  var ta=document.getElementById('tabla-anual');if(!ta)return;
  ta.innerHTML='<div class="ld"><span class="sp-sm"></span></div>';
  (function(){var x=_ctx();var ae=document.getElementById('score-anio-sel');var anio=ae?parseInt(ae.value,10):new Date().getFullYear();var ta=document.getElementById('tabla-anual');if(!ta)return;ta.innerHTML='<div class="ld"><span class="sp-sm"></span></div>';_rpc('aos_historico_asesor_anual',{p_asesor:x.a,p_id_asesor:x.id,p_anio:anio},function(res){if(!ta)return;if(!res||!res.meses||!res.meses.length){ta.innerHTML='<div class="ld" style="font-size:9px;">Sin datos</div>';return;}var MES_NOM2=['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];var rows=res.meses.map(function(m){var isCur=m.es_actual||false,bg=isCur?'background:#EBF2FF;':'';return '<tr style="border-bottom:1px solid #F0F4FC;'+bg+'"><td style="padding:2px 4px;font-weight:700;font-size:9px;">'+(MES_NOM2[(m.mes_num-1)||0]||'M'+m.mes_num)+(isCur?'<span style="color:#0A4FBF;font-size:7px;">●</span>':''  )+'</td><td style="padding:2px 4px;text-align:right;font-size:9px;">'+(m.llamadas||0)+'</td><td style="padding:2px 4px;text-align:right;font-size:9px;">'+(m.citas||0)+'</td><td style="padding:2px 4px;text-align:right;font-size:9px;font-weight:700;color:#0A4FBF;">'+(m.fact>0?'S/'+(parseFloat(m.fact).toFixed(0)):'—')+'</td></tr>';});ta.innerHTML='<table style="width:100%;border-collapse:collapse;"><thead><tr style="background:#F0F4FC;"><th style="padding:2px 4px;text-align:left;color:#9AAAC8;font-weight:700;font-size:7px;">Mes</th><th style="padding:2px 4px;text-align:right;color:#9AAAC8;font-weight:700;font-size:7px;">Llam</th><th style="padding:2px 4px;text-align:right;color:#9AAAC8;font-weight:700;font-size:7px;">Citas</th><th style="padding:2px 4px;text-align:right;color:#9AAAC8;font-weight:700;font-size:7px;">S/</th></tr></thead><tbody>'+rows.join('')+'</tbody></table>';});})();
}

function setTipoPeriodo(tipo){['mes','semana','hoy'].forEach(function(t){var b=document.getElementById('tipo-'+t);if(b){b.style.background=t===tipo?'#0A4FBF':'transparent';b.style.color=t===tipo?'#fff':'#6B7BA8';}});loadScorePanel();}

// ══════════════════════════════════════════════════════════════
// PANEL TABS
// ══════════════════════════════════════════════════════════════
function setPanelTab(tab){
  ['score','segs','top'].forEach(function(t){var b=document.getElementById('ptab-'+t),p=document.getElementById('panel-'+t);if(b)b.classList.toggle('act',t===tab);if(p)p.style.display=(t===tab?'block':'none');});
  if(tab==='score')loadScorePanel();if(tab==='segs')loadSegsPanel();if(tab==='top')loadTopPanel();
}

// ══════════════════════════════════════════════════════════════
// CALENDARIO MENSUAL — lee Supabase directamente
// ══════════════════════════════════════════════════════════════
function recargarCalendario(){
  var sede=(document.getElementById('cal-sede-sel')||{}).value||'';
  var lbl=document.getElementById('cal-mes-lbl');if(lbl)lbl.textContent=MES_FULL[CAL_MES]+' '+CAL_ANIO;
  var grid=document.getElementById('cal-dias-grid');if(grid)grid.innerHTML='<div style="grid-column:1/-1;text-align:center;padding:12px;color:#9AAAC8;font-size:10px;"><span class="sp-sm"></span></div>';
  document.getElementById('cal-detalle').innerHTML='<div class="cal-det-fecha">Selecciona un día con turnos</div>';
  CAL_DATA_MES={};
  var primero=new Date(CAL_ANIO,CAL_MES,1);
  var dow=primero.getDay(),offsetL=dow===0?6:dow-1;
  var diasEnMes=new Date(CAL_ANIO,CAL_MES+1,0).getDate();
  var semanas=Math.ceil((offsetL+diasEnMes)/7);
  var lunesInicio=new Date(primero);lunesInicio.setDate(primero.getDate()-offsetL);
  var pend=semanas,_sede=sede;
  for(var s=0;s<semanas;s++){
    var ls=new Date(lunesInicio);ls.setDate(lunesInicio.getDate()+s*7);
    var lsStr=ls.getFullYear()+'-'+String(ls.getMonth()+1).padStart(2,'0')+'-'+String(ls.getDate()).padStart(2,'0');
    (function(lunesStr){
      _rpc('aos_horarios_semana',{p_fecha_lunes:lunesStr,p_sede:_sede,p_rol:''},function(res){
        if(res&&res.ok&&res.dias){res.dias.forEach(function(d){
          if(!d.fecha)return;
          var t=d.turnos||[];
          if(!t.length&&(d.doctoras||d.enfermeria)){
            (d.doctoras||[]).forEach(function(x){t.push({rol:'DOCTORA',personal:x.label||x.personal||'',sede:x.sede||'',hora_inicio:x.horaIni||x.hora_inicio||'',hora_fin:x.horaFin||x.hora_fin||'',notas:x.tipo||x.notas||''});});
            (d.enfermeria||[]).forEach(function(g){(g.nombres||[]).forEach(function(n){t.push({rol:'ENFERMERIA',personal:n,sede:g.sede||'',hora_inicio:'',hora_fin:'',notas:''});});});
          }
          CAL_DATA_MES[d.fecha]=t;
        });}
        if(--pend===0)renderMes(_sede);
      });
    })(lsStr);
  }
}

function cambiarMesCal(dir){
  if(dir===0){CAL_MES=new Date().getMonth();CAL_ANIO=new Date().getFullYear();}
  else{CAL_MES+=dir;if(CAL_MES>11){CAL_MES=0;CAL_ANIO++;}if(CAL_MES<0){CAL_MES=11;CAL_ANIO--;}}
  recargarCalendario();
}

function renderMes(sede){
  var grid=document.getElementById('cal-dias-grid');if(!grid)return;
  var hoy=new Date(),hoyStr=hoy.getFullYear()+'-'+String(hoy.getMonth()+1).padStart(2,'0')+'-'+String(hoy.getDate()).padStart(2,'0');
  var primero=new Date(CAL_ANIO,CAL_MES,1);
  var diasEnMes=new Date(CAL_ANIO,CAL_MES+1,0).getDate();
  var dow=primero.getDay(),offsetL=dow===0?6:dow-1;
  var html='';
  // Relleno inicio
  for(var p2=offsetL-1;p2>=0;p2--){var d2=new Date(CAL_ANIO,CAL_MES,-p2);html+='<div class="cal-dia otro-mes"><div class="cal-dia-n" style="color:#DDE4F5;">'+d2.getDate()+'</div></div>';}
  // Días del mes
  for(var dia=1;dia<=diasEnMes;dia++){
    var fd=CAL_ANIO+'-'+String(CAL_MES+1).padStart(2,'0')+'-'+String(dia).padStart(2,'0');
    var turnos=CAL_DATA_MES[fd]||[];
    var esHoy=fd===hoyStr,esPas=fd<hoyStr,tieneTurno=turnos.length>0;
    var docs=turnos.filter(function(t){return t.rol==='DOCTORA';});
    var enfs=turnos.filter(function(t){return t.rol==='ENFERMERIA';});
    var dots='';
    docs.forEach(function(doc){var col=doc.sede==='SAN ISIDRO'?'#16A34A':doc.sede==='PUEBLO LIBRE'?'#D97706':'#6B7BA8';dots+='<div class="cal-dot" style="background:'+col+';"></div>';});
    if(enfs.length)dots+='<div class="cal-dot" style="background:#0A4FBF;"></div>';
    var cls='cal-dia'+(tieneTurno?' tiene-turno':'')+(esHoy?' es-hoy':'')+(esPas&&!esHoy?' pasado':'');
    var click=tieneTurno?('onclick="mostrarDetalleDia(\''+fd+'\')"'):'';
    html+='<div class="'+cls+'" '+click+'><div class="cal-dia-n">'+dia+'</div><div class="cal-dots">'+dots+'</div></div>';
  }
  // Relleno final
  var total=offsetL+diasEnMes,resto=total%7===0?0:7-(total%7);
  for(var r=1;r<=resto;r++)html+='<div class="cal-dia otro-mes"><div class="cal-dia-n" style="color:#DDE4F5;">'+r+'</div></div>';
  grid.innerHTML=html;
  grid.querySelectorAll('[data-dia]').forEach(function(el){el.onclick=function(){mostrarDetalleDia(this.getAttribute('data-dia'));};});
}

function mostrarDetalleDia(fecha){
  var det=document.getElementById('cal-detalle');if(!det)return;
  var turnos=CAL_DATA_MES[fecha]||[];
  if(!turnos.length){det.innerHTML='<div class="cal-det-fecha">Sin turnos este día</div>';return;}
  var partes=fecha.split('-');
  var d=new Date(parseInt(partes[0]),parseInt(partes[1])-1,parseInt(partes[2]));
  var dias=['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'];
  det.innerHTML='<div class="cal-det-fecha">'+dias[d.getDay()]+' '+d.getDate()+' '+MES_NOM[d.getMonth()]+' '+d.getFullYear()+'</div>'+
    turnos.map(function(t){
      var esDoc=t.rol==='DOCTORA',col=esDoc&&t.sede==='SAN ISIDRO'?'#16A34A':esDoc&&t.sede==='PUEBLO LIBRE'?'#D97706':'#0A4FBF';
      var bgBadge=esDoc?(t.sede==='SAN ISIDRO'?'#F0FDF4':'#FEFCE8'):'#EBF2FF';
      var nombre=(t.personal||t.label||'').replace(/^DRA\.\s*/,'Dr. ');
      var sede_s=(t.sede||'').replace('SAN ISIDRO','San Isidro').replace('PUEBLO LIBRE','Pueblo Libre');
      return '<div class="cal-det-row"><div class="cal-det-dot" style="background:'+col+';margin-top:3px;"></div><div><div class="cal-det-nombre">'+escH(nombre)+'</div><div class="cal-det-meta">'+escH(sede_s)+(t.hora_inicio?' · '+escH(t.hora_inicio)+' – '+escH(t.hora_fin||''):'')+'</div>'+(t.notas?'<span class="cal-det-badge" style="background:'+bgBadge+';color:'+col+';">'+escH(t.notas)+'</span>':'')+'</div></div>';
    }).join('');
}

// ══════════════════════════════════════════════════════════════
// SEGUIMIENTOS
// ══════════════════════════════════════════════════════════════
function loadSegsPanel(){
  var sp=document.getElementById('segs-panel');if(sp)sp.innerHTML='<div class="ld"><span class="sp-sm"></span></div>';
  var x=_ctx();_rpc('aos_get_seguimientos',{p_asesor:x.a,p_id_asesor:x.id,p_hoy:x.hoy},function(rows){
    if(!rows){if(sp)sp.innerHTML='<div style="text-align:center;color:#16A34A;padding:10px;font-size:10px;">✓ Sin seguimientos</div>';return;}
    var arr=Array.isArray(rows)?rows:[];
    var items=arr.map(function(s){var fecha=String(s.fecha_prog||'').slice(0,10),hora=String(s.hora_prog||'').slice(0,5);var venc=fecha&&fecha<x.hoy,esHoy=fecha===x.hoy;return{segId:s.id||'',num:s.numero||'',trat:s.tratamiento||'',obs:s.obs||'',fecha:fecha,hora:hora,fechaHora:fecha?(fecha+(hora?' '+hora:'')):'' ,vencido:venc&&!esHoy,esHoy:esHoy,whatsapp:s.whatsapp||('https://api.whatsapp.com/send?phone=51'+(s.numero||'').replace(/\D/g,''))};});
    var tot={vencido:items.filter(function(i){return i.vencido;}).length,hoy:items.filter(function(i){return i.esHoy;}).length,proximo:items.filter(function(i){return !i.vencido&&!i.esHoy;}).length,total:items.length};
    _segsData=items;
    var sv=document.getElementById('seg-v');if(sv)sv.textContent=tot.vencido||0;
    var sh=document.getElementById('seg-h');if(sh)sh.textContent=tot.hoy||0;
    var sp2=document.getElementById('seg-p');if(sp2)sp2.textContent=tot.proximo||0;
    renderSegs(_segsData,_segFiltro);
  });
}

function filtrarSegs(tipo){_segFiltro=(_segFiltro===tipo)?'todos':tipo;renderSegs(_segsData,_segFiltro);}

function renderSegs(items,filtro){
  var sp=document.getElementById('segs-panel');if(!sp)return;
  var f=filtro==='todos'?items:items.filter(function(s){if(filtro==='vencido')return s.vencido&&!s.esHoy;if(filtro==='hoy')return s.esHoy;return!s.vencido&&!s.esHoy;});
  if(!f.length){sp.innerHTML='<div style="text-align:center;color:#16A34A;padding:10px;font-size:10px;">✓ Sin seguimientos</div>';return;}
  sp.innerHTML=f.slice(0,25).map(function(s){
    var bg=s.vencido?'#FEF2F2':(s.esHoy?'#FFFBEB':'#F0F4FC'),bc=s.vencido?'#FECACA':(s.esHoy?'#FDE68A':'#DDE4F5'),cf=s.vencido?'#DC2626':(s.esHoy?'#D97706':'#6B7BA8');
    var sid=escH(s.segId||''),snum=escH(s.num||'—'),wa=escH(s.whatsapp||('https://api.whatsapp.com/send?phone=51'+(s.num||'').replace(/[^0-9]/g,'')));
    return '<div style="padding:7px;background:'+bg+';border:1px solid '+bc+';border-radius:7px;margin-bottom:4px;"><div style="display:flex;justify-content:space-between;align-items:flex-start;"><div style="flex:1;cursor:pointer;" onclick="abrirFichaPorNum(\''+snum+'\')"><div style="font-size:10px;font-weight:700;color:#0A4FBF;text-decoration:underline;">'+snum+'</div><div style="font-size:9px;color:#6B7BA8;">'+escH((s.trat||'').slice(0,22))+'</div>'+(s.obs?'<div style="font-size:8px;color:#9AAAC8;font-style:italic;">'+escH(s.obs.slice(0,38))+'</div>':'')+'</div><div style="font-size:9px;font-weight:700;color:'+cf+';margin-left:5px;white-space:nowrap;">'+escH(s.fechaHora||'—')+'</div></div><div style="display:flex;gap:3px;margin-top:4px;"><button data-wa="'+wa+'" onclick="segWa(this)" style="padding:2px 6px;border-radius:4px;background:#25D366;color:#fff;border:none;font-size:8px;font-weight:700;cursor:pointer;">WA</button><button data-num="'+snum+'" onclick="segLlamar(this)" style="padding:2px 6px;border-radius:4px;background:#0A4FBF;color:#fff;border:none;font-size:8px;font-weight:700;cursor:pointer;">Llamar</button><button data-id="'+sid+'" onclick="segCerrar(this)" style="padding:2px 6px;border-radius:4px;background:#F0F4FC;color:#6B7BA8;border:1px solid #DDE4F5;font-size:8px;font-weight:700;cursor:pointer;">✓</button></div></div>';
  }).join('');
}

function segWa(b){window.open(b.getAttribute('data-wa'),'_blank');}
function segLlamar(b){var num=b.getAttribute('data-num');if(!num)return;CC.lead={num:num,trat:'',wa:'https://api.whatsapp.com/send?phone=51'+num.replace(/[^0-9]/g,''),rowNum:0};document.getElementById('cc-num').textContent=num;document.getElementById('cc-tier').textContent='SEGUIM.';document.getElementById('cc-no-lead').style.display='none';document.getElementById('cc-lead-panel').style.display='block';document.getElementById('cc-tipif').value='';cargarNombrePaciente(num);}
function segCerrar(b){var sid=b.getAttribute('data-id');if(!sid)return;b.disabled=true;b.textContent='...';(function(){var x=_ctx();_rpc('aos_cerrar_seguimiento',{p_id:String(sid)},function(){loadSegsPanel();});})();}

// ══════════════════════════════════════════════════════════════
// TOP CLIENTES
// ══════════════════════════════════════════════════════════════
function loadTopPanel(){
  var tl=document.getElementById('top-list');if(tl)tl.innerHTML='<div class="ld"><span class="sp-sm"></span></div>';
  var x=_ctx();_rpc('aos_top_clientes_asesor',{p_asesor:x.a,p_id_asesor:x.id,p_limite:20},function(d){
    if(!tl)return;if(!d||!d.items||!d.items.length){tl.innerHTML='<div class="ld">Sin clientes</div>';return;}
    var em=['🥇','🥈','🥉'];
    tl.innerHTML=d.items.map(function(c,i){
      var nom=escH(c.nombre||c.num||'—'),num=escH(c.num||'');
      var fact='S/'+(parseFloat(c.total_historico||c.fact)||0).toFixed(0);
      var compras=Number(c.compras||c.nVentas)||0,ultV=c.ult_compra||c.ultVisita||'';
      var wa=escH('https://api.whatsapp.com/send?phone=51'+(c.num||'').replace(/[^0-9]/g,''));
      return '<div class="top-item" data-num="'+num+'" style="cursor:pointer;">'+
        '<div class="top-item-hd"><span style="font-size:11px;">'+(em[i]||('#'+(i+1)))+'</span><div class="top-nombre">'+nom+'</div><div style="text-align:right;"><div class="top-fact">'+fact+'</div><div class="top-meta">'+compras+' compras</div></div></div>'+
        (ultV?'<div class="top-meta" style="display:flex;justify-content:space-between;align-items:center;margin-top:3px;">Últ: <b style="color:#6B7BA8;">'+escH(ultV)+'</b><button data-wa="'+wa+'" onclick="event.stopPropagation();segWa(this)" style="padding:1px 5px;border-radius:3px;background:#25D366;color:#fff;border:none;font-size:8px;cursor:pointer;">WA</button></div>':'')+
      '</div>';
    }).join('');
  });
}

// ══════════════════════════════════════════════════════════════
// FICHA 360°
// ══════════════════════════════════════════════════════════════
function abrirFicha360(){if(!CC.lead||!CC.lead.num)return;abrirFichaPorNum(CC.lead.num);}

function abrirFichaPorNum(num){
  if(!num)return;
  document.getElementById('ficha-overlay').classList.add('open');
  document.getElementById('ficha-360').classList.add('open');
  document.getElementById('ficha-nombre').textContent='Cargando...';
  document.getElementById('ficha-sub').textContent=num;
  document.getElementById('ficha-tab-content').innerHTML='<div class="ld"><span class="sp-sm"></span>Cargando...</div>';
  _rpc('aos_get_historial_paciente',{p_numero:String(num).replace(/\D/g,'')},function(res){
    if(!res){document.getElementById('ficha-nombre').textContent='Sin datos';document.getElementById('ficha-tab-content').innerHTML='<div class="ld">Sin información.</div>';return;}
    var r={ok:true,num:num,paciente:res.paciente||{},compras:res.ventas||[],citas:res.citas||[],llamadas:res.llamadas||[],totalFact:parseFloat(res.totalFact)||0,totalCompras:Number(res.totalCompras)||0,totalCitas:Number(res.totalCitas)||0,totalContactos:Number(res.totalContactos)||0,whatsapp:'https://api.whatsapp.com/send?phone=51'+String(num).replace(/\D/g,'')};
    CC.ficha360=r;renderFicha360(r);
  });
}

function renderFicha360(res){
  var p=res.paciente||{};var nombre=((p.nombres||'')+' '+(p.apellidos||'')).trim()||res.num||'—';
  document.getElementById('ficha-nombre').textContent=nombre;
  document.getElementById('ficha-sub').textContent=res.num+' · '+(p.sede||'—');
  document.getElementById('ficha-status').textContent=p.estado||'ACTIVO';
  document.getElementById('ficha-status').style.background=p.estado==='INACTIVO'?'#FEF2F2':'#F0FDF4';
  document.getElementById('ficha-status').style.color=p.estado==='INACTIVO'?'#DC2626':'#16A34A';
  var compras=res.compras||res.ventas||[];
  document.getElementById('fb-fact').textContent='S/'+((res.totalFact||0).toFixed(0));
  document.getElementById('fb-compras').textContent=compras.length||res.totalCompras||0;
  document.getElementById('fb-citas').textContent=(res.citas||[]).length||res.totalCitas||0;
  document.getElementById('fb-contactos').textContent=(res.llamadas||[]).length||res.totalContactos||0;
  document.getElementById('fd-tel').textContent=p.telefono||res.num||'—';
  document.getElementById('fd-dni').textContent=p.documento||'—';
  document.getElementById('fd-sede').textContent=p.sede||'—';
  document.getElementById('fd-ult').textContent=p.ultimaVisita?String(p.ultimaVisita).slice(0,10):'—';
  document.getElementById('ficha-360')._num=res.num||(p.telefono||'');
  document.getElementById('ficha-360')._wa=res.whatsapp||('https://api.whatsapp.com/send?phone=51'+(res.num||'').replace(/\D/g,''));
  setFichaTab(CC.fichaTab,res);
}

function setFichaTab(tab,data){
  CC.fichaTab=tab;var res=data||CC.ficha360;
  ['compras','citas','contactos'].forEach(function(t){document.getElementById('ftab-'+t).classList.toggle('act',t===tab);});
  if(!res)return;
  var el=document.getElementById('ficha-tab-content'),html='';
  if(tab==='compras'){var items=res.compras||res.ventas||[];if(!items.length){el.innerHTML='<div class="ld">Sin compras</div>';return;}html=items.map(function(c){return '<div class="ficha-item"><div class="ficha-item-top"><div class="ficha-item-trat">'+escH(c.tratamiento||c.trat||'—')+'</div><div class="ficha-item-monto">S/'+(parseFloat(c.monto)||0).toFixed(0)+'</div></div><div class="ficha-item-meta">'+escH(c.fecha||'')+' · '+escH(c.asesor||'')+' · '+escH(c.sede||'')+'</div></div>';}).join('');}
  else if(tab==='citas'){var items=res.citas||[];if(!items.length){el.innerHTML='<div class="ld">Sin citas</div>';return;}var estMap={'PENDIENTE':'fe-pendiente','EFECTIVA':'fe-asistio','ASISTIO':'fe-asistio','ASISTIÓ':'fe-asistio','NO ASISTIO':'fe-noasist','NO ASISTIÓ':'fe-noasist','CANCELADA':'fe-cancelada'};html=items.map(function(c){var est=c.estado_cita||c.estado||'PENDIENTE',cls=estMap[est.toUpperCase()]||'fe-pendiente';return '<div class="ficha-item"><div class="ficha-item-top"><div class="ficha-item-trat">'+escH(c.tratamiento||c.trat||'—')+'</div><span class="ficha-item-est '+cls+'">'+escH(est)+'</span></div><div class="ficha-item-meta">'+escH(c.fecha_cita||c.fecha||'')+(c.hora_cita?' '+escH(c.hora_cita.slice(0,5)):'')+' · '+escH(c.asesor||'')+(c.doctora?' · '+escH(c.doctora):'')+'</div></div>';}).join('');}
  else if(tab==='contactos'){var items=res.llamadas||[];if(!items.length){el.innerHTML='<div class="ld">Sin contactos</div>';return;}var chipMap={'CITA CONFIRMADA':'est-cita','SIN CONTACTO':'est-sc','NO CONTESTA':'est-sc','NO LE INTERESA':'est-ni','SEGUIMIENTO':'est-seg'};html=items.map(function(l){var est=l.estado||'—',cls=chipMap[est]||'est-base';return '<div class="ficha-item"><div class="ficha-item-top"><span class="est-chip '+cls+'">'+escH(est==='NO CONTESTA'?'SIN CONTACTO':est)+'</span><span style="font-size:9px;color:#9AAAC8;">'+escH(l.asesor||'')+'</span></div><div class="ficha-item-meta">'+escH(l.fecha||'')+' '+escH((l.hora_llamada||l.hora||'').slice(0,5))+(l.observacion&&l.observacion.length<80?'<br><span style="color:#9AAAC8;font-size:8px;">'+escH(l.observacion.slice(0,80))+'</span>':'')+'</div></div>';}).join('');}
  el.innerHTML=html;
}

function cerrarFicha360(){document.getElementById('ficha-360').classList.remove('open');document.getElementById('ficha-overlay').classList.remove('open');}
function fichaWa(){var wa=document.getElementById('ficha-360')._wa;if(wa)window.open(wa,'_blank');}
function fichaLlamar(){doCallCC();}
function fichaEditar(){if(window.AOS_showToast)AOS_showToast('ℹ️ Próximamente','Bloque 3.','');}

// ══════════════════════════════════════════════════════════════
// UTILIDADES
// ══════════════════════════════════════════════════════════════
function cargarNombrePaciente(num){
  _rpc('aos_get_historial_paciente',{p_numero:String(num||'').replace(/\D/g,'')},function(res){
    var w=document.getElementById('pac-nombre-wrap');
    if(!res||!res.paciente){if(w)w.style.display='none';renderContexto(null);return;}
    var p=res.paciente,nombre=((p.nombres||'')+' '+(p.apellidos||'')).trim();
    if(w){
      if(nombre){document.getElementById('pac-nombre-txt').textContent=nombre;w.style.display='block';}
      else w.style.display='none';
    }
    // Renderizar contexto completo
    renderContexto({
      intentosPrevios:res.intentosPrevios||0,
      ultContacto:res.ultContacto||null,
      ultCita:res.ultCita||null,
      ultCompra:res.ultCompra||null,
      accionSugerida:generarSugerencia(res)
    });
  });
}

function generarSugerencia(res){
  if(!res)return '';
  var uc=res.ultContacto,uv=res.ultCompra,ucit=res.ultCita;
  if(uv&&uv.monto>500)return 'Cliente de alto valor (S/'+uv.monto+'). Ofrecer tratamiento complementario.';
  if(ucit&&ucit.estado==='PENDIENTE')return 'Tiene cita pendiente: '+ucit.trat+' en '+ucit.sede+'. Confirmar asistencia.';
  if(uc&&(uc.estado==='SIN CONTACTO'||uc.estado==='NO CONTESTA'))return 'Intentar contacto nuevamente. '+res.intentosPrevios+' intentos previos.';
  if(uv)return 'Paciente activo. Ult. compra: '+uv.trat+' ('+uv.fecha+')';
  return '';
}

function loadTrats(){
  _rpc('aos_catalogo_tratamientos',{},function(items){
    if(!items||!items.length)return;
    var opts='<option value="">— Seleccionar —</option>'+items.map(function(i){return '<option value="'+i.t+'">'+i.t+'</option>';}).join('');
    ['cc-c-trat','cm-trat'].forEach(function(id){var s=document.getElementById(id);if(s)s.innerHTML=opts;});
  });
}

function onCCTipif(val){var sub=document.getElementById('sub-tipif-wrap');sub.classList.remove('open');if(val==='SIN CONTACTO'){sub.classList.add('open');CC.subTipif='NO CONTESTA';document.querySelectorAll('.sub-opt').forEach(function(o){o.classList.toggle('act',o.getAttribute('data-val')==='NO CONTESTA');});}else if(val==='CITA CONFIRMADA'){
    document.getElementById('cc-m-cita').classList.add('open');
    document.getElementById('cc-m-cita-num').textContent='Número: '+(CC.lead?CC.lead.num:'—');
    if(CC.lead&&CC.lead.num){buscarPacParaCita(CC.lead.num);}
  }else if(val==='SEGUIMIENTO'){document.getElementById('cc-m-seg').classList.add('open');}}
function selectSubTipif(el){document.querySelectorAll('.sub-opt').forEach(function(o){o.classList.remove('act');});el.classList.add('act');CC.subTipif=el.getAttribute('data-val');}
function doCallCC(){if(window.AOS_setEstado)AOS_setEstado('EN LLAMADA','#0A4FBF');}
function openWaCC(){
  if(!CC.lead||!CC.lead.num) return;
  var num = CC.lead.num;
  var trat = CC.lead.trat || (document.getElementById('cc-trat')?document.getElementById('cc-trat').textContent:'') || '';
  var tipif = document.getElementById('cc-tipif') ? document.getElementById('cc-tipif').value : '';
  var nombreEl = document.getElementById('cc-paciente-nombre');
  var nombre = nombreEl ? nombreEl.textContent : '';
  if(!nombre||nombre==='—'||nombre.indexOf('No encontrado')>=0) nombre = '';

  // Cargar plantillas e info del tratamiento desde Supabase
  var _sk = typeof _SK!=='undefined'?_SK:(window.AOS_SB_KEY||'');
  var _sb = typeof _SB!=='undefined'?_SB:'https://ituyqwstonmhnfshnaqz.supabase.co';
  var headers = {'apikey':_sk,'Authorization':'Bearer '+_sk};

  Promise.all([
    fetch(_sb+'/rest/v1/aos_plantillas_whatsapp?activo=eq.true&order=orden',{headers:headers}).then(function(r){return r.json()}),
    fetch(_sb+'/rest/v1/aos_info_tratamientos?activo=eq.true',{headers:headers}).then(function(r){return r.json()})
  ]).then(function(results) {
    var plantillasDB = results[0] || [];
    var tratamientosDB = results[1] || [];

    // Buscar info del tratamiento
    var infoTrat = '';
    var tratUp = trat.toUpperCase();
    tratamientosDB.forEach(function(t) {
      if(tratUp.indexOf(t.campana.toUpperCase()) >= 0) {
        infoTrat = t.descripcion_corta;
      }
    });
    if(!infoTrat && trat) infoTrat = 'Te contactamos sobre nuestro servicio de *'+trat+'* que tenemos disponible para ti.';

    // Preparar nombre para plantilla
    var nombreTag = nombre ? (' ' + nombre.split(' ')[0]) : '';

    // Filtrar plantillas por contexto
    var plantillas = [];
    plantillasDB.forEach(function(p) {
      // Si tiene contexto específico, solo mostrar si la tipificación coincide
      if(p.contexto && tipif.toUpperCase().replace(/ /g,'_') !== p.contexto.toUpperCase()) return;
      
      // Reemplazar variables en mensaje
      var msg = p.mensaje
        .replace(/\{nombre\}/g, nombreTag)
        .replace(/\{tratamiento\}/g, trat || 'nuestros tratamientos')
        .replace(/\{info_tratamiento\}/g, infoTrat)
        .replace(/\{sede\}/g, 'San Isidro');
      
      plantillas.push({ icon: p.icono, label: p.nombre, color: p.color, msg: msg });
    });

    // Si no hay plantillas del DB, usar fallback
    if(!plantillas.length) {
      plantillas.push({icon:'💬',label:'Mensaje rápido',color:'#475569',
        msg:'Hola'+nombreTag+', te escribimos de *Zi Vital* 🌿\n\nTe contactamos sobre *'+(trat||'nuestros servicios')+'*.\n\n¿Te gustaría más información?'});
    }

    renderWaModal(num, trat, plantillas);
  }).catch(function() {
    // Fallback si falla Supabase
    var nombreTag = nombre ? (' '+nombre.split(' ')[0]) : '';
    renderWaModal(num, trat, [
      {icon:'📞',label:'Contacto rápido',color:'#DC2626',msg:'Hola'+nombreTag+', te llamamos de *Zi Vital* 🌿 sobre *'+(trat||'nuestros servicios')+'*.\n\n¿Te gustaría más información o agendar una evaluación? 😊'},
      {icon:'✏️',label:'Mensaje libre',color:'#475569',msg:'Hola'+nombreTag+', te escribimos de *Zi Vital* 🌿\n\n'}
    ]);
  });
}

function renderWaModal(num, trat, plantillas) {
  var existing = document.getElementById('wa-modal-cc');
  if (existing) existing.remove();

  var m = document.createElement('div');
  m.id = 'wa-modal-cc';
  m.style.cssText = 'position:fixed;inset:0;background:rgba(7,29,74,.6);z-index:9999;display:flex;align-items:center;justify-content:center;backdrop-filter:blur(3px);';

  var cardsHtml = plantillas.map(function(p, i) {
    return '<div onclick="waSeleccionarPlantilla('+i+')" style="padding:12px 14px;border:2px solid #EEF0F8;border-radius:10px;cursor:pointer;transition:all .15s;display:flex;align-items:center;gap:10px;" onmouseover="this.style.borderColor=\'#128C7E\';this.style.background=\'#F0FFF4\'" onmouseout="this.style.borderColor=\'#EEF0F8\';this.style.background=\'#fff\'">' +
      '<span style="font-size:18px;">'+p.icon+'</span>' +
      '<div style="flex:1;min-width:0;"><div style="font-size:11px;font-weight:700;color:'+p.color+';">'+escH(p.label)+'</div>' +
      '<div style="font-size:9px;color:#94A3B8;margin-top:1px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">'+escH(p.msg.substring(0,80).replace(/\n/g,' '))+'...</div></div></div>';
  }).join('');

  m.innerHTML = '<div style="background:#fff;border-radius:16px;width:440px;max-width:94vw;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,.3);">' +
    '<div style="background:linear-gradient(135deg,#075E54,#128C7E);padding:16px 20px;display:flex;align-items:center;gap:10px;">' +
    '<svg width="22" height="22" viewBox="0 0 24 24" fill="white"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z"/><path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z"/></svg>' +
    '<div><div style="font-size:14px;font-weight:800;color:#fff;">WhatsApp · Plantillas</div>' +
    '<div style="font-size:10px;color:#25D366;">'+escH(num)+' · '+escH(trat||'Sin campaña')+'</div></div>' +
    '<div onclick="document.getElementById(\'wa-modal-cc\').remove()" style="margin-left:auto;color:#fff;font-size:20px;cursor:pointer;padding:4px 8px;">&times;</div></div>' +
    '<div style="padding:14px 18px;max-height:50vh;overflow-y:auto;display:flex;flex-direction:column;gap:6px;">'+cardsHtml+'</div>' +
    '<div id="wa-preview-area" style="display:none;padding:14px 18px;border-top:1px solid #EEF0F8;">' +
    '<div style="font-size:9px;font-weight:700;color:#6B7BA8;text-transform:uppercase;margin-bottom:6px;">Vista previa · puedes editar antes de enviar</div>' +
    '<textarea id="wa-msg-edit" style="width:100%;height:120px;border:1.5px solid #DDE4F5;border-radius:8px;padding:10px;font-size:11px;font-family:DM Sans,sans-serif;resize:none;outline:none;box-sizing:border-box;"></textarea>' +
    '<div style="display:flex;gap:8px;margin-top:10px;">' +
    '<button onclick="document.getElementById(\'wa-preview-area\').style.display=\'none\'" style="flex:1;padding:9px;border:1.5px solid #DDE4F5;border-radius:8px;background:#fff;font-weight:600;font-size:11px;cursor:pointer;font-family:DM Sans,sans-serif;">\u2190 Volver</button>' +
    '<button onclick="waEnviarMsg()" style="flex:1;padding:9px;border:none;border-radius:8px;background:#25D366;color:#fff;font-weight:700;font-size:11px;cursor:pointer;font-family:DM Sans,sans-serif;">\ud83d\udcac Enviar WhatsApp</button></div></div></div>';

  document.body.appendChild(m);
  window._waPlantillas = plantillas;
}

function waSeleccionarPlantilla(idx) {
  var p = window._waPlantillas[idx];
  if(!p) return;
  document.getElementById('wa-msg-edit').value = p.msg;
  document.getElementById('wa-preview-area').style.display = 'block';
}

function waEnviarMsg() {
  var msg = document.getElementById('wa-msg-edit').value;
  var num = CC.lead ? CC.lead.num : '';
  if(!num) return;
  var cleanNum = '51' + num.replace(/\D/g,'');
  // Usa protocolo whatsapp:// para abrir directo en Desktop (más rápido que wa.me)
  var url = 'https://api.whatsapp.com/send?phone=' + cleanNum + '&text=' + encodeURIComponent(msg);
  window.open(url, '_blank');
  var m = document.getElementById('wa-modal-cc');
  if(m) m.remove();
}
function copyNumCC(){if(!CC.lead)return;navigator.clipboard.writeText(CC.lead.num).catch(function(){});if(window.AOS_showToast)AOS_showToast('⧉ Copiado',CC.lead.num,'');}
function closeCCModal(id){document.getElementById(id).classList.remove('open');document.getElementById('cc-tipif').value='';document.getElementById('sub-tipif-wrap').classList.remove('open');}
function abrirModalManual(){var inp=document.getElementById('manual-buscar'),res2=document.getElementById('manual-resultados'),nd=document.getElementById('manual-num-directo');if(inp)inp.value='';if(res2)res2.innerHTML='';if(nd)nd.value='';document.getElementById('cc-m-manual').classList.add('open');}
function usarNumManual(){var nd=document.getElementById('manual-num-directo'),num=(nd?nd.value:'').trim().replace(/[^0-9]/g,'');if(!num||num.length<7){if(window.AOS_showToast)AOS_showToast('Ingresa un número válido','','');return;}closeCCModal('cc-m-manual');CC.lead={num:num,trat:'',wa:'https://api.whatsapp.com/send?phone=51'+num,rowNum:0,manual:true};document.getElementById('cc-num').textContent=num;document.getElementById('cc-trat').textContent='';document.getElementById('cc-meta').textContent='LLAMADA MANUAL';document.getElementById('cc-tier').textContent='MANUAL';document.getElementById('cc-no-lead').style.display='none';document.getElementById('cc-lead-panel').style.display='block';document.getElementById('cc-tipif').value='';document.getElementById('cc-m-cita-num').textContent='Número: '+num;document.getElementById('cc-m-seg-num').textContent='Número: '+num;cargarNombrePaciente(num);}

var _tmr=null;
function buscarPacLive(q){
  if(_tmr)clearTimeout(_tmr);q=(q||'').trim();
  var el=document.getElementById('manual-resultados');
  if(q.length<2){if(el)el.innerHTML='';return;}
  if(el)el.innerHTML='<div class="ld"><span class="sp-sm"></span></div>';
  _tmr=setTimeout(function(){
    _rpc('aos_search_pacientes',{p_query:q,p_limit:8},function(rows){
      if(!el)return;
      if(!rows||!rows.length){el.innerHTML='<div style="font-size:10px;color:#D97706;padding:6px;">Sin resultados</div>';return;}
      el.innerHTML=(Array.isArray(rows)?rows:[]).map(function(p){
        var nom=escH(((p.nombres||'')+' '+(p.apellidos||'')).trim()),tel=escH(p.telefono||'');
        return '<div style="padding:6px;background:#F0F4FC;border:1px solid #DDE4F5;border-radius:7px;margin-bottom:3px;cursor:pointer;" data-tel="'+tel+'" onclick="selPacManual(this)"><div style="font-size:11px;font-weight:700;color:#0D1B3E;">'+nom+'</div><div style="font-size:9px;color:#9AAAC8;">'+tel+(p.sede?' · '+escH(p.sede):'')+'</div></div>';
      }).join('');
    });
  },350);
}
function selPacManual(el){var tel=el.getAttribute('data-tel'),nd=document.getElementById('manual-num-directo');if(nd)nd.value=tel;var r=document.getElementById('manual-resultados');if(r)r.innerHTML='<div style="padding:6px;background:#EBF2FF;border:1px solid #BFDBFE;border-radius:7px;font-size:10px;font-weight:700;color:#0A4FBF;">✓ '+escH(el.querySelector('div').textContent)+'</div>';}

function renderContexto(ctx){var el=document.getElementById('cc-contexto');if(!el)return;if(!ctx){el.style.display='none';el.innerHTML='';return;}var html='<div class="ctx-bloque"><div class="ctx-tit">📋 Contexto</div>';if(ctx.intentosPrevios>0)html+='<div class="ctx-row"><span class="ctx-lbl">Intentos prev.:</span><span class="ctx-val">'+ctx.intentosPrevios+'</span></div>';if(ctx.ultContacto){var est=(ctx.ultContacto.estado||'').toUpperCase(),badge=est==='SIN CONTACTO'||est==='NO CONTESTA'?'<span style="background:#FEF2F2;color:#B91C1C;padding:1px 5px;border-radius:3px;font-size:8px;font-weight:700;">'+escH(est)+'</span>':est==='CITA CONFIRMADA'?'<span style="background:#EBF2FF;color:#0A4FBF;padding:1px 5px;border-radius:3px;font-size:8px;font-weight:700;">CITA CONF.</span>':'<span style="color:#6B7BA8;font-weight:600;">'+escH(ctx.ultContacto.estado)+'</span>';html+='<div class="ctx-row"><span class="ctx-lbl">Últ. contacto:</span><span class="ctx-val">'+escH(ctx.ultContacto.fecha||'')+' · '+badge+'</span></div>';}if(ctx.ultCita)html+='<div class="ctx-row"><span class="ctx-lbl">Últ. cita:</span><span class="ctx-val">'+escH(ctx.ultCita.fecha||'')+' · '+escH(ctx.ultCita.trat||'')+'</span></div>';if(ctx.ultCompra)html+='<div class="ctx-row"><span class="ctx-lbl">Últ. compra:</span><span class="ctx-val">'+escH(ctx.ultCompra.trat||'')+' · S/'+(parseFloat(ctx.ultCompra.monto)||0).toFixed(0)+'</span></div>';if(ctx.accionSugerida)html+='<div class="ctx-acc"><span>💡</span><span>'+escH(ctx.accionSugerida)+'</span></div>';html+='</div>';el.innerHTML=html;el.style.display='block';}

function escH(s){return String(s||'').replace(/&/g,'&amp;').split('<').join('&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}



// ══════════════════════════════════════════════════════════════
// DETECCIÓN AUTOMÁTICA DE DOCTORA POR SEDE + DÍA + HORA
// ══════════════════════════════════════════════════════════════
function detectarDoctora(fechaStr,horaStr,sede,targetId){
  var el=document.getElementById(targetId);if(!el)return;
  if(!fechaStr||!sede){el.value='';return;}
  el.value='Buscando...';
  var hora=(horaStr||'10:00').slice(0,5);
  // Calcular lunes de la semana del fechaStr
  var dd=new Date(fechaStr+'T12:00:00');
  var day=dd.getDay();var diff=dd.getDate()-day+(day===0?-6:1);
  var lunes=new Date(dd.getFullYear(),dd.getMonth(),diff);
  var lunesStr=lunes.toISOString().slice(0,10);
  // Usar MISMA RPC que el calendario
  _rpc('aos_horarios_semana',{p_fecha_lunes:lunesStr,p_sede:sede,p_rol:''},function(res){
    if(!res||!res.dias){el.value='Sin datos';el.style.color='#D97706';return;}
    // Encontrar el día correcto en res.dias[]
    var diaObj=null;
    (res.dias||[]).forEach(function(d){if(d.fecha===fechaStr||d.fecha_date===fechaStr)diaObj=d;});
    if(!diaObj||!diaObj.turnos){el.value='Sin turnos ese dia';el.style.color='#D97706';return;}
    // Filtrar solo doctoras
    var docs=diaObj.turnos.filter(function(t){return(t.rol||'').toUpperCase()==='DOCTORA';});
    if(!docs.length){el.value='Sin doctora ese dia';el.style.color='#D97706';return;}
    // Filtrar por hora
    var matches=docs.filter(function(t){
      var hi=(t.hora_inicio||'').slice(0,5);var hf=(t.hora_fin||'').slice(0,5);
      return hora>=hi&&hora<=hf;
    });
    if(matches.length>0){
      el.value=matches[0].personal;
      el.style.color='#16A34A';
      // Filtrar tratamientos por servicios del profesional detectado
      filtrarTratsPorProfesional(matches[0].personal);
    } else {
      var allDocs=docs.map(function(t){return t.personal+' ('+t.hora_inicio.slice(0,5)+'-'+t.hora_fin.slice(0,5)+')';}).join(', ');
      el.value='Fuera de horario. '+allDocs;
      el.style.color='#D97706';
      resetTratsFull();
    }
  });
}
function filtrarTratsPorProfesional(nombre){
  fetch(_SB+'/rest/v1/aos_usuarios?nombre=eq.'+encodeURIComponent(nombre)+'&select=servicios',{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}})
  .then(function(r){return r.json();}).then(function(rows){
    if(!rows||!rows[0]||!rows[0].servicios||!rows[0].servicios.length){resetTratsFull();return;}
    var svcMap={};rows[0].servicios.forEach(function(s){svcMap[s.toUpperCase()]=true;});
    _rpc('aos_catalogo_tratamientos',{},function(items){
      if(!items||!items.length)return;
      var filtered=items.filter(function(i){return svcMap[i.t.toUpperCase()];});
      if(!filtered.length)filtered=items;
      var opts='<option value="">— Seleccionar —</option>'+filtered.map(function(i){return '<option value="'+i.t+'">'+i.t+'</option>';}).join('');
      var s1=document.getElementById('cc-c-trat');if(s1)s1.innerHTML=opts;
    });
  }).catch(function(){});
}
function resetTratsFull(){
  _rpc('aos_catalogo_tratamientos',{},function(items){
    if(!items||!items.length)return;
    var opts='<option value="">— Seleccionar —</option>'+items.map(function(i){return '<option value="'+i.t+'">'+i.t+'</option>';}).join('');
    var s1=document.getElementById('cc-c-trat');if(s1)s1.innerHTML=opts;
  });
}

// Event listeners para auto-detectar doctora en modal de cita
(function(){
  // Detectar doctora en modal cita CC
  ['cc-c-fecha','cc-c-hora','cc-c-sede','cc-c-tipo-at'].forEach(function(id){
    var e=document.getElementById(id);
    if(e){e.addEventListener('change',_triggerDocCC);e.addEventListener('input',_triggerDocCC);}
  });
  function _triggerDocCC(){
    var f=document.getElementById('cc-c-fecha').value;
    var h=document.getElementById('cc-c-hora').value;
    var s=document.getElementById('cc-c-sede').value;
    if(f&&s)detectarDoctora(f,h,s,'cc-c-doctora');
  }
  // Detectar doctora en modal cita manual
  ['cm-fecha','cm-hora','cm-sede','cm-tipo-at'].forEach(function(id){
    var e=document.getElementById(id);
    if(e){e.addEventListener('change',_triggerDocCM);e.addEventListener('input',_triggerDocCM);}
  });
  function _triggerDocCM(){
    var f=document.getElementById('cm-fecha').value;
    var h=document.getElementById('cm-hora').value;
    var s=document.getElementById('cm-sede').value;
    if(f&&s)detectarDoctora(f,h,s,'cm-doctora');
  }
  // Tipo cita tabs en modal manual
  var grp=document.getElementById('cm-tipo-cita-grp');
  if(grp)grp.querySelectorAll('.tb').forEach(function(t){t.addEventListener('click',function(){grp.querySelectorAll('.tb').forEach(function(x){x.classList.remove('act');});this.classList.add('act');});});
})();

// ══════════════════════════════════════════════════════════════
// MODAL CITA MANUAL (con número)
// ══════════════════════════════════════════════════════════════
function abrirCitaManual(){
  var hoy=(function(){var n=new Date();return n.getFullYear()+'-'+String(n.getMonth()+1).padStart(2,'0')+'-'+String(n.getDate()).padStart(2,'0');})();
  var el=document.getElementById('cm-fecha');if(el){el.min=hoy;el.value='';}
  document.getElementById('cm-num').value='';
  document.getElementById('cm-nombre').value='';
  document.getElementById('cm-apellido').value='';
  document.getElementById('cm-dni').value='';
  document.getElementById('cm-correo').value='';
  document.getElementById('cm-doctora').value='';
  document.getElementById('cm-obs').value='';
  var info=document.getElementById('cm-pac-info');if(info){info.style.display='none';info.innerHTML='';}
  document.getElementById('cc-m-cita-manual').classList.add('open');
}

var _cmTimer=null;
function buscarPacCitaManual(q){
  clearTimeout(_cmTimer);
  var info=document.getElementById('cm-pac-info');
  if(!q||q.length<3){if(info)info.style.display='none';return;}
  _cmTimer=setTimeout(function(){
    _rpc('aos_search_pacientes',{p_query:q,p_limit:5},function(rows){
      if(!rows||!rows.length){if(info)info.style.display='none';return;}
      var num=(document.getElementById('cm-num').value||'').replace(/\D/g,'');
      var match=rows.find(function(p){return (p.telefono||'').replace(/\D/g,'')===num;});
      if(match){
        info.style.display='block';
        info.innerHTML='<div style="font-size:11px;font-weight:700;color:#0A4FBF;">\u2713 Paciente encontrado: '+(match.nombres||'')+' '+(match.apellidos||'')+'</div><div style="font-size:9px;color:#6B7BA8;">DNI: '+(match.dni||'—')+' | Tel: '+(match.telefono||'')+'</div>';
        if(match.nombres)document.getElementById('cm-nombre').value=match.nombres;
        if(match.apellidos)document.getElementById('cm-apellido').value=match.apellidos;
        if(match.dni)document.getElementById('cm-dni').value=match.dni;
        if(match.correo)document.getElementById('cm-correo').value=match.correo;
      }
    });
  },400);
}

function guardarCitaManual(){
  var num=(document.getElementById('cm-num').value||'').trim().replace(/\D/g,'');
  if(!num||num.length<7){alert('Ingresa un número válido.');return;}
  var fecha=document.getElementById('cm-fecha').value;
  if(!fecha){alert('Selecciona la fecha de la cita.');return;}
  var x=_ctx();var now=new Date();
  var tipoCita='CONSULTA NUEVA';
  var grp=document.getElementById('cm-tipo-cita-grp');
  if(grp)grp.querySelectorAll('.tb').forEach(function(t){if(t.classList.contains('act'))tipoCita=t.getAttribute('data-val');});
  var doctora=document.getElementById('cm-doctora').value||'';
  var rowC={
    numero_limpio:num,numero:num,
    nombre:document.getElementById('cm-nombre').value.trim(),
    apellido:document.getElementById('cm-apellido').value.trim(),
    dni:document.getElementById('cm-dni').value.trim(),
    correo:document.getElementById('cm-correo').value.trim(),
    tipo_atencion:document.getElementById('cm-tipo-at').value,
    sede:document.getElementById('cm-sede').value,
    fecha_cita:fecha,
    hora_cita:document.getElementById('cm-hora').value||'10:00',
    tratamiento:document.getElementById('cm-trat').value,
    tipo_cita:tipoCita,
    doctora:doctora,
    asesor:x.a,id_asesor:x.id,
    estado_cita:'PENDIENTE',
    origen_cita:'CITA_MANUAL',
    obs:document.getElementById('cm-obs').value.trim(),
    ts_creado:now.toISOString()
  };
  rowC.estado_cita='PENDIENTE';
  var rowLM={fecha:x.hoy,numero:num,numero_limpio:num,tratamiento:rowC.tratamiento||'',estado:'CITA CONFIRMADA',hora_llamada:String(now.getHours()).padStart(2,'0')+':'+String(now.getMinutes()).padStart(2,'0')+':'+String(now.getSeconds()).padStart(2,'0'),asesor:x.a,id_asesor:x.id,intento:1,created_at:now.toISOString()};
  console.log('[AOS] citaManual cita:',JSON.stringify(rowC));
  console.log('[AOS] citaManual llamada:',JSON.stringify(rowLM));
  Promise.all([
    fetch(_SB+'/rest/v1/aos_agenda_citas',{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(rowC)}),
    fetch(_SB+'/rest/v1/aos_llamadas',{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(rowLM)})
  ]).then(function(results){
    var allOk=results.every(function(r){return r.ok;});
    if(!allOk)throw new Error('Error guardando');
    closeCCModal('cc-m-cita-manual');
    if(window.AOS_playSound)AOS_playSound('venta');
    if(window.AOS_showToast)AOS_showToast('Cita agendada','Cita + llamada registradas','toast-venta');
    // Enviar email de confirmación automáticamente
    enviarEmailConfirmacionCita(rowC);
    loadMetrics();loadHistorial();
  }).catch(function(e){
    console.error('[AOS] Error citaManual:',e);
    if(window.AOS_showToast)AOS_showToast('Error',e&&e.message?e.message:'Error al guardar','toast-alerta');
  });
}

// Incluir doctora en ccConfirmarCita
var _origCCConfirmarCita = ccConfirmarCita;
ccConfirmarCita = function(){
  // Inyectar doctora al payload antes de guardar
  var docEl=document.getElementById('cc-c-doctora');
  if(docEl&&docEl.value){
    var _origFetch=window.fetch;
    window.fetch=function(url,opts){
      if(url.indexOf('aos_agenda_citas')>=0&&opts&&opts.body){
        try{var b=JSON.parse(opts.body);b.doctora=docEl.value;opts.body=JSON.stringify(b);}catch(e){}
      }
      return _origFetch.call(this,url,opts);
    };
    _origCCConfirmarCita();
    setTimeout(function(){window.fetch=_origFetch;},3000);
  } else {
    _origCCConfirmarCita();
  }
};


// Buscar paciente existente y autocompletar campos del modal de cita
function buscarPacParaCita(num){
  var numL=String(num||'').replace(/\D/g,'');
  if(!numL||numL.length<7)return;
  _rpc('aos_search_pacientes',{p_query:numL,p_limit:3},function(rows){
    if(!rows||!rows.length)return;
    var match=rows.find(function(p){return(p.telefono||'').replace(/\D/g,'')===numL;});
    if(!match)match=rows[0];
    if(match.nombres){var e=document.getElementById('cc-c-nombre');if(e&&!e.value)e.value=match.nombres;}
    if(match.apellidos){var e=document.getElementById('cc-c-apellido');if(e&&!e.value)e.value=match.apellidos;}
    if(match.dni){var e=document.getElementById('cc-c-dni');if(e&&!e.value)e.value=match.dni;}
    if(match.correo){var e=document.getElementById('cc-c-correo');if(e&&!e.value)e.value=match.correo;}
  });
}

