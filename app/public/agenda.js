// agenda.js v2 — Agenda Global | AscendaOS v1 | 100% Supabase
var _SB='https://ituyqwstonmhnfshnaqz.supabase.co';
var _SK='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';

// ===== EMAIL AUTOMÁTICO AL CREAR/REAGENDAR CITA =====
function enviarEmailConfirmacionCita(d) {
  var correo = (d.correo || '').trim();
  if (!correo || correo.indexOf('@') < 0) return;
  var nombre = ((d.nombre || '') + ' ' + (d.apellido || '')).trim();
  var fechaRaw = d.fecha_cita || '';
  var fechaLabel = fechaRaw;
  try {
    var dp = new Date(fechaRaw + 'T12:00:00');
    var dias = ['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'];
    var meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    fechaLabel = dias[dp.getDay()] + ' ' + dp.getDate() + ' de ' + meses[dp.getMonth()] + ', ' + dp.getFullYear();
  } catch(e) {}
  fetch('https://ascenda-os-production.up.railway.app/api/send-template', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ to: correo, template: 'confirmacion_cita', nombre: nombre, tratamiento: d.tratamiento || 'Consulta', hora: d.hora_cita || '', sede: d.sede || '', fecha: fechaLabel, dni: d.dni || '', telefono: d.numero_limpio || d.numero || '', email: correo })
  }).then(function(r) { return r.json(); }).then(function(res) {
    if (res && (res.ok || res.id)) { if (window.AOS_showToast) AOS_showToast('📧 Email enviado', correo, ''); }
  }).catch(function() {});
}
function _rpc(fn,p,ok,fail){fetch(_SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json'},body:JSON.stringify(p||{})}).then(function(r){return r.json();}).then(ok||function(){}).catch(fail||function(e){console.error('[SB]',fn,e);});}
function _rest(path,opts){return fetch(_SB+'/rest/v1/'+path,Object.assign({headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'}},opts||{}));}
function h(s){var o=String(s||'');o=o.split('&').join('&amp;');o=o.split(String.fromCharCode(60)).join('&lt;');o=o.split('>').join('&gt;');o=o.split('"').join('&quot;');return o;}
function el(id){return document.getElementById(id);}

var DIAS_S=['Dom','Lun','Mar','Mi\u00e9','Jue','Vie','S\u00e1b'];
var DIAS_L=['Domingo','Lunes','Martes','Mi\u00e9rcoles','Jueves','Viernes','S\u00e1bado'];
var MESES=['','Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
var AG={fecha:(function(){var n=new Date();return n.getFullYear()+'-'+String(n.getMonth()+1).padStart(2,'0')+'-'+String(n.getDate()).padStart(2,'0');})(),data:null,sel:null,editId:null,filtro:'',vista:'list'};
var AMAP={'WILMER':'ZIV-004','RUVILA':'ZIV-002','MIREYA':'ZIV-003','SRA CARMEN':'ZIV-005','CESAR':'ZIV-001'};
var ESTADOS=[{val:'PENDIENTE',lbl:'Pendiente',cls:'est-btn-pend'},{val:'CITA CONFIRMADA',lbl:'Confirmada',cls:'est-btn-conf'},{val:'ASISTIO',lbl:'Asisti\u00f3',cls:'est-btn-asist'},{val:'EFECTIVA',lbl:'Efectiva',cls:'est-btn-efect'},{val:'NO ASISTIO',lbl:'No Asisti\u00f3',cls:'est-btn-noasist'},{val:'CANCELADA',lbl:'Cancelada',cls:'est-btn-cancel'}];

(function(){el('ag-fecha').value=AG.fecha;updateLbl();agLoad();})();

function updateLbl(){var d=new Date(AG.fecha+'T12:00:00');el('ag-fecha-lbl').textContent=DIAS_L[d.getDay()]+', '+d.getDate()+' de '+MESES[d.getMonth()+1]+' '+d.getFullYear();}
function agNav(dir){var d=new Date(AG.fecha+'T12:00:00');if(AG.vista==='week')d.setDate(d.getDate()+dir*7);else if(AG.vista==='month')d.setMonth(d.getMonth()+dir);else d.setDate(d.getDate()+dir);AG.fecha=d.toISOString().slice(0,10);el('ag-fecha').value=AG.fecha;updateLbl();agLoad();}
function agHoy(){AG.fecha=(function(){var n=new Date();return n.getFullYear()+'-'+String(n.getMonth()+1).padStart(2,'0')+'-'+String(n.getDate()).padStart(2,'0');})();el('ag-fecha').value=AG.fecha;updateLbl();agLoad();}
function agVista(btn){document.querySelectorAll('.vtab').forEach(function(t){t.classList.remove('act');});btn.classList.add('act');AG.vista=btn.getAttribute('data-v');agLoad();}
function agFilterLocal(){AG.filtro=el('ag-estado').value;if(AG.data)renderView();}

function estCls(e){var u=(e||'').toUpperCase();if(u==='PENDIENTE')return'est-pend';if(u==='CITA CONFIRMADA'||u==='CONFIRMADA')return'est-conf';if(u==='EFECTIVA')return'est-efect';if(u.indexOf('ASISTI')>=0&&u.indexOf('NO')<0)return'est-asist';if(u.indexOf('NO ASIST')>=0)return'est-noasist';if(u==='CANCELADA')return'est-cancel';return'est-pend';}
function atencionLabel(c){if((c.tipo_atencion||'').toUpperCase()==='DOCTORA')return c.doctora||'Doctora';return'Enfermer\u00eda';}

function filterCitas(citas){var f=AG.filtro;if(!f)return citas;return citas.filter(function(c){var e=(c.estado_cita||'').toUpperCase();if(f==='ASISTIO')return e.indexOf('ASISTI')>=0||e==='EFECTIVA';if(f==='NO ASISTIO')return e.indexOf('NO ASIST')>=0;return e===f;});}

function agLoad(){
  AG.fecha=el('ag-fecha').value||AG.fecha;updateLbl();
  if(AG.vista==='week'){loadWeek();return;}
  if(AG.vista==='month'){loadMonth();return;}
  var sede=el('ag-sede').value;
  _rpc('aos_agenda_dia',{p_fecha:AG.fecha,p_sede:sede||'',p_asesor_filtro:''},function(d){
    if(!d)return;AG.data=d;
    renderKPIs(d.resumen||{});renderView();renderTurnos(d.turnos||[]);
  });
  loadTrats();
}
function loadTrats(){
  var sel=el('ed-trat');if(!sel||sel.options.length>2)return;
  _rpc('aos_catalogo_tratamientos',{},function(items){
    if(!items||!items.length)return;
    sel.innerHTML='<option value="">-- Seleccionar --</option>'+items.map(function(i){return '<option value="'+i.t+'">'+i.t+'</option>';}).join('');
  });
}

function renderKPIs(r){el('ag-total').textContent=r.total||0;el('ag-pend').textContent=r.pendiente||0;el('ag-asist').textContent=r.asistio||0;el('ag-noasist').textContent=r.noAsistio||0;el('ag-cancel').textContent=r.cancelada||0;}

function renderView(){
  var citas=filterCitas((AG.data&&AG.data.citas)||[]);
  el('ag-list-count').textContent=citas.length+' cita'+(citas.length!==1?'s':'');
  if(AG.vista==='grid')renderGrid(citas);
  else renderList(citas);
}

function renderList(citas){
  var box=el('ag-content');
  box.innerHTML='<table class="ag-table"><thead><tr><th>Hora</th><th>Paciente</th><th>Tratamiento</th><th>Sede</th><th>Asesor</th><th>Estado</th><th>Atenci\u00f3n</th><th style="width:36px;"></th></tr></thead><tbody id="ag-tbody"></tbody></table>';
  var tb=el('ag-tbody');
  if(!citas.length){tb.innerHTML='<tr><td colspan="8" class="ld">Sin citas</td></tr>';return;}
  tb.innerHTML=citas.map(function(c){
    var cli=((c.nombre||'')+' '+(c.apellido||'')).trim();
    var hora=(c.hora_cita||'').toString().substring(0,5);
    var num=(c.numero_limpio||c.numero||'').replace(/\D/g,'');
    var waBtn=num?'<div onclick="event.stopPropagation();AG.sel=AG.data.citas.find(function(x){return x.id===\''+c.id+'\'});agWhatsApp()" style="cursor:pointer;font-size:16px;width:28px;height:28px;border-radius:50%;background:#25D366;display:flex;align-items:center;justify-content:center;" title="WhatsApp">💬</div>':'';
    return '<tr onclick="agDetalle(\''+h(c.id)+'\')"><td style="font-weight:700;white-space:nowrap;">'+h(hora||'--')+'</td><td><div style="font-weight:700;font-size:11px;">'+h((cli||'--').substring(0,25))+'</div><div style="font-size:9px;color:#9AAAC8;">'+h(c.numero_limpio||c.numero||'')+'</div></td><td style="font-size:10px;">'+h((c.tratamiento||'').substring(0,18))+'</td><td style="font-size:10px;color:#6B7BA8;">'+h((c.sede||'').substring(0,10))+'</td><td style="font-size:10px;">'+h((c.asesor||'').substring(0,10))+'</td><td><span class="est-b '+estCls(c.estado_cita)+'">'+h(c.estado_cita||'')+'</span></td><td style="font-size:10px;color:#6B7BA8;">'+h(atencionLabel(c).substring(0,15))+'</td><td style="text-align:center;" onclick="event.stopPropagation()">'+waBtn+'</td></tr>';
  }).join('');
}

function renderGrid(citas){
  var docs=citas.filter(function(c){return(c.tipo_atencion||'').toUpperCase()==='DOCTORA';});
  var enfs=citas.filter(function(c){return(c.tipo_atencion||'').toUpperCase()!=='DOCTORA';});
  var box=el('ag-content');
  box.innerHTML='<div class="grid-2col"><div><div class="grid-col-hdr grid-col-doc">DOCTORA ('+docs.length+')</div><div id="grid-docs"></div></div><div><div class="grid-col-hdr grid-col-enf">ENFERMER\u00cdA ('+enfs.length+')</div><div id="grid-enfs"></div></div></div>';
  function renderCards(items,containerId){
    var c=document.getElementById(containerId);
    if(!items.length){c.innerHTML='<div class="ld">Sin citas</div>';return;}
    c.innerHTML=items.map(function(ci){
      var cli=((ci.nombre||'')+' '+(ci.apellido||'')).trim();
      return '<div class="grid-card" onclick="agDetalle(\''+h(ci.id)+'\')">'+'<div style="display:flex;justify-content:space-between;"><div class="grid-card-hora">'+h((ci.hora_cita||'').toString().substring(0,5))+'</div><span class="est-b '+estCls(ci.estado_cita)+'">'+h(ci.estado_cita||'')+'</span></div>'+'<div class="grid-card-cli">'+h((cli||'--').substring(0,22))+'</div>'+'<div class="grid-card-meta">'+h(ci.tratamiento||'')+' \u00b7 '+h(ci.asesor||'')+'</div></div>';
    }).join('');
  }
  renderCards(docs,'grid-docs');renderCards(enfs,'grid-enfs');
}

// ── SEMANA ──
function loadWeek(){
  var d=new Date(AG.fecha+'T12:00:00');var day=d.getDay();var diff=d.getDate()-day+(day===0?-6:1);
  var lunes=new Date(d.getFullYear(),d.getMonth(),diff);
  var dias=[];for(var i=0;i<7;i++){var dd=new Date(lunes);dd.setDate(lunes.getDate()+i);dias.push(dd.toISOString().slice(0,10));}
  var hoy=(function(){var n=new Date();return n.getFullYear()+'-'+String(n.getMonth()+1).padStart(2,'0')+'-'+String(n.getDate()).padStart(2,'0');})();
  var sede=el('ag-sede').value;
  // Fetch citas de toda la semana
  var desde=dias[0],hasta=dias[6];
  fetch(_SB+'/rest/v1/aos_agenda_citas?fecha_cita=gte.'+desde+'&fecha_cita=lte.'+hasta+(sede?'&sede=ilike.*'+sede+'*':'')+'&select=id,fecha_cita,hora_cita,nombre,apellido,numero_limpio,tratamiento,estado_cita,asesor,tipo_atencion,doctora&order=hora_cita',{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}}).then(function(r){return r.json();}).then(function(rows){
    var byDay={};dias.forEach(function(d){byDay[d]=[];});
    (rows||[]).forEach(function(c){var f=c.fecha_cita;if(f&&byDay[f])byDay[f].push(c);});
    var total=rows?rows.length:0;el('ag-total').textContent=total;el('ag-list-count').textContent=total+' citas';
    var box=el('ag-content');
    box.innerHTML='<div class="week-grid">'+dias.map(function(fecha){
      var dd=new Date(fecha+'T12:00:00');
      var isToday=fecha===hoy;
      var citasDia=filterCitas(byDay[fecha]||[]);
      return '<div class="week-day'+(isToday?' today':'')+'"><div class="week-day-hdr">'+DIAS_S[dd.getDay()]+' '+dd.getDate()+'</div>'+citasDia.map(function(c){
        var hora=(c.hora_cita||'').toString().substring(0,5);
        var cli=((c.nombre||'')+' '+(c.apellido||'')).trim();
        return '<div class="week-cita" onclick="agDetalle(\''+h(c.id)+'\')">'+h(hora)+' '+h((cli||'').substring(0,12))+'</div>';
      }).join('')+'</div>';
    }).join('')+'</div>';
  });
}

// ── MES ──
function loadMonth(){
  var d=new Date(AG.fecha+'T12:00:00');var anio=d.getFullYear(),mes=d.getMonth();
  var primero=new Date(anio,mes,1);var startDay=primero.getDay();
  var diasMes=new Date(anio,mes+1,0).getDate();
  var desde=anio+'-'+String(mes+1).padStart(2,'0')+'-01';
  var hasta=anio+'-'+String(mes+1).padStart(2,'0')+'-'+diasMes;
  var hoy=(function(){var n=new Date();return n.getFullYear()+'-'+String(n.getMonth()+1).padStart(2,'0')+'-'+String(n.getDate()).padStart(2,'0');})();
  var sede=el('ag-sede').value;
  el('ag-fecha-lbl').textContent=MESES[mes+1]+' '+anio;
  fetch(_SB+'/rest/v1/aos_agenda_citas?fecha_cita=gte.'+desde+'&fecha_cita=lte.'+hasta+(sede?'&sede=ilike.*'+sede+'*':'')+'&select=id,fecha_cita,estado_cita',{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}}).then(function(r){return r.json();}).then(function(rows){
    var byDay={};(rows||[]).forEach(function(c){var f=c.fecha_cita;if(!byDay[f])byDay[f]=[];byDay[f].push(c);});
    el('ag-total').textContent=rows?rows.length:0;
    var cells='';var hdrs=DIAS_S.map(function(d){return '<div class="month-hdr">'+d+'</div>';}).join('');
    // Celdas vacías antes del 1
    var emptyStart=(startDay===0?6:startDay-1);
    for(var e=0;e<emptyStart;e++)cells+='<div class="month-cell other"></div>';
    for(var day=1;day<=diasMes;day++){
      var f=anio+'-'+String(mes+1).padStart(2,'0')+'-'+String(day).padStart(2,'0');
      var isToday=f===hoy;
      var citasDia=byDay[f]||[];
      var dots=citasDia.slice(0,6).map(function(c){
        var e=(c.estado_cita||'').toUpperCase();
        var dc=e==='PENDIENTE'?'dot-pend':e.indexOf('ASIST')>=0&&e.indexOf('NO')<0?'dot-asist':e.indexOf('NO ASIST')>=0?'dot-noasist':e==='CANCELADA'?'dot-cancel':'dot-conf';
        return '<div class="month-dot '+dc+'"></div>';
      }).join('');
      cells+='<div class="month-cell'+(isToday?' today':'')+'" onclick="AG.fecha=\''+f+'\';el(\'ag-fecha\').value=\''+f+'\';agVista(document.querySelector(\'[data-v=list]\'))"><div class="month-num">'+day+'</div><div class="month-dots">'+dots+'</div></div>';
    }
    el('ag-content').innerHTML='<div class="month-grid">'+hdrs+cells+'</div>';
  });
}

function renderTurnos(turnos){
  var box=el('ag-turnos');
  if(!turnos||!turnos.length){box.innerHTML='<div class="ld">Sin turnos</div>';return;}
  box.innerHTML=turnos.map(function(t){var isDoc=(t.rol||'').toUpperCase()==='DOCTORA';return '<div class="turno-card '+(isDoc?'turno-doc':'turno-enf')+'"><div class="turno-nombre">'+h(t.personal)+'</div><div class="turno-meta">'+h(t.rol)+' \u00b7 '+h(t.sede)+' \u00b7 '+h(t.hora_inicio)+'-'+h(t.hora_fin)+'</div></div>';}).join('');
}

// ── MODAL DETALLE ──
function agDetalle(id){
  var citas=[];
  if(AG.data&&AG.data.citas)citas=AG.data.citas;
  var c=citas.find(function(x){return x.id===id;});
  if(!c){
    // Para vistas semana/mes, buscar en Supabase
    fetch(_SB+'/rest/v1/aos_agenda_citas?id=eq.'+id+'&select=*',{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}}).then(function(r){return r.json();}).then(function(rows){if(rows&&rows[0]){AG.sel=rows[0];showDetalle(rows[0]);}});
    return;
  }
  AG.sel=c;showDetalle(c);
}
function showDetalle(c){
  var cli=((c.nombre||'')+' '+(c.apellido||'')).trim();
  el('det-nombre').textContent=cli||'--';
  el('det-sub').textContent=(c.numero_limpio||c.numero||'')+' \u00b7 '+(c.tratamiento||'');
  el('det-info').innerHTML=[['Fecha',c.fecha_cita],['Hora',(c.hora_cita||'').toString().substring(0,5)],['Sede',c.sede],['Tipo',c.tipo_cita],['Tratamiento',c.tratamiento],['Asesor',c.asesor],['Atenci\u00f3n',c.tipo_atencion||''],['Doctora',c.doctora||'Sin asignar']].map(function(r){return '<div class="det-row"><div class="det-lbl">'+r[0]+'</div><div class="det-val">'+h(r[1]||'--')+'</div></div>';}).join('');
  el('det-nota').value=c.obs||'';
  el('det-estados').innerHTML=ESTADOS.map(function(e){return '<div class="est-btn '+e.cls+' '+((c.estado_cita||'').toUpperCase()===e.val?'act':'')+'" data-val="'+e.val+'" onclick="agSelEstado(this)">'+e.lbl+'</div>';}).join('');
  // Cargar historial del paciente
  var num=c.numero_limpio||c.numero||'';
  if(num){
    _rpc('aos_get_historial_paciente',{p_numero:num},function(hist){
      var box=el('det-historial');
      if(!hist||(!hist.llamadas&&!hist.compras&&!hist.citas)){box.innerHTML='<div class="ld">Sin historial</div>';return;}
      var html='';
      if(hist.compras&&hist.compras.length){
        html+='<div class="ml" style="margin-bottom:4px;">Compras ('+hist.compras.length+')</div><div class="hist-mini">';
        html+=hist.compras.map(function(v){return '<div class="hist-item"><b>'+h(v.fecha)+'</b> '+h(v.trat)+' <span style="color:#0A4FBF;font-weight:800;">S/'+parseFloat(v.monto||0).toFixed(0)+'</span></div>';}).join('');
        html+='</div>';
      }
      if(hist.citas&&hist.citas.length){
        html+='<div class="ml" style="margin:8px 0 4px;">Citas ('+hist.citas.length+')</div><div class="hist-mini">';
        html+=hist.citas.map(function(ci){return '<div class="hist-item"><b>'+h(ci.fecha)+'</b> '+h(ci.trat)+' <span class="est-b '+estCls(ci.estado)+'">'+h(ci.estado||'')+'</span></div>';}).join('');
        html+='</div>';
      }
      if(hist.llamadas&&hist.llamadas.length){
        html+='<div class="ml" style="margin:8px 0 4px;">Llamadas ('+hist.llamadas.length+')</div><div class="hist-mini">';
        html+=hist.llamadas.slice(0,5).map(function(l){return '<div class="hist-item"><b>'+h(l.fecha)+'</b> '+h(l.trat)+' <span style="color:#6B7BA8;">'+h(l.estado)+'</span></div>';}).join('');
        html+='</div>';
      }
      box.innerHTML=html||'<div class="ld">Sin historial</div>';
    });
  } else {el('det-historial').innerHTML='<div class="ld">Sin n\u00famero</div>';}
  el('ag-m-det').classList.add('open');
  /* Si ya está ASISTIÓ, mostrar selector de asistente y pre-seleccionar */
  var estActual=(c.estado_cita||'').toUpperCase();
  if(estActual==='ASISTIO'||estActual==='EFECTIVA'){
    var zone=el('det-asistente-zone');
    zone.style.display='block';
    var esDoctora=(c.tipo_atencion||'').toUpperCase().indexOf('DOCTOR')>=0;
    zone.querySelector('.ml').textContent=esDoctora?'Enfermera asistente':'Quién realizará la atención';
    var sel=el('det-asistente');
    sel.innerHTML='<option value="">— Sin asistente —</option>';
    fetch(_SB+'/rest/v1/aos_rrhh?estado=eq.ACTIVO&select=nombre,apellido,puesto&order=nombre',{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}})
    .then(function(r){return r.json()}).then(function(rows){
      (rows||[]).forEach(function(r){
        sel.innerHTML+='<option value="'+h(r.nombre)+'">'+h(r.nombre+(r.apellido?' '+r.apellido:''))+' ('+h(r.puesto||'')+')</option>';
      });
      /* Pre-seleccionar el profesional guardado en la atención */
      var numP=c.numero_limpio||c.numero||'';
      if(numP){
        fetch(_SB+'/rest/v1/aos_atenciones?numero_limpio=eq.'+numP+'&fecha=eq.'+c.fecha_cita+'&select=profesional_nombre,asistente_nombre&limit=1',{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}})
        .then(function(r2){return r2.json()}).then(function(at){
          if(at&&at[0]){
            var guardado=esDoctora?(at[0].asistente_nombre||''):(at[0].profesional_nombre||'');
            if(guardado){for(var i=0;i<sel.options.length;i++){if(sel.options[i].value===guardado){sel.selectedIndex=i;break;}}}
          }
        });
      }
    });
  } else {
    var zone=el('det-asistente-zone');if(zone)zone.style.display='none';
  }
}
function agCloseDet(){el('ag-m-det').classList.remove('open');}

// ═══ WHATSAPP — PLANTILLAS INTELIGENTES ═══
var _waMsg = '';
var _waNum = '';

var WA_SEDES = {
  'SAN ISIDRO': { dir: 'Av. Javier Prado Este 996 - Ofi 501 - Lima · Edificio Capricornio', maps: 'https://maps.app.goo.gl/co7ch54zHCt1Nj6w5', ref: '',
    estac: '🚗 Estacionamiento:\n✅ Frente al Edificio Capricornio\n✅ Gratuito (máx 3h) — Av. Aux. Rep. de Panamá\n✅ Los Portales — C. Ricardo Angulo 197\n✅ C.C. Santa Catalina — Av. Carlos Villarán 500',
    taxi: '🚖 Taxi: Buscar Av. Javier Prado Este 996, San Isidro\n⚠️ YANGO: usar Av Pablo Carriquiry 106, San Isidro' },
  'PUEBLO LIBRE': { dir: 'Av. Brasil 1170, Pueblo Libre - Lima', maps: 'https://goo.gl/maps/Cw36T6YPudyRNmVe6', ref: 'A 4 cuadras de la Rambla',
    estac: '🚗 Estacionamiento:\n✅ Frente a fachada (según hora)\n✅ Univ. Alas Peruanas — Jr. Pedro Ruiz Gallo 251\n✅ C.E.P. Santa María — Jr. Pedro Ruiz Gallo 137\n✅ Playa Otorcuna — JP Fernandini 1255',
    taxi: '🚖 Taxi: Buscar Av. Brasil 1170 - Pueblo Libre o ZI VITAL' }
};

function fmtFechaWA(fechaStr) {
  try {
    var d = new Date(fechaStr + 'T12:00:00');
    var dias = ['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'];
    var meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    return dias[d.getDay()] + ' ' + d.getDate() + ' de ' + meses[d.getMonth()];
  } catch(e) { return fechaStr; }
}

function agWhatsApp() {
  var c = AG.sel;
  if (!c) return;
  var num = (c.numero_limpio || c.numero || '').replace(/\D/g, '');
  if (!num) { if(window.AOS_showToast) AOS_showToast('Sin número', '', 'toast-alerta'); return; }
  _waNum = num;
  var cli = ((c.nombre || '') + ' ' + (c.apellido || '')).trim();
  var sede = WA_SEDES[(c.sede || '').toUpperCase()] || WA_SEDES['SAN ISIDRO'];
  var fechaLabel = fmtFechaWA(c.fecha_cita);
  var hora = (c.hora_cita || '').toString().substring(0, 5);
  var trat = c.tratamiento || 'Consulta';

  el('wa-paciente').textContent = cli + ' · ' + num;

  // Detectar contexto: ¿es cita de hoy, mañana, o futuro?
  var hoy = new Date(Date.now() + (-5*60)*60000).toISOString().split('T')[0];
  var manana = new Date(Date.now() + (-5*60)*60000 + 86400000).toISOString().split('T')[0];
  var esSab = new Date(Date.now() + (-5*60)*60000).getDay() === 6;
  var lunes = new Date(Date.now() + (-5*60)*60000 + 2*86400000).toISOString().split('T')[0];

  var esHoy = c.fecha_cita === hoy;
  var esManana = c.fecha_cita === manana || (esSab && c.fecha_cita === lunes);

  // Plantillas con datos del paciente
  var plantillas = [];

  // RECOMENDADA según contexto
  var recomendada = null;
  if (esManana) {
    recomendada = { nombre: '⏰ Confirmación de cita MAÑANA', recomendado: true,
      msg: '¡Hola! Te saluda tu Asesora de salud de Zi Vital 🏥👩‍⚕️\n\nTe recordamos que mañana tienes tu cita:\n\n📌 *CITA CONFIRMADA*\nNombre: ' + cli + '\nDía: ' + fechaLabel + '\nHora: ' + hora + '\nServicio: ' + trat + '\nSede: *' + (c.sede || '') + '*\n\n📍 ' + sede.dir + '\n' + sede.maps + '\n\nLlegar 15 minutos antes ⏱️ con DNI\n\n' + sede.estac + '\n\n' + sede.taxi + '\n\n¡TE ESPERAMOS! 🤗' };
  } else if (esHoy) {
    recomendada = { nombre: '☀️ Recordatorio cita HOY', recomendado: true,
      msg: '¡Buenos días! ☀️ Te recordamos que HOY tienes tu cita en Zi Vital\n\n📌 *TU CITA DE HOY*\nServicio: ' + trat + '\nHora: ' + hora + '\nSede: *' + (c.sede || '') + '*\n\n📍 ' + sede.dir + '\n' + sede.maps + '\n\nLlegar 15 min antes ⏱️ con DNI\n\n¡Te esperamos! 🤗' };
  } else {
    recomendada = { nombre: '✅ Confirmación de cita', recomendado: true,
      msg: '¡Hola! Te saluda tu Asesora de salud de Zi Vital 🏥👩‍⚕️\nAquí te envío tu confirmación de cita ♥\n\n📌 *CITA CONFIRMADA*\nNombre: ' + cli + '\nDNI: ' + (c.dni || '') + '\nDía: ' + fechaLabel + '\nHora: ' + hora + '\nServicio: ' + trat + '\nSede: *' + (c.sede || '') + '*\n\n📍 ' + sede.dir + '\n' + (sede.ref ? sede.ref + '\n' : '') + sede.maps + '\n\nLlegar 15 minutos antes ⏱️ con DNI\n\n' + sede.estac + '\n\n' + sede.taxi + '\n\n📱 Agréganos como ZI VITAL para recordatorios\n\n✔️ La consulta es personalizada. Puede haber tiempo de espera.\n\n¡TE ESPERAMOS! 🤗' };
  }

  // Otras plantillas
  var otrasPlantillas = [
    { nombre: '🔄 Reprogramación', msg: '¡Hola ' + (c.nombre || '').split(' ')[0] + '! Tu cita de ' + trat + ' ha sido reprogramada para el ' + fechaLabel + ' a las ' + hora + ' en ' + (c.sede || '') + '.\n\n📍 ' + sede.dir + '\n' + sede.maps + '\n\nSi necesitas cambiar, avísanos. ¡Te esperamos! 🤗' },
    { nombre: '📍 Solo dirección y estacionamiento', msg: '📍 Sede ' + (c.sede || '') + '\n' + sede.dir + '\n' + sede.maps + '\n\n' + sede.estac + '\n\n' + sede.taxi },
    { nombre: '💬 Mensaje libre', msg: '¡Hola ' + (c.nombre || '').split(' ')[0] + '! ' }
  ];

  // Render recomendada
  el('wa-recomendado').innerHTML = '<div style="font-size:10px;font-weight:700;color:#059669;text-transform:uppercase;margin-bottom:6px;">⭐ Recomendado</div>' +
    '<div style="padding:12px;background:#F0FDF4;border-radius:10px;border:2px solid #059669;cursor:pointer;" onclick="waSelect(0)">' +
    '<div style="font-weight:700;font-size:12px;color:#059669;">' + recomendada.nombre + '</div>' +
    '<div style="font-size:9px;color:#6B7BA8;margin-top:2px;">Click para seleccionar y previsualizar</div></div>';

  // Render saldos/pendientes
  _rpc('aos_get_historial_paciente', { p_numero: num }, function(hist) {
    var saldoHtml = '';
    if (hist && hist.compras && hist.compras.length) {
      var pendientes = hist.compras.filter(function(v) { return parseFloat(v.saldo || 0) > 0; });
      if (pendientes.length) {
        var saldoTotal = pendientes.reduce(function(s, v) { return s + parseFloat(v.saldo || 0); }, 0);
        var detalle = pendientes.map(function(v) { return '• ' + (v.trat || '') + ' — Saldo: S/' + parseFloat(v.saldo).toFixed(2); }).join('\n');
        otrasPlantillas.splice(1, 0, {
          nombre: '💰 Recordatorio saldos pendientes (S/' + saldoTotal.toFixed(0) + ')',
          msg: '¡Hola ' + (c.nombre || '').split(' ')[0] + '! Te recordamos que tienes saldos pendientes:\n\n' + detalle + '\n\nTotal pendiente: *S/' + saldoTotal.toFixed(2) + '*\n\nPuedes acercarte a cualquiera de nuestras sedes para completar tu pago. ¡Te esperamos! 🤗'
        });
      }
    }
    // Render otras
    el('wa-otras').innerHTML = otrasPlantillas.map(function(p, i) {
      return '<div style="padding:8px 12px;border:1px solid #EEF0F8;border-radius:8px;margin-bottom:4px;cursor:pointer;transition:background .15s;" onmouseover="this.style.background=\'#F8FAFF\'" onmouseout="this.style.background=\'#fff\'" onclick="waSelect(' + (i + 1) + ')">' +
        '<div style="font-weight:600;font-size:11px;">' + p.nombre + '</div></div>';
    }).join('');
    // Guardar todas
    window._waPlantillas = [recomendada].concat(otrasPlantillas);
  });

  // Abrir modal
  _waMsg = '';
  el('wa-preview').textContent = 'Selecciona una plantilla...';
  el('wa-btn-send').disabled = true;
  el('ag-m-wa').classList.add('open');
}

function waSelect(idx) {
  var p = window._waPlantillas && window._waPlantillas[idx];
  if (!p) return;
  _waMsg = p.msg;
  el('wa-preview').textContent = p.msg;
  el('wa-btn-send').disabled = false;
  // Highlight seleccionada
  var cards = el('wa-otras').querySelectorAll('div[onclick]');
  cards.forEach(function(c) { c.style.borderColor = '#EEF0F8'; c.style.background = '#fff'; });
  if (idx > 0 && cards[idx - 1]) { cards[idx - 1].style.borderColor = '#0A4FBF'; cards[idx - 1].style.background = '#F0F4FC'; }
  if (idx === 0) el('wa-recomendado').querySelector('div[onclick]').style.borderColor = '#059669';
}

function waEnviar() {
  if (!_waMsg || !_waNum) return;
  var encoded = encodeURIComponent(_waMsg);
  var waUrl = 'https://api.whatsapp.com/send?phone=51' + _waNum + '&text=' + encoded;
  // En móvil usar location para que abra la app de WhatsApp
  var isMobile = /Android|iPhone|iPad/i.test(navigator.userAgent);
  if (isMobile) {
    window.location.href = waUrl;
  } else {
    window.open(waUrl, '_blank');
  }
  el('ag-m-wa').classList.remove('open');
  if (window.AOS_showToast) AOS_showToast('WhatsApp abierto', 'Envía el mensaje', '');
}
function agSelEstado(btn){
  el('det-estados').querySelectorAll('.est-btn').forEach(function(b){b.classList.remove('act');});
  btn.classList.add('act');
  var est=btn.getAttribute('data-val');
  var zone=el('det-asistente-zone');
  if(est==='ASISTIO'||est==='EFECTIVA'){
    zone.style.display='block';
    var c=AG.sel||{};
    var esDoctora=(c.tipo_atencion||'').toUpperCase().indexOf('DOCTOR')>=0;
    var labelTxt=esDoctora?'Enfermera asistente':'Quién realizará la atención';
    zone.querySelector('.ml').textContent=labelTxt;
    /* Cargar personal */
    var sel=el('det-asistente');
    if(!sel.options.length||sel.options.length<=1){
      sel.innerHTML='<option value="">— Sin asistente —</option>';
      fetch(_SB+'/rest/v1/aos_rrhh?estado=eq.ACTIVO&select=nombre,apellido,puesto&order=nombre',{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}})
      .then(function(r){return r.json()}).then(function(rows){
        (rows||[]).forEach(function(r){
          sel.innerHTML+='<option value="'+h(r.nombre)+'">'+h(r.nombre+(r.apellido?' '+r.apellido:''))+' ('+h(r.puesto||'')+')</option>';
        });
      });
    }
  }else{zone.style.display='none';}
}

function agGuardarEstado(){
  if(!AG.sel)return;
  var est='';el('det-estados').querySelectorAll('.est-btn.act').forEach(function(b){est=b.getAttribute('data-val');});
  var nota=el('det-nota').value.trim();
  var asistente=(el('det-asistente')||{}).value||'';
  var upd={estado_cita:est,ts_actualizado:new Date().toISOString()};
  if(nota!==(AG.sel.obs||''))upd.obs=nota;
  _rest('aos_agenda_citas?id=eq.'+AG.sel.id,{method:'PATCH',body:JSON.stringify(upd)}).then(function(r){
    if(!r.ok)throw new Error('HTTP '+r.status);
    if(window.AOS_showToast)AOS_showToast('Estado actualizado',est,'');
    
    /* ===== CREAR/ACTUALIZAR ATENCIÓN al marcar ASISTIÓ o EFECTIVA ===== */
    if(est==='ASISTIO'||est==='EFECTIVA'){
      var c=AG.sel;
      var esDoctora=(c.tipo_atencion||'').toUpperCase().indexOf('DOCTOR')>=0;
      var profNombre, profTipo, asistNombre;
      
      if(esDoctora){
        profNombre = c.doctora || '';
        if(!profNombre || profNombre==='Sin asignar')profNombre='';
        profTipo = 'DOCTORA';
        asistNombre = asistente || '';
      } else {
        profNombre = asistente || c.asesor || '';
        if(profNombre==='--'||profNombre==='No aplica')profNombre='';
        profTipo = 'ENFERMERIA';
        asistNombre = '';
      }
      
      /* Si no hay profesional principal pero sí asistente, usar asistente */
      if(!profNombre && asistNombre){
        profNombre = asistNombre;
        profTipo = 'ENFERMERIA';
      }
      
      if(!profNombre){
        if(window.AOS_showToast)AOS_showToast('⚠️ Selecciona quién atenderá','Elige un profesional del selector','toast-alerta');
        return;
      }
      
      var atencion={
        numero_limpio:c.numero_limpio||c.numero||'',
        fecha:c.fecha_cita,
        sede:c.sede||'SAN ISIDRO',
        profesional_id:'',
        profesional_nombre:profNombre,
        profesional_tipo:profTipo,
        asistente_id:'',
        asistente_nombre:asistNombre,
        estado:'PENDIENTE',
        paciente_nombre:((c.nombre||'')+' '+(c.apellido||'')).trim(),
        paciente_telefono:c.numero_limpio||c.numero||'',
        cita_id:c.id,
        tratamiento_principal:c.tratamiento||'',
        tipo_atencion:'CONSULTA',
        observaciones:nota
      };
      
      /* Buscar por numero_limpio + fecha (SIN filtrar por profesional) */
      fetch(_SB+'/rest/v1/aos_atenciones?numero_limpio=eq.'+atencion.numero_limpio+'&fecha=eq.'+atencion.fecha+'&select=id,profesional_nombre',{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}})
      .then(function(r){return r.json()}).then(function(existing){
        if(existing&&existing.length>0){
          /* Ya existe → ACTUALIZAR profesional y datos (no crear nueva) */
          var existId=existing[0].id;
          fetch(_SB+'/rest/v1/aos_atenciones?id=eq.'+existId,{
            method:'PATCH',
            headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},
            body:JSON.stringify({
              profesional_nombre:profNombre,
              profesional_tipo:profTipo,
              asistente_nombre:asistNombre,
              estado:'PENDIENTE',
              updated_at:new Date().toISOString()
            })
          }).then(function(r2){
            if(r2.ok){
              if(window.AOS_showToast)AOS_showToast('✅ Atención actualizada','Profesional: '+profNombre+(asistNombre?' · Asiste: '+asistNombre:''),'');
            }
          });
          return;
        }
        /* No existe → Crear nueva */
        fetch(_SB+'/rest/v1/aos_atenciones',{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify(atencion)})
        .then(function(r2){
          if(r2.ok){
            if(window.AOS_showToast)AOS_showToast('✅ Atención creada','Profesional: '+profNombre+(asistNombre?' · Asiste: '+asistNombre:''),'');
          }else{
            r2.text().then(function(t){console.error('[AGENDA] Error creando atención:',t);});
          }
        });
      });
    }
    
    /* ===== ELIMINAR ATENCIÓN al volver a PENDIENTE o CONFIRMADA ===== */
    if(est==='PENDIENTE'||est==='CITA CONFIRMADA'){
      var cSel=AG.sel;
      var numLimpio=cSel.numero_limpio||cSel.numero||'';
      if(numLimpio){
        fetch(_SB+'/rest/v1/aos_atenciones?numero_limpio=eq.'+numLimpio+'&fecha=eq.'+cSel.fecha_cita+'&select=id',{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}})
        .then(function(r){return r.json()}).then(function(existing){
          if(existing&&existing.length>0){
            /* Verificar que no tenga notas clínicas (si ya se registró algo, no eliminar) */
            fetch(_SB+'/rest/v1/aos_notas_clinicas?numero_limpio=eq.'+numLimpio+'&fecha=eq.'+cSel.fecha_cita+'&select=id&limit=1',{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}})
            .then(function(r2){return r2.json()}).then(function(notas){
              if(notas&&notas.length>0){
                if(window.AOS_showToast)AOS_showToast('⚠️ Atención conservada','Ya tiene notas clínicas registradas','toast-alerta');
              }else{
                /* Sin notas → eliminar atención */
                existing.forEach(function(ex){
                  fetch(_SB+'/rest/v1/aos_atenciones?id=eq.'+ex.id,{method:'DELETE',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}});
                });
                if(window.AOS_showToast)AOS_showToast('🗑 Atención eliminada','Se eliminó la atención pendiente','');
              }
            });
          }
        });
      }
    }
    
    // Si marcó NO ASISTIÓ → enviar email reagendamiento
    if(est==='NO ASISTIO'){
      var numPac = (AG.sel.numero||AG.sel.telefono||'').replace(/\D/g,'');
      if(numPac){
        fetch(_SB+'/rest/v1/aos_pacientes?select=Email,nombres&numero_limpio=eq.'+numPac,{headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}})
        .then(function(r){return r.json()}).then(function(pacs){
          var pac=pacs&&pacs[0];
          if(pac&&pac.Email){
            fetch('https://ascenda-os-production.up.railway.app/api/send-template',{
              method:'POST',headers:{'Content-Type':'application/json'},
              body:JSON.stringify({
                to:pac.Email,
                template:'no_asistencia',
                nombre:pac.nombres||AG.sel.paciente||'',
                tratamiento:AG.sel.tratamiento||'',
                sede:AG.sel.sede||'',
                fecha:AG.sel.fecha||''
              })
            }).then(function(r){return r.json()}).then(function(res){
              if(res&&(res.ok||res.id)){if(window.AOS_showToast)AOS_showToast('📧 Email de reagendamiento enviado','','');}
            }).catch(function(){});
          }
        }).catch(function(){});
      }
    }
    
    agCloseDet();agLoad();
  }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
}

