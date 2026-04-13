// agenda.js — Agenda Global | AscendaOS v1 | 100% Supabase
var _SB='https://ituyqwstonmhnfshnaqz.supabase.co';
var _SK='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';
function _rpc(fn,p,ok,fail){fetch(_SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json'},body:JSON.stringify(p||{})}).then(function(r){return r.json();}).then(ok||function(){}).catch(fail||function(e){console.error('[SB]',fn,e);});}
function h(s){var o=String(s||'');o=o.split('&').join('&amp;');o=o.split(String.fromCharCode(60)).join('&lt;');o=o.split('>').join('&gt;');o=o.split('"').join('&quot;');return o;}
function el(id){return document.getElementById(id);}

var DIAS=['Domingo','Lunes','Martes','Mi\u00e9rcoles','Jueves','Viernes','S\u00e1bado'];
var MESES=['','Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
var AG={fecha:new Date().toISOString().slice(0,10), data:null, sel:null, editId:null, filtroEstado:''};
var ASESORES_MAP={'WILMER':'ZIV-004','RUVILA':'ZIV-002','MIREYA':'ZIV-003','SRA CARMEN':'ZIV-005','CESAR':'ZIV-001'};
var ESTADOS=[
  {val:'PENDIENTE',lbl:'Pendiente',cls:'est-btn-pend'},
  {val:'CITA CONFIRMADA',lbl:'Cita Confirmada',cls:'est-btn-conf'},
  {val:'ASISTIO',lbl:'Asisti\u00f3',cls:'est-btn-asist'},
  {val:'EFECTIVA',lbl:'Efectiva',cls:'est-btn-efect'},
  {val:'NO ASISTIO',lbl:'No Asisti\u00f3',cls:'est-btn-noasist'},
  {val:'CANCELADA',lbl:'Cancelada',cls:'est-btn-cancel'}
];

(function(){
  el('ag-fecha').value=AG.fecha;
  updateDateLabel();
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  var a=(ctx.asesor||'').toUpperCase();
  if(a&&el('ed-asesor')){el('ed-asesor').value=a;}
  agLoad();
})();

function updateDateLabel(){
  var d=new Date(AG.fecha+'T12:00:00');
  el('ag-fecha-lbl').textContent=DIAS[d.getDay()]+', '+d.getDate()+' de '+MESES[d.getMonth()+1]+' '+d.getFullYear();
}
function agNav(dir){
  var d=new Date(AG.fecha+'T12:00:00');
  d.setDate(d.getDate()+dir);
  AG.fecha=d.toISOString().slice(0,10);
  el('ag-fecha').value=AG.fecha;
  updateDateLabel();agLoad();
}
function agHoy(){AG.fecha=new Date().toISOString().slice(0,10);el('ag-fecha').value=AG.fecha;updateDateLabel();agLoad();}

function agLoad(){
  AG.fecha=el('ag-fecha').value||AG.fecha;
  updateDateLabel();
  var sede=el('ag-sede').value;
  var asesor=el('ag-asesor').value;
  _rpc('aos_agenda_dia',{p_fecha:AG.fecha,p_sede:sede||'',p_asesor_filtro:asesor||''},function(d){
    if(!d){return;}
    AG.data=d;
    renderKPIs(d.resumen||{});
    renderCitas(d.citas||[]);
    renderTurnos(d.turnos||[]);
  });
}

function agFilterEstado(){AG.filtroEstado=el('ag-estado').value;if(AG.data)renderCitas(AG.data.citas||[]);}

function estCls(e){
  var u=(e||'').toUpperCase();
  if(u==='PENDIENTE')return 'est-pend';
  if(u==='CITA CONFIRMADA'||u==='CONFIRMADA')return 'est-conf';
  if(u==='ASISTIO'||u==='ASISTI\u00d3'||u==='EFECTIVA')return 'est-asist';
  if(u==='EFECTIVA')return 'est-efect';
  if(u.indexOf('NO ASIST')>=0)return 'est-noasist';
  if(u==='CANCELADA')return 'est-cancel';
  return 'est-pend';
}

function renderKPIs(r){
  el('ag-total').textContent=r.total||0;
  el('ag-pend').textContent=r.pendiente||0;
  el('ag-asist').textContent=r.asistio||0;
  el('ag-noasist').textContent=r.noAsistio||0;
  el('ag-cancel').textContent=r.cancelada||0;
}

function renderCitas(citas){
  var f=AG.filtroEstado;
  var filtered=f?citas.filter(function(c){
    var e=(c.estado_cita||'').toUpperCase();
    if(f==='ASISTIO')return e.indexOf('ASISTI')>=0||e==='EFECTIVA';
    if(f==='NO ASISTIO')return e.indexOf('NO ASIST')>=0;
    return e===f;
  }):citas;
  el('ag-list-count').textContent=filtered.length+' cita'+(filtered.length!==1?'s':'');
  var tb=el('ag-tbody');
  if(!filtered.length){tb.innerHTML='<tr><td colspan="7" class="ld">Sin citas este d\u00eda</td></tr>';return;}
  tb.innerHTML=filtered.map(function(c){
    var cli=((c.nombre||'')+' '+(c.apellido||'')).trim();
    var hora=(c.hora_cita||'').toString().substring(0,5);
    var cls=estCls(c.estado_cita);
    return '<tr onclick="agDetalle(\''+h(c.id||'')+'\')">'+'<td style="font-weight:700;color:#0D1B3E;white-space:nowrap;">'+h(hora||'--')+'</td>'+'<td><div style="font-weight:700;font-size:11px;">'+h((cli||'--').substring(0,25))+'</div><div style="font-size:9px;color:#9AAAC8;">'+h(c.numero_limpio||c.numero||'')+'</div></td>'+'<td style="font-size:10px;">'+h((c.tratamiento||'').substring(0,18))+'</td>'+'<td style="font-size:10px;color:#6B7BA8;">'+h((c.sede||'').substring(0,10))+'</td>'+'<td style="font-size:10px;">'+h((c.asesor||'').substring(0,10))+'</td>'+'<td><span class="est-b '+cls+'">'+h(c.estado_cita||'')+'</span></td>'+'<td style="font-size:10px;color:#6B7BA8;">'+h((c.doctora||'').substring(0,12))+'</td></tr>';
  }).join('');
}

function renderTurnos(turnos){
  var box=el('ag-turnos');
  if(!turnos||!turnos.length){box.innerHTML='<div class="ld">Sin turnos</div>';return;}
  box.innerHTML=turnos.map(function(t){
    var isDoc=(t.rol||'').toUpperCase()==='DOCTORA';
    return '<div class="turno-card '+(isDoc?'turno-doc':'turno-enf')+'"><div class="turno-nombre">'+h(t.personal)+'</div><div class="turno-meta">'+h(t.rol)+' \u00b7 '+h(t.sede)+' \u00b7 '+h(t.hora_inicio)+'-'+h(t.hora_fin)+'</div></div>';
  }).join('');
}

// ── MODAL DETALLE ──
function agDetalle(id){
  var citas=(AG.data&&AG.data.citas)||[];
  var c=citas.find(function(x){return x.id===id;});
  if(!c)return;
  AG.sel=c;
  var cli=((c.nombre||'')+' '+(c.apellido||'')).trim();
  el('det-nombre').textContent=cli||'--';
  el('det-sub').textContent=(c.numero_limpio||c.numero||'')+' \u00b7 '+(c.tratamiento||'');
  var info='<div class="det-row"><div class="det-lbl">Fecha</div><div class="det-val">'+h(c.fecha_cita)+'</div></div>'+'<div class="det-row"><div class="det-lbl">Hora</div><div class="det-val">'+h((c.hora_cita||'').toString().substring(0,5))+'</div></div>'+'<div class="det-row"><div class="det-lbl">Sede</div><div class="det-val">'+h(c.sede)+'</div></div>'+'<div class="det-row"><div class="det-lbl">Tipo</div><div class="det-val">'+h(c.tipo_cita)+'</div></div>'+'<div class="det-row"><div class="det-lbl">Tratamiento</div><div class="det-val">'+h(c.tratamiento)+'</div></div>'+'<div class="det-row"><div class="det-lbl">Asesor</div><div class="det-val">'+h(c.asesor)+'</div></div>'+'<div class="det-row"><div class="det-lbl">Atenci\u00f3n</div><div class="det-val">'+h(c.tipo_atencion||'')+'</div></div>'+'<div class="det-row"><div class="det-lbl">Doctora</div><div class="det-val">'+h(c.doctora||'Sin asignar')+'</div></div>';
  el('det-info').innerHTML=info;
  el('det-nota').value=c.obs||'';
  // Botones de estado
  el('det-estados').innerHTML=ESTADOS.map(function(e){
    var act=(c.estado_cita||'').toUpperCase()===e.val?'act':'';
    return '<div class="est-btn '+e.cls+' '+act+'" data-val="'+e.val+'" onclick="agSelEstado(this)">'+e.lbl+'</div>';
  }).join('');
  el('ag-m-det').classList.add('open');
}
function agCloseDet(){el('ag-m-det').classList.remove('open');}
function agSelEstado(btn){
  el('det-estados').querySelectorAll('.est-btn').forEach(function(b){b.classList.remove('act');});
  btn.classList.add('act');
}
function agGuardarEstado(){
  if(!AG.sel)return;
  var nuevoEstado='';
  el('det-estados').querySelectorAll('.est-btn.act').forEach(function(b){nuevoEstado=b.getAttribute('data-val');});
  var nota=el('det-nota').value.trim();
  var updates={estado_cita:nuevoEstado,ts_actualizado:new Date().toISOString()};
  if(nota&&nota!==(AG.sel.obs||''))updates.obs=nota;
  fetch(_SB+'/rest/v1/aos_agenda_citas?id=eq.'+AG.sel.id,{method:'PATCH',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(updates)}).then(function(r){
    if(!r.ok)throw new Error('HTTP '+r.status);
    if(window.AOS_showToast)AOS_showToast('Estado actualizado',nuevoEstado,'');
    agCloseDet();agLoad();
  }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
}
function agReagendar(){
  if(!AG.sel)return;
  agAbrirEditar();
  el('edit-titulo').textContent='Reagendar cita';
  el('ed-fecha').value='';el('ed-fecha').focus();
}

// ── MODAL EDITAR / NUEVA ──
function agAbrirEditar(){
  var c=AG.sel;
  if(c){
    el('edit-titulo').textContent='Editar cita';
    el('edit-sub').textContent='N\u00famero: '+(c.numero_limpio||c.numero||'');
    el('ed-nombre').value=c.nombre||'';el('ed-apellido').value=c.apellido||'';
    el('ed-num').value=c.numero_limpio||c.numero||'';el('ed-dni').value=c.dni||'';
    el('ed-correo').value=c.correo||'';el('ed-asesor').value=c.asesor||'';
    el('ed-sede').value=c.sede||'';el('ed-tipo-at').value=c.tipo_atencion||'';
    el('ed-fecha').value=c.fecha_cita||'';el('ed-hora').value=(c.hora_cita||'').toString().substring(0,5)||'10:00';
    el('ed-trat').value=c.tratamiento||'';el('ed-tipo-cita').value=c.tipo_cita||'CONSULTA NUEVA';
    el('ed-estado').value=c.estado_cita||'PENDIENTE';el('ed-obs').value=c.obs||'';
    AG.editId=c.id;
  }
  agCloseDet();
  el('ag-m-edit').classList.add('open');
}
function agAbrirNueva(){
  AG.sel=null;AG.editId=null;
  el('edit-titulo').textContent='Nueva cita';el('edit-sub').textContent='';
  el('ed-nombre').value='';el('ed-apellido').value='';el('ed-num').value='';
  el('ed-dni').value='';el('ed-correo').value='';el('ed-sede').value='';
  el('ed-tipo-at').value='';el('ed-fecha').value=AG.fecha;
  el('ed-hora').value='10:00';el('ed-trat').value='';
  el('ed-tipo-cita').value='CONSULTA NUEVA';el('ed-estado').value='PENDIENTE';
  el('ed-obs').value='';el('ed-pac-info').style.display='none';
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  el('ed-asesor').value=(ctx.asesor||'WILMER').toUpperCase();
  el('ag-m-edit').classList.add('open');
}
function agCloseEdit(){el('ag-m-edit').classList.remove('open');}

function agGuardarEdit(){
  var num=(el('ed-num').value||'').trim().replace(/\D/g,'');
  var fecha=el('ed-fecha').value;
  if(!fecha){alert('Selecciona fecha');return;}
  var asesor=el('ed-asesor').value;
  var now=new Date();
  var row={
    nombre:el('ed-nombre').value.trim(),apellido:el('ed-apellido').value.trim(),
    numero:num,numero_limpio:num,dni:el('ed-dni').value.trim(),
    correo:el('ed-correo').value.trim(),asesor:asesor,
    id_asesor:ASESORES_MAP[asesor]||'',sede:el('ed-sede').value,
    tipo_atencion:el('ed-tipo-at').value,fecha_cita:fecha,
    hora_cita:el('ed-hora').value||'10:00',tratamiento:el('ed-trat').value,
    tipo_cita:el('ed-tipo-cita').value,estado_cita:el('ed-estado').value||'PENDIENTE',
    obs:el('ed-obs').value.trim(),ts_actualizado:now.toISOString()
  };
  if(AG.editId){
    // UPDATE existente
    fetch(_SB+'/rest/v1/aos_agenda_citas?id=eq.'+AG.editId,{method:'PATCH',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(row)}).then(function(r){
      if(!r.ok)throw new Error('HTTP '+r.status);
      if(window.AOS_showToast)AOS_showToast('Cita actualizada','','');
      agCloseEdit();agLoad();
    }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
  } else {
    // INSERT nueva (desde agenda NO cuenta como llamada)
    row.ts_creado=now.toISOString();
    row.origen_cita='AGENDA';
    fetch(_SB+'/rest/v1/aos_agenda_citas',{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(row)}).then(function(r){
      if(!r.ok)throw new Error('HTTP '+r.status);
      if(window.AOS_showToast)AOS_showToast('Cita creada','Agregada a la agenda','toast-venta');
      agCloseEdit();agLoad();
    }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
  }
}

// Buscar paciente por número
var _agTmr=null;
function agBuscarPac(q){
  clearTimeout(_agTmr);
  var info=el('ed-pac-info');
  if(!q||q.length<6){if(info)info.style.display='none';return;}
  _agTmr=setTimeout(function(){
    _rpc('aos_search_pacientes',{p_query:q,p_limit:3},function(rows){
      if(!rows||!rows.length){if(info)info.style.display='none';return;}
      var num=q.replace(/\D/g,'');
      var match=rows.find(function(p){return(p.telefono||'').replace(/\D/g,'')===num;})||rows[0];
      if(match){
        info.style.display='block';
        info.innerHTML='\u2713 Paciente: '+(match.nombres||'')+' '+(match.apellidos||'');
        if(match.nombres&&!el('ed-nombre').value)el('ed-nombre').value=match.nombres;
        if(match.apellidos&&!el('ed-apellido').value)el('ed-apellido').value=match.apellidos;
        if(match.dni&&!el('ed-dni').value)el('ed-dni').value=match.dni;
        if(match.correo&&!el('ed-correo').value)el('ed-correo').value=match.correo;
      }
    });
  },400);
}
