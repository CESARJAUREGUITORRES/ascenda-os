// citas.js — Mis Citas | AscendaOS v1 | 100% Supabase
var _SB='https://ituyqwstonmhnfshnaqz.supabase.co';
var _SK='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';
function _rpc(fn,p,ok,fail){fetch(_SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json'},body:JSON.stringify(p||{})}).then(function(r){return r.json();}).then(ok||function(){}).catch(fail||function(e){console.error('[SB]',fn,e);});}
function h(s){var o=String(s||'');o=o.split('&').join('&amp;');o=o.split(String.fromCharCode(60)).join('&lt;');o=o.split('>').join('&gt;');o=o.split('"').join('&quot;');return o;}
function el(id){return document.getElementById(id);}

var VC={mes:new Date().getMonth()+1, anio:new Date().getFullYear(), data:null, filtro:'all', busqueda:''};

(function(){
  el('vc-mes').value=String(VC.mes);
  el('vc-anio').value=String(VC.anio);
  vcReload();
})();

function vcReload(){
  VC.mes=Number(el('vc-mes').value);
  VC.anio=Number(el('vc-anio').value);
  VC.filtro='all';
  document.querySelectorAll('.ftab').forEach(function(t){t.classList.toggle('act',t.getAttribute('data-f')==='all');});
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  var nom=(ctx.asesor||'').toUpperCase();
  var idAs=ctx.idAsesor||'';
  if(!nom){el('vc-total').textContent='Sin sesion';return;}
  _rpc('aos_citas_asesor',{p_asesor:nom,p_id_asesor:idAs,p_mes:VC.mes,p_anio:VC.anio},function(d){
    if(!d){el('vc-total').textContent='Error';return;}
    VC.data=d;
    renderKPIs(d);
    renderDetalle(d.detalle||[],'all');
    renderSedes(d.porSede||[]);
    renderTrats(d.porTratamiento||[]);
    renderEstados(d.porEstado||[]);
  });
}

function renderKPIs(d){
  el('vc-total').textContent=d.total||0;
  el('vc-pend').textContent=d.pendientes||0;
  el('vc-asist').textContent=d.asistio||0;
  el('vc-pct').textContent=(d.pctAsistencia||0)+'% asistencia';
  el('vc-noasist').textContent=d.noAsistio||0;
  el('vc-cancel').textContent=d.canceladas||0;
}

function estCls(e){
  var u=(e||'').toUpperCase();
  if(u==='PENDIENTE')return 'est-pend';
  if(u==='CONFIRMADA')return 'est-asist';
  if(u.indexOf('ASISTI')>=0&&u.indexOf('NO')<0)return 'est-asist';
  if(u.indexOf('NO ASISTI')>=0||u==='NO ASISTIO')return 'est-noasist';
  if(u==='CANCELADA')return 'est-cancel';
  return 'est-pend';
}

function renderDetalle(rows, filtro){
  var q=VC.busqueda.toLowerCase();
  var filtered=rows.filter(function(r){
    var eMatch=filtro==='all'?true:(function(){var e=(r.estado_cita||'').toUpperCase();var f=filtro.toUpperCase();if(f==='ASISTIO')return e.indexOf('ASISTI')>=0&&e.indexOf('NO')<0;if(f==='NO ASISTIO')return e.indexOf('NO ASISTI')>=0||e==='NO ASISTIO';return e===f;})();
    if(!eMatch)return false;
    if(!q)return true;
    var cli=((r.nombre||'')+' '+(r.apellido||'')).toLowerCase();
    var num=(r.numero_limpio||r.numero||'').toLowerCase();
    return cli.indexOf(q)>=0||num.indexOf(q)>=0;
  });
  var tb=el('vc-tbody');
  if(!filtered.length){tb.innerHTML='<tr><td colspan="7" class="ld">Sin citas</td></tr>';return;}
  tb.innerHTML=filtered.map(function(c,i){
    var cli=((c.nombre||'')+' '+(c.apellido||'')).trim();
    var hora=(c.hora_cita||'').toString().substring(0,5);
    var cls=estCls(c.estado_cita);
    return '<tr style="cursor:pointer;" onclick="vcAbrirCita('+i+')"><td style="white-space:nowrap;color:#6B7BA8;">'+h(c.fecha_cita||'')+'</td>'+
      '<td style="font-weight:700;color:#0D1B3E;">'+h(hora||'--')+'</td>'+
      '<td><div style="font-weight:700;font-size:11px;">'+h((cli||'--').substring(0,22))+'</div>'+
      '<div style="font-size:9px;color:#9AAAC8;">'+h(c.numero_limpio||c.numero||'')+'</div></td>'+
      '<td style="font-size:10px;">'+h((c.tratamiento||'').substring(0,18))+'</td>'+
      '<td style="font-size:10px;color:#6B7BA8;">'+h((c.sede||'').substring(0,8))+'</td>'+
      '<td><span class="est-b '+cls+'">'+h(c.estado_cita||'')+'</span></td>'+
      '<td style="font-size:10px;color:#6B7BA8;">'+h((c.doctora||'').substring(0,15))+'</td></tr>';
  }).join('');
  VC._filtered=filtered;
}

function vcBuscar(){
  VC.busqueda=(el('vc-buscar')||{}).value||'';
  if(VC.data)renderDetalle(VC.data.detalle||[], VC.filtro);
}

function vcFilter(btn){
  document.querySelectorAll('.ftab').forEach(function(t){t.classList.remove('act');});
  btn.classList.add('act');
  VC.filtro=btn.getAttribute('data-f');
  if(VC.data)renderDetalle(VC.data.detalle||[], VC.filtro);
}

function renderBars(items, containerId, maxVal, color){
  var box=el(containerId);
  if(!items||!items.length){box.innerHTML='<div class="ld">Sin datos</div>';return;}
  var mx=maxVal||Math.max.apply(null,items.map(function(i){return i.n||0;}));
  box.innerHTML=items.map(function(i){
    var pct=mx>0?Math.round((i.n||0)/mx*100):0;
    return '<div class="bar-row"><div class="bar-lbl">'+h(i.sede||i.tratamiento||i.estado||'--')+'</div>'+
      '<div class="bar-track"><div class="bar-fill" style="width:'+pct+'%;background:'+(color||'#0A4FBF')+';"></div></div>'+
      '<div class="bar-n">'+(i.n||0)+'</div></div>';
  }).join('');
}

function renderSedes(sedes){renderBars(sedes,'vc-sedes',0,'#0A4FBF');}
function renderTrats(trats){renderBars(trats,'vc-trats',0,'#00C9A7');}
function renderEstados(estados){
  var colors={'PENDIENTE':'#D97706','ASISTIO':'#16A34A','NO ASISTIO':'#DC2626','CANCELADA':'#6B7BA8','CONFIRMADA':'#0A4FBF','REAGENDADA':'#7C3AED','EFECTIVA':'#16A34A'};
  var box=el('vc-estados');
  if(!estados||!estados.length){box.innerHTML='<div class="ld">Sin datos</div>';return;}
  var mx=Math.max.apply(null,estados.map(function(i){return i.n||0;}));
  box.innerHTML=estados.map(function(i){
    var pct=mx>0?Math.round((i.n||0)/mx*100):0;
    var c=colors[(i.estado||'').toUpperCase()]||'#0A4FBF';
    return '<div class="bar-row"><div class="bar-lbl">'+h(i.estado||'--')+'</div>'+
      '<div class="bar-track"><div class="bar-fill" style="width:'+pct+'%;background:'+c+';"></div></div>'+
      '<div class="bar-n">'+(i.n||0)+'</div></div>';
  }).join('');
}

// ══════════════════════════════════════════════════════════════
// MODAL DE CITA — Click en fila
// ══════════════════════════════════════════════════════════════
function vcAbrirCita(idx){
  var c=(VC._filtered||[])[idx];if(!c)return;
  VC._citaSel=c;
  var cli=((c.nombre||'')+' '+(c.apellido||'')).trim();
  // Crear modal dinámico si no existe
  var m=document.getElementById('vc-modal');
  if(!m){
    m=document.createElement('div');m.id='vc-modal';m.className='vc-mov';
    m.innerHTML='<div class="vc-mbox" id="vc-mbox"></div>';
    m.addEventListener('click',function(e){if(e.target===m)vcCerrarModal();});
    document.querySelector('.vc-root').appendChild(m);
  }
  document.getElementById('vc-mbox').innerHTML=
    '<div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:12px;">'+
    '<div><div style="font-family:Exo\\ 2,sans-serif;font-weight:800;font-size:15px;color:#0D1B3E;">'+h(cli||'Sin nombre')+'</div>'+
    '<div style="font-size:11px;color:#6B7BA8;">'+h(c.numero_limpio||c.numero||'')+' · '+h(c.tratamiento||'')+'</div></div>'+
    '<div style="cursor:pointer;font-size:18px;color:#9AAAC8;" onclick="vcCerrarModal()">✕</div></div>'+
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-bottom:12px;font-size:11px;">'+
    '<div><span style="color:#9AAAC8;font-weight:700;">FECHA:</span> '+h(c.fecha_cita||'')+'</div>'+
    '<div><span style="color:#9AAAC8;font-weight:700;">HORA:</span> '+h((c.hora_cita||'').toString().substring(0,5))+'</div>'+
    '<div><span style="color:#9AAAC8;font-weight:700;">SEDE:</span> '+h(c.sede||'')+'</div>'+
    '<div><span style="color:#9AAAC8;font-weight:700;">TIPO:</span> '+h(c.tipo_cita||'')+'</div>'+
    '<div><span style="color:#9AAAC8;font-weight:700;">ASESOR:</span> '+h(c.asesor||'No aplica')+'</div>'+
    '<div><span style="color:#9AAAC8;font-weight:700;">DOCTORA:</span> '+h(c.doctora||'Sin asignar')+'</div></div>'+
    '<div style="margin-bottom:10px;"><div style="font-size:9px;font-weight:700;color:#9AAAC8;letter-spacing:.5px;text-transform:uppercase;margin-bottom:5px;">CAMBIAR ESTADO</div>'+
    '<div style="display:flex;gap:5px;flex-wrap:wrap;" id="vc-estados-btns">'+
    ['PENDIENTE','CONFIRMADA','ASISTIO','EFECTIVA','NO ASISTIO','CANCELADA','REAGENDADA'].map(function(e){
      var ac=(c.estado_cita||'').toUpperCase()===e;
      var cols={'PENDIENTE':'#D97706','CONFIRMADA':'#0A4FBF','ASISTIO':'#16A34A','EFECTIVA':'#16A34A','NO ASISTIO':'#DC2626','CANCELADA':'#6B7BA8','REAGENDADA':'#7C3AED'};
      return '<div onclick="vcCambiarEstado(\''+e+'\')" style="padding:4px 10px;border-radius:6px;font-size:10px;font-weight:700;cursor:pointer;border:1.5px solid '+(cols[e]||'#DDE4F5')+';'+(ac?'background:'+(cols[e]||'#DDE4F5')+';color:#fff;':'background:#fff;color:'+(cols[e]||'#6B7BA8')+';')+'">'+e+'</div>';
    }).join('')+'</div></div>'+
    (c.obs?'<div style="font-size:11px;color:#6B7BA8;background:#F0F4FC;padding:8px;border-radius:7px;margin-bottom:10px;">'+h(c.obs)+'</div>':'')+
    '<div style="display:flex;gap:8px;margin-top:12px;">'+
    '<button onclick="vcCerrarModal()" style="flex:1;padding:8px;border-radius:8px;border:1px solid #DDE4F5;background:#F0F4FC;font-size:11px;font-weight:600;cursor:pointer;font-family:DM Sans,sans-serif;color:#6B7BA8;">Cerrar</button>'+
    '<button onclick="vcEliminarCita()" style="padding:8px 14px;border-radius:8px;border:none;background:#DC2626;color:#fff;font-size:11px;font-weight:700;cursor:pointer;font-family:DM Sans,sans-serif;">Eliminar</button>'+
    '<button onclick="vcEditarEnAgenda()" style="flex:1;padding:8px;border-radius:8px;border:none;background:#0A4FBF;color:#fff;font-size:11px;font-weight:700;cursor:pointer;font-family:DM Sans,sans-serif;">Editar en Agenda</button></div>';
  m.classList.add('open');
}

function vcCerrarModal(){var m=document.getElementById('vc-modal');if(m)m.classList.remove('open');}

function vcCambiarEstado(nuevoEstado){
  var c=VC._citaSel;if(!c||!c.id)return;
  fetch(_SB+'/rest/v1/aos_agenda_citas?id=eq.'+c.id,{method:'PATCH',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify({estado_cita:nuevoEstado,ts_actualizado:new Date().toISOString()})}).then(function(r){
    if(!r.ok)throw new Error('HTTP '+r.status);
    if(window.AOS_showToast)AOS_showToast('Estado actualizado',nuevoEstado,'');
    vcCerrarModal();vcReload();
  }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
}

function vcEliminarCita(){
  var c=VC._citaSel;if(!c||!c.id)return;
  if(!confirm('¿Eliminar esta cita? Esta acción no se puede deshacer.'))return;
  fetch(_SB+'/rest/v1/aos_agenda_citas?id=eq.'+c.id,{method:'DELETE',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Prefer':'return=minimal'}}).then(function(r){
    if(!r.ok)throw new Error('HTTP '+r.status);
    if(window.AOS_showToast)AOS_showToast('Cita eliminada','','');
    vcCerrarModal();vcReload();
  }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
}

function vcEditarEnAgenda(){
  vcCerrarModal();
  if(window.navigateTo)navigateTo('advisor-agenda');else if(window.AOS_navigateTo)AOS_navigateTo('advisor-agenda');
}