var _confirmCb=null;
function agConfirmResp(ok){
  el('ag-m-confirm').classList.remove('open');
  if(ok&&_confirmCb)_confirmCb();
  _confirmCb=null;
}
function agShowConfirm(titulo,msg,btnText,btnCls,cb){
  el('confirm-titulo').textContent=titulo;
  el('confirm-msg').textContent=msg;
  var btn=el('confirm-btn');btn.textContent=btnText;btn.className='mconf '+(btnCls||'red');
  _confirmCb=cb;
  el('ag-m-confirm').classList.add('open');
}

function agEliminar(){
  if(!AG.sel)return;
  var cli=((AG.sel.nombre||'')+' '+(AG.sel.apellido||'')).trim();
  var numP=AG.sel.numero_limpio||AG.sel.numero||'';
  var fechaC=AG.sel.fecha_cita;
  agShowConfirm(
    'Eliminar cita',
    'Se eliminar\u00e1 la cita de '+cli+' del '+(fechaC||'')+'. También se eliminará la atención, notas clínicas y planes de trabajo asociados a esta fecha.',
    'S\u00ed, eliminar todo',
    'red',
    function(){
      _rest('aos_agenda_citas?id=eq.'+AG.sel.id,{method:'DELETE'}).then(function(r){
        if(!r.ok)throw new Error('HTTP '+r.status);
        /* Limpiar todo lo asociado a este paciente+fecha */
        if(numP&&fechaC){
          fetch(_SB+'/rest/v1/aos_atenciones?numero_limpio=eq.'+numP+'&fecha=eq.'+fechaC,{method:'DELETE',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}});
          fetch(_SB+'/rest/v1/aos_notas_clinicas?numero_limpio=eq.'+numP+'&fecha=eq.'+fechaC,{method:'DELETE',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}});
          fetch(_SB+'/rest/v1/aos_plan_trabajo_items?numero_limpio=eq.'+numP+'&fecha=eq.'+fechaC,{method:'DELETE',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}});
          fetch(_SB+'/rest/v1/aos_planes_trabajo?numero_limpio=eq.'+numP+'&fecha=eq.'+fechaC,{method:'DELETE',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}});
        }
        if(window.AOS_showToast)AOS_showToast('Cita eliminada','Atención y notas también eliminadas','');agCloseDet();agLoad();
      }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
    }
  );
}

