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
  var m=document.getElementById('vc-modal');
  if(!m){
    m=document.createElement('div');m.id='vc-modal';m.className='vc-mov';
    m.innerHTML='<div class="vc-mbox" id="vc-mbox"></div>';
    m.addEventListener('click',function(e){if(e.target===m)vcCerrarModal();});
    document.querySelector('.vc-root').appendChild(m);
  }
  var estados=['PENDIENTE','CONFIRMADA','ASISTIO','EFECTIVA','NO ASISTIO','CANCELADA','REAGENDADA'];
  var cols={'PENDIENTE':'#D97706','CONFIRMADA':'#0A4FBF','ASISTIO':'#16A34A','EFECTIVA':'#16A34A','NO ASISTIO':'#DC2626','CANCELADA':'#6B7BA8','REAGENDADA':'#7C3AED'};
  var estBtns=estados.map(function(e){
    var ac=(c.estado_cita||'').toUpperCase()===e;
    return '<div onclick="vcCambiarEstado(\''+e+'\')" style="padding:3px 9px;border-radius:6px;font-size:9px;font-weight:700;cursor:pointer;border:1.5px solid '+(cols[e]||'#DDE4F5')+';'+(ac?'background:'+(cols[e]||'#DDE4F5')+';color:#fff;':'background:#fff;color:'+(cols[e]||'#6B7BA8')+';')+'">'+e.replace('_',' ')+'</div>';
  }).join('');

  document.getElementById('vc-mbox').innerHTML=
    '<div style="display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:14px;">'+
    '<div style="display:flex;align-items:center;gap:10px;">'+
    '<div style="width:36px;height:36px;border-radius:10px;background:#FEF2F2;display:flex;align-items:center;justify-content:center;font-size:18px;">📋</div>'+
    '<div><div style="font-family:Exo\\ 2,sans-serif;font-weight:800;font-size:16px;color:#0D1B3E;">'+h(cli||'Sin nombre')+'</div>'+
    '<div style="font-size:11px;color:#6B7BA8;">'+h(c.numero_limpio||c.numero||'')+' · '+h(c.tratamiento||'')+'</div></div></div>'+
    '<div style="cursor:pointer;width:28px;height:28px;border-radius:7px;border:1px solid #DDE4F5;background:#F0F4FC;display:flex;align-items:center;justify-content:center;font-size:14px;flex-shrink:0;" onclick="vcCerrarModal()">✕</div></div>'+

    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:24px;">'+
    // Columna izquierda: Datos de la cita
    '<div>'+
    '<div style="font-family:Exo\\ 2,sans-serif;font-weight:800;font-size:13px;color:#0D1B3E;margin-bottom:8px;">Datos de la cita</div>'+
    '<div style="display:flex;flex-direction:column;gap:0;">'+
    [['FECHA',c.fecha_cita],['HORA',(c.hora_cita||'').toString().substring(0,5)],['SEDE',c.sede],['TIPO',c.tipo_cita],['TRATAMIENTO',c.tratamiento],['ASESOR',c.asesor||'No aplica'],['ATENCIÓN',c.tipo_atencion||'--'],['DOCTORA',c.doctora||'Sin asignar']].map(function(r){
      return '<div style="display:flex;justify-content:space-between;padding:4px 0;border-bottom:1px solid rgba(221,228,245,.3);"><span style="font-size:10px;font-weight:700;color:#9AAAC8;text-transform:uppercase;">'+r[0]+'</span><span style="font-size:12px;font-weight:600;color:#0D1B3E;text-align:right;">'+h(r[1]||'--')+'</span></div>';
    }).join('')+'</div>'+
    '<div style="margin-top:10px;"><div style="font-size:9px;font-weight:700;color:#9AAAC8;letter-spacing:.5px;text-transform:uppercase;margin-bottom:5px;">CAMBIAR ESTADO</div>'+
    '<div style="display:flex;gap:4px;flex-wrap:wrap;">'+estBtns+'</div></div>'+
    (c.obs?'<div style="margin-top:8px;"><div style="font-size:9px;font-weight:700;color:#9AAAC8;letter-spacing:.5px;text-transform:uppercase;margin-bottom:4px;">NOTA</div><div style="font-size:11px;color:#6B7BA8;background:#F0F4FC;padding:8px;border-radius:7px;max-height:80px;overflow-y:auto;">'+h(c.obs)+'</div></div>':'')+
    '</div>'+

    // Columna derecha: Historial del paciente
    '<div>'+
    '<div style="font-family:Exo\\ 2,sans-serif;font-weight:800;font-size:13px;color:#0D1B3E;margin-bottom:8px;">Historial del paciente</div>'+
    '<div id="vc-historial-pac"><div style="text-align:center;padding:12px;color:#9AAAC8;font-size:11px;">Cargando historial...</div></div>'+
    '</div></div>'+

    // Botones inferiores — igual que agenda
    '<div style="display:flex;gap:8px;margin-top:16px;">'+
    '<button onclick="vcCerrarModal()" style="flex:1;padding:9px;border-radius:9px;border:1px solid #DDE4F5;background:#fff;font-size:11px;font-weight:600;cursor:pointer;font-family:DM Sans,sans-serif;color:#6B7BA8;">Cerrar</button>'+
    '<button onclick="vcEliminarCita()" style="flex:.6;padding:9px;border-radius:9px;border:none;background:#DC2626;color:#fff;font-size:11px;font-weight:700;cursor:pointer;font-family:DM Sans,sans-serif;">Eliminar</button>'+
    '<button onclick="vcEditarEnAgenda()" style="flex:1;padding:9px;border-radius:9px;border:none;background:#0A4FBF;color:#fff;font-size:11px;font-weight:700;cursor:pointer;font-family:DM Sans,sans-serif;">Editar en Agenda</button></div>';

  m.classList.add('open');
  // Cargar historial del paciente
  vcCargarHistorial(c.numero_limpio||c.numero||'');
}

