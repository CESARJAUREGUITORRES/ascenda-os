// patients.js — Pacientes 360 | AscendaOS v1 | 100% Supabase
var _SB='https://ituyqwstonmhnfshnaqz.supabase.co';
var _SK='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';
function _rpc(fn,p,ok,fail){fetch(_SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json'},body:JSON.stringify(p||{})}).then(function(r){return r.json();}).then(ok||function(){}).catch(fail||function(e){console.error('[SB]',fn,e);});}
function _rest(path,opts){return fetch(_SB+'/rest/v1/'+path,Object.assign({headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'}},opts||{}));}
function h(s){var o=String(s||'');o=o.split('&').join('&amp;');o=o.split(String.fromCharCode(60)).join('&lt;');o=o.split('>').join('&gt;');o=o.split('"').join('&quot;');return o;}
function el(id){return document.getElementById(id);}
function estCls(e){var u=(e||'').toUpperCase();if(u==='PENDIENTE')return'est-pend';if(u==='CONFIRMADA'||u==='CITA CONFIRMADA')return'est-conf';if(u.indexOf('ASISTI')>=0&&u.indexOf('NO')<0||u==='EFECTIVA')return'est-asist';if(u.indexOf('NO ASIST')>=0)return'est-noasist';if(u==='CANCELADA')return'est-cancel';return'est-pend';}

var PT={sel:null,data:null,tab:'compras'};

// TOGGLE PANELS
function ptToggleLeft(){var p=el('pt-left');p.classList.toggle('hidden');var t=el('pt-left-tog');t.style.left=p.classList.contains('hidden')?'0':'320px';}
function ptToggleRight(){var p=el('pt-right');p.classList.toggle('hidden');var t=el('pt-right-tog');t.classList.toggle('hidden');t.style.right=p.classList.contains('hidden')?'0':'300px';}

// SEARCH
var _ptTmr=null;
function ptSearch(q){
  clearTimeout(_ptTmr);
  var res=el('pt-results');
  if(!q||q.length<2){res.innerHTML='<div class="ld">Escribe al menos 2 caracteres</div>';return;}
  res.innerHTML='<div class="ld"><span class="sp"></span>Buscando...</div>';
  _ptTmr=setTimeout(function(){
    _rpc('aos_search_pacientes',{p_query:q,p_limit:20},function(rows){
      if(!rows||!rows.length){res.innerHTML='<div class="ld">Sin resultados para "'+h(q)+'"</div>';return;}
      el('pt-count').textContent=rows.length+' resultado'+(rows.length!==1?'s':'');
      res.innerHTML=rows.map(function(p){
        var nom=((p.nombres||'')+' '+(p.apellidos||'')).trim();
        var tel=p.telefono||'';
        var est=(p.estado||'PROSPECTO').toUpperCase();
        var bc=est==='PACIENTE'?'bg-pac':est==='PROSPECTO'?'bg-pros':'bg-inact';
        return '<div class="pt-card" data-num="'+h(tel)+'" onclick="ptSelect(\''+h(tel)+'\')">'
          +'<div class="pt-card-name">'+h(nom||'Sin nombre')+'</div>'
          +'<div class="pt-card-meta">'+h(tel)+(p.dni?' \u00b7 DNI:'+h(p.dni):'')+'</div>'
          +'<div class="pt-card-badges"><span class="pt-badge '+bc+'">'+h(est)+'</span>'+(p.sede?'<span class="pt-badge" style="background:#EBF2FF;color:#0A4FBF;">'+h(p.sede)+'</span>':'')+'</div></div>';
      }).join('');
    });
  },300);
}

// SELECT PATIENT -> LOAD 360
function ptSelect(num){
  // Highlight card
  document.querySelectorAll('.pt-card').forEach(function(c){c.classList.remove('act');});
  document.querySelectorAll('.pt-card[data-num="'+num+'"]').forEach(function(c){c.classList.add('act');});
  // Collapse left panel on mobile
  if(window.innerWidth<900)ptToggleLeft();
  // Show right panel toggle
  el('pt-right-tog').classList.remove('hidden');
  // Load 360
  el('pt-empty').style.display='none';
  var ficha=el('pt-ficha');
  ficha.style.display='block';
  ficha.innerHTML='<div class="ld"><span class="sp"></span>Cargando ficha 360...</div>';
  _rpc('aos_paciente_360',{p_numero:num},function(d){
    if(!d||!d.found){ficha.innerHTML='<div class="ld">Paciente no encontrado</div>';return;}
    PT.data=d;PT.sel=d.paciente;PT.tab='compras';
    render360(d);
    loadNotas(num);
  });
}

function render360(d){
  var p=d.paciente;
  var nom=((p.nombres||'')+' '+(p.apellidos||'')).trim();
  var initials=((p.nombres||'')[0]||'')+((p.apellidos||'')[0]||'');
  var wa='https://wa.me/51'+(p.telefono||'').replace(/[^0-9]/g,'');
  var est=(p.estado||'PROSPECTO').toUpperCase();
  var bc=est==='PACIENTE'?'bg-pac':est==='PROSPECTO'?'bg-pros':'bg-inact';

  var html='';
  // HEADER
  html+='<div class="ficha-hdr"><div class="ficha-avatar">'+h(initials.toUpperCase())+'</div><div style="flex:1;"><div class="ficha-name">'+h(nom)+'</div><div class="ficha-sub">'+h(p.telefono||'')+' \u00b7 <span class="pt-badge '+bc+'">'+h(est)+'</span> \u00b7 '+(p.sede||'Sin sede')+'</div></div><div class="ficha-actions"><a href="tel:'+h(p.telefono||'')+'" class="ficha-act-btn">\u260e Llamar</a><a href="'+wa+'" target="_blank" class="ficha-act-btn wa">WA</a></div></div>';

  // KPIs
  html+='<div class="ficha-kpis">';
  html+='<div class="fk"><div class="fk-v">S/'+parseFloat(d.totalFacturado||0).toFixed(0)+'</div><div class="fk-l">Facturado</div></div>';
  html+='<div class="fk"><div class="fk-v">'+parseInt(d.totalCompras||0)+'</div><div class="fk-l">Compras</div></div>';
  html+='<div class="fk"><div class="fk-v">'+(d.citas||[]).length+'</div><div class="fk-l">Citas</div></div>';
  html+='<div class="fk"><div class="fk-v">'+(d.llamadas||[]).length+'</div><div class="fk-l">Llamadas</div></div>';
  html+='</div>';

  // DATOS PERSONALES
  html+='<div class="ficha-datos">';
  [['DNI',p.dni],['Correo',p.correo],['Sexo',p.sexo],['Nacimiento',p.fecha_nac],['Direcci\u00f3n',p.direccion],['Ocupaci\u00f3n',p.ocupacion],['Fuente',p.fuente],['Registro',p.fecha_registro],['Trat. principal',p.trat_principal],['Score',p.score]].forEach(function(r){
    html+='<div class="fd-card"><div class="fd-lbl">'+r[0]+'</div><div class="fd-val">'+h(r[1]||'\u2014')+'</div></div>';
  });
  html+='</div>';

  // DUPLICADOS
  if(d.duplicados&&d.duplicados.length){
    html+='<div style="margin-bottom:14px;"><div style="font-family:Exo\\ 2,sans-serif;font-weight:800;font-size:12px;color:#D97706;margin-bottom:6px;">\u26a0 Posibles duplicados ('+d.duplicados.length+')</div>';
    d.duplicados.forEach(function(dup){
      html+='<div class="dup-card"><div class="dup-info"><div class="dup-name">'+h((dup.nombres||'')+' '+(dup.apellidos||''))+'</div><div class="dup-meta">Tel: '+h(dup.telefono||'')+' | DNI: '+h(dup.dni||'')+'</div></div><div class="dup-btn" onclick="ptSelect(\''+h(dup.telefono||'')+'\')">Ver ficha</div></div>';
    });
    html+='</div>';
  }

  // TABS
  html+='<div class="ficha-tabs">';
  ['compras','citas','llamadas','seguimientos'].forEach(function(t){
    var labels={compras:'Compras ('+((d.compras||[]).length)+')',citas:'Citas ('+((d.citas||[]).length)+')',llamadas:'Llamadas ('+((d.llamadas||[]).length)+')',seguimientos:'Seguimientos ('+((d.seguimientos||[]).length)+')'};
    html+='<div class="ftab'+(PT.tab===t?' act':'')+'" data-tab="'+t+'" onclick="ptTab(\''+t+'\')">'+labels[t]+'</div>';
  });
  html+='</div>';
  html+='<div class="ficha-tab-content" id="pt-tab-content"></div>';

  el('pt-ficha').innerHTML=html;
  renderTab();
}

function ptTab(t){PT.tab=t;document.querySelectorAll('.ftab').forEach(function(f){f.classList.toggle('act',f.getAttribute('data-tab')===t);});renderTab();}

function renderTab(){
  var box=el('pt-tab-content');if(!box||!PT.data)return;
  var d=PT.data;
  if(PT.tab==='compras'){
    var rows=d.compras||[];
    if(!rows.length){box.innerHTML='<div class="ld">Sin compras</div>';return;}
    box.innerHTML='<table class="tb-table"><thead><tr><th>Fecha</th><th>Tratamiento</th><th>Monto</th><th>Tipo</th><th>Sede</th><th>Asesor</th><th>Pago</th></tr></thead><tbody>'+rows.map(function(v){
      return '<tr><td>'+h(v.fecha)+'</td><td>'+h(v.tratamiento)+'</td><td style="font-weight:700;color:#0A4FBF;">S/'+parseFloat(v.monto||0).toFixed(2)+'</td><td><span class="pt-badge" style="background:'+(v.tipo==='PRODUCTO'?'#F5F3FF;color:#7C3AED':'#EBF2FF;color:#0A4FBF')+'">'+h(v.tipo||'')+'</span></td><td>'+h((v.sede||'').substring(0,10))+'</td><td>'+h(v.asesor||'')+'</td><td style="font-size:10px;color:#6B7BA8;">'+h(v.pago||'')+'</td></tr>';
    }).join('')+'</tbody></table>';
  } else if(PT.tab==='citas'){
    var rows=d.citas||[];
    if(!rows.length){box.innerHTML='<div class="ld">Sin citas</div>';return;}
    box.innerHTML='<table class="tb-table"><thead><tr><th>Fecha</th><th>Hora</th><th>Tratamiento</th><th>Sede</th><th>Estado</th><th>Doctora</th><th>Asesor</th></tr></thead><tbody>'+rows.map(function(c){
      return '<tr><td>'+h(c.fecha)+'</td><td>'+h((c.hora||'').toString().substring(0,5))+'</td><td>'+h(c.tratamiento)+'</td><td>'+h((c.sede||'').substring(0,10))+'</td><td><span class="est-b '+estCls(c.estado)+'">'+h(c.estado||'')+'</span></td><td>'+h((c.doctora||'').substring(0,12))+'</td><td>'+h(c.asesor||'')+'</td></tr>';
    }).join('')+'</tbody></table>';
  } else if(PT.tab==='llamadas'){
    var rows=d.llamadas||[];
    if(!rows.length){box.innerHTML='<div class="ld">Sin llamadas</div>';return;}
    box.innerHTML='<table class="tb-table"><thead><tr><th>Fecha</th><th>Hora</th><th>Trat.</th><th>Estado</th><th>Obs</th><th>Asesor</th></tr></thead><tbody>'+rows.map(function(l){
      return '<tr><td>'+h(l.fecha)+'</td><td>'+h((l.hora||'').substring(0,5))+'</td><td>'+h((l.tratamiento||'').substring(0,14))+'</td><td style="color:'+(l.estado==='CITA CONFIRMADA'?'#0A4FBF':l.estado==='SIN CONTACTO'?'#DC2626':'#6B7BA8')+'">'+h(l.estado||'')+'</td><td style="font-size:10px;color:#6B7BA8;max-width:120px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">'+h((l.obs||'').substring(0,40))+'</td><td>'+h(l.asesor||'')+'</td></tr>';
    }).join('')+'</tbody></table>';
  } else if(PT.tab==='seguimientos'){
    var rows=d.seguimientos||[];
    if(!rows.length){box.innerHTML='<div class="ld">Sin seguimientos</div>';return;}
    box.innerHTML='<table class="tb-table"><thead><tr><th>Fecha</th><th>Tratamiento</th><th>Estado</th><th>Obs</th><th>Asesor</th></tr></thead><tbody>'+rows.map(function(s){
      return '<tr><td>'+h(s.fecha||'')+'</td><td>'+h(s.tratamiento||'')+'</td><td>'+h(s.estado||'')+'</td><td style="font-size:10px;color:#6B7BA8;">'+h((s.obs||'').substring(0,40))+'</td><td>'+h(s.asesor||'')+'</td></tr>';
    }).join('')+'</tbody></table>';
  }
}

// NOTAS
function loadNotas(num){
  var list=el('pt-notes-list');
  list.innerHTML='<div class="ld"><span class="sp"></span></div>';
  // Notas del paciente desde las llamadas con observación
  _rpc('aos_paciente_360',{p_numero:num},function(d){
    if(!d||!d.found){list.innerHTML='<div class="ld">Sin notas</div>';return;}
    var notas=[];
    (d.llamadas||[]).forEach(function(l){
      if(l.obs&&l.obs.trim())notas.push({fecha:l.fecha,autor:l.asesor||'',texto:l.obs,tipo:'Llamada'});
    });
    (d.seguimientos||[]).forEach(function(s){
      if(s.obs&&s.obs.trim())notas.push({fecha:s.fecha,autor:s.asesor||'',texto:s.obs,tipo:'Seguimiento'});
    });
    if(d.paciente&&d.paciente.notas)notas.unshift({fecha:'--',autor:'Sistema',texto:d.paciente.notas,tipo:'Nota general'});
    if(!notas.length){list.innerHTML='<div class="ld">Sin notas registradas</div>';return;}
    list.innerHTML=notas.map(function(n){
      return '<div class="note-card"><div class="note-card-hdr"><span class="note-card-author">'+h(n.autor)+' \u00b7 '+h(n.tipo)+'</span><span class="note-card-date">'+h(n.fecha)+'</span></div><div class="note-card-text">'+h(n.texto).substring(0,200)+'</div></div>';
    }).join('');
  });
}

function ptAddNote(){
  if(!PT.sel||!PT.sel.telefono)return;
  var texto=el('pt-note-text').value.trim();
  if(!texto){return;}
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  var row={fecha:new Date().toISOString().slice(0,10),numero:PT.sel.telefono,numero_limpio:PT.sel.telefono,tratamiento:'',estado:'NOTA',observacion:texto,hora_llamada:new Date().toTimeString().slice(0,8),asesor:(ctx.asesor||'').toUpperCase(),id_asesor:ctx.idAsesor||'',created_at:new Date().toISOString()};
  _rest('aos_llamadas',{method:'POST',body:JSON.stringify(row)}).then(function(r){
    if(!r.ok)throw new Error('HTTP '+r.status);
    el('pt-note-text').value='';
    if(window.AOS_showToast)AOS_showToast('Nota guardada','','');
    loadNotas(PT.sel.telefono);
  }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
}