function agReagendar(){
  if(!AG.sel)return;
  AG.reagendando=true;
  AG.reagendaOrigId=AG.sel.id;
  agAbrirEditar();
  el('edit-titulo').textContent='Reagendar cita';
  el('ed-fecha').value='';el('ed-fecha').focus();
}

// ── MODAL EDITAR / NUEVA ──
function agAbrirEditar(){
  var c=AG.sel;
  if(c){
    el('edit-titulo').textContent='Editar cita';el('edit-sub').textContent='N\u00famero: '+(c.numero_limpio||c.numero||'');
    el('ed-nombre').value=c.nombre||'';el('ed-apellido').value=c.apellido||'';
    el('ed-num').value=c.numero_limpio||c.numero||'';el('ed-dni').value=c.dni||'';
    el('ed-correo').value=c.correo||'';el('ed-asesor').value=c.asesor||'';
    el('ed-sede').value=c.sede||'';el('ed-tipo-at').value=c.tipo_atencion||'';
    el('ed-fecha').value=c.fecha_cita||'';el('ed-hora').value=(c.hora_cita||'').toString().substring(0,5)||'10:00';
    el('ed-trat').value=c.tratamiento||'';el('ed-tipo-cita').value=c.tipo_cita||'CONSULTA NUEVA';
    el('ed-estado').value=c.estado_cita||'PENDIENTE';el('ed-obs').value=c.obs||'';
    AG.editId=c.id;
  }
  agCloseDet();el('ag-m-edit').classList.add('open');
}
function agAbrirNueva(){
  AG.sel=null;AG.editId=null;
  el('edit-titulo').textContent='Nueva cita';el('edit-sub').textContent='';
  ['ed-nombre','ed-apellido','ed-num','ed-dni','ed-correo','ed-obs'].forEach(function(id){el(id).value='';});
  el('ed-sede').value='';el('ed-tipo-at').value='';el('ed-fecha').value=AG.fecha;
  el('ed-hora').value='10:00';el('ed-trat').value='';el('ed-tipo-cita').value='CONSULTA NUEVA';
  el('ed-estado').value='PENDIENTE';el('ed-pac-info').style.display='none';var sr=el('ed-search-results');if(sr)sr.innerHTML='';var sb=el('ed-buscar');if(sb)sb.value='';
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  el('ed-asesor').value=(ctx.asesor||'WILMER').toUpperCase();
  el('ag-m-edit').classList.add('open');
}
function agCloseEdit(){el('ag-m-edit').classList.remove('open');AG.reagendando=false;AG.reagendaOrigId=null;}