function vcCargarHistorial(num){
  var box=document.getElementById('vc-historial-pac');if(!box||!num)return;
  _rpc('aos_paciente_360',{p_numero:num},function(d){
    if(!d){box.innerHTML='<div style="color:#9AAAC8;font-size:10px;">Sin historial</div>';return;}
    var html='';
    // Compras
    var compras=d.compras||[];
    if(compras.length){
      html+='<div style="font-size:10px;font-weight:700;color:#0A4FBF;margin-bottom:4px;">COMPRAS ('+compras.length+')</div>';
      html+=compras.slice(0,5).map(function(v){return '<div style="font-size:10px;color:#0D1B3E;padding:2px 0;">'+h(v.fecha||'')+' '+h(v.tratamiento||'')+' <span style="color:#16A34A;font-weight:700;">S/'+h(v.monto||'0')+'</span></div>';}).join('');
    }
    // Citas
    var citas=d.citas||[];
    if(citas.length){
      html+='<div style="font-size:10px;font-weight:700;color:#0A4FBF;margin-top:8px;margin-bottom:4px;">CITAS ('+citas.length+')</div>';
      html+=citas.slice(0,6).map(function(c2){
        var ec=c2.estado_cita||'';var ecol={'PENDIENTE':'#D97706','ASISTIO':'#16A34A','NO ASISTIO':'#DC2626','CANCELADA':'#6B7BA8','CONFIRMADA':'#0A4FBF','EFECTIVA':'#16A34A'}[ec.toUpperCase()]||'#6B7BA8';
        return '<div style="font-size:10px;color:#0D1B3E;padding:2px 0;">'+h(c2.fecha_cita||'')+' '+h(c2.tratamiento||'')+' <span style="font-weight:700;color:'+ecol+';">'+h(ec)+'</span></div>';
      }).join('');
    }
    // Llamadas
    var llam=d.llamadas||[];
    if(llam.length){
      html+='<div style="font-size:10px;font-weight:700;color:#0A4FBF;margin-top:8px;margin-bottom:4px;">LLAMADAS ('+llam.length+')</div>';
      html+=llam.slice(0,5).map(function(l){return '<div style="font-size:10px;color:#0D1B3E;padding:2px 0;">'+h(l.fecha||'')+' '+h(l.tratamiento||'')+' <span style="color:#6B7BA8;">'+h(l.estado||'')+'</span></div>';}).join('');
    }
    if(!html)html='<div style="color:#9AAAC8;font-size:10px;">Sin historial registrado</div>';
    box.innerHTML=html;
  },function(){box.innerHTML='<div style="color:#DC2626;font-size:10px;">Error al cargar</div>';});
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