function agGuardarEdit(){
  var num=(el('ed-num').value||'').trim().replace(/\D/g,'');
  var fecha=el('ed-fecha').value;
  if(!fecha){alert('Selecciona fecha');return;}
  var asesor=el('ed-asesor').value;var now=new Date();
  var row={nombre:el('ed-nombre').value.trim(),apellido:el('ed-apellido').value.trim(),numero:num,numero_limpio:num,dni:el('ed-dni').value.trim(),correo:el('ed-correo').value.trim(),asesor:asesor,id_asesor:AMAP[asesor]||'',sede:el('ed-sede').value,tipo_atencion:el('ed-tipo-at').value,fecha_cita:fecha,hora_cita:el('ed-hora').value||'10:00',tratamiento:el('ed-trat').value,tipo_cita:el('ed-tipo-cita').value,estado_cita:el('ed-estado').value||'PENDIENTE',obs:el('ed-obs').value.trim(),ts_actualizado:now.toISOString()};
  if(AG.reagendando && AG.reagendaOrigId){
    // REAGENDAR: marcar original como REAGENDADA + crear nueva cita
    var origPatch={estado_cita:'REAGENDADA',obs:(el('ed-obs').value.trim()?el('ed-obs').value.trim()+' | ':'')+'Reagendada a '+fecha,ts_actualizado:now.toISOString()};
    row.ts_creado=now.toISOString();row.origen_cita='REAGENDADA';row.estado_cita='PENDIENTE';
    Promise.all([
      _rest('aos_agenda_citas?id=eq.'+AG.reagendaOrigId,{method:'PATCH',body:JSON.stringify(origPatch)}),
      _rest('aos_agenda_citas',{method:'POST',body:JSON.stringify(row)})
    ]).then(function(results){
      var allOk=results.every(function(r){return r.ok;});
      if(!allOk)throw new Error('Error al reagendar');
      AG.reagendando=false;AG.reagendaOrigId=null;
      enviarEmailConfirmacionCita(row);
      if(window.AOS_showToast)AOS_showToast('Cita reagendada','Original marcada + nueva creada en '+fecha,'toast-venta');agCloseEdit();agLoad();
    }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
  } else if(AG.editId){
    _rest('aos_agenda_citas?id=eq.'+AG.editId,{method:'PATCH',body:JSON.stringify(row)}).then(function(r){
      if(!r.ok)throw new Error('HTTP '+r.status);
      if(window.AOS_showToast)AOS_showToast('Cita actualizada','','');agCloseEdit();agLoad();
    }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
  } else {
    row.ts_creado=now.toISOString();row.origen_cita='AGENDA';
    _rest('aos_agenda_citas',{method:'POST',body:JSON.stringify(row)}).then(function(r){
      if(!r.ok)throw new Error('HTTP '+r.status);
      enviarEmailConfirmacionCita(row);
      if(window.AOS_showToast)AOS_showToast('Cita creada','','toast-venta');agCloseEdit();agLoad();
    }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
  }
}

var _agTmr=null;
function agBuscarPac(q){
  clearTimeout(_agTmr);
  var res=el('ed-search-results');var info=el('ed-pac-info');
  if(!q||q.length<3){if(res)res.innerHTML='';if(info)info.style.display='none';return;}
  if(res)res.innerHTML='<div style="font-size:10px;color:#9AAAC8;padding:4px;">Buscando...</div>';
  _agTmr=setTimeout(function(){
    _rpc('aos_search_pacientes',{p_query:q,p_limit:5},function(rows){
      if(!rows||!rows.length){if(res)res.innerHTML='<div style="font-size:10px;color:#D97706;padding:4px;">Sin resultados</div>';return;}
      if(res)res.innerHTML=rows.map(function(p){
        var nom=((p.nombres||'')+' '+(p.apellidos||'')).trim();
        var tel=p.telefono||'';
        return '<div style="padding:6px 8px;background:#F0F4FC;border:1px solid #DDE4F5;border-radius:7px;margin-bottom:3px;cursor:pointer;display:flex;justify-content:space-between;align-items:center;" onclick="agSelPac(this)" data-nom="'+h(p.nombres||'')+'" data-ape="'+h(p.apellidos||'')+'" data-tel="'+h(tel)+'" data-dni="'+h(p.dni||'')+'" data-correo="'+h(p.correo||'')+'">'
          +'<div><div style="font-size:11px;font-weight:700;color:#0D1B3E;">'+h(nom)+'</div>'
          +'<div style="font-size:9px;color:#9AAAC8;">'+h(tel)+(p.dni?' \u00b7 DNI: '+h(p.dni):'')+'</div></div>'
          +'<div style="font-size:9px;color:#0A4FBF;font-weight:700;">Seleccionar</div></div>';
      }).join('');
    });
  },350);
}

function agSelPac(el2){
  el('ed-nombre').value=el2.getAttribute('data-nom')||'';
  el('ed-apellido').value=el2.getAttribute('data-ape')||'';
  el('ed-num').value=el2.getAttribute('data-tel')||'';
  el('ed-dni').value=el2.getAttribute('data-dni')||'';
  el('ed-correo').value=el2.getAttribute('data-correo')||'';
  var res=el('ed-search-results');if(res)res.innerHTML='';
  var info=el('ed-pac-info');
  if(info){info.style.display='block';info.innerHTML='\u2713 Paciente seleccionado: '+el2.getAttribute('data-nom')+' '+el2.getAttribute('data-ape');}
}
