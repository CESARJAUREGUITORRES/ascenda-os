// patients.js v2 — Pacientes 360 | AscendaOS v1 | 100% Supabase
var _SB='https://ituyqwstonmhnfshnaqz.supabase.co';
var _SK='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';
function _rpc(fn,p,ok,fail){fetch(_SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json'},body:JSON.stringify(p||{})}).then(function(r){return r.json();}).then(ok||function(){}).catch(fail||function(e){console.error('[SB]',fn,e);});}
function _rest(path,opts){return fetch(_SB+'/rest/v1/'+path,Object.assign({headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json','Prefer':'return=minimal'}},opts||{}));}
function h(s){var o=String(s||'');o=o.split('&').join('&amp;');o=o.split(String.fromCharCode(60)).join('&lt;');o=o.split('>').join('&gt;');o=o.split('"').join('&quot;');return o;}
function el(id){return document.getElementById(id);}
function estCls(e){var u=(e||'').toUpperCase();if(u==='PENDIENTE')return'est-pend';if(u==='CONFIRMADA'||u==='CITA CONFIRMADA')return'est-conf';if(u.indexOf('ASISTI')>=0&&u.indexOf('NO')<0||u==='EFECTIVA')return'est-asist';if(u.indexOf('NO ASIST')>=0)return'est-noasist';if(u==='CANCELADA')return'est-cancel';return'est-pend';}

var PT={sel:null,data:null,tab:'compras'};
function ptTL(){var p=el('pt-left');p.classList.toggle('hidden');el('pt-lt').style.left=p.classList.contains('hidden')?'0':'300px';}
function ptTR(){var p=el('pt-right');p.classList.toggle('hidden');el('pt-rt').style.right=p.classList.contains('hidden')?'0':'320px';}

var _ptT=null;
function ptSearch(q){clearTimeout(_ptT);var r=el('pt-res');if(!q||q.length<2){r.innerHTML='<div class="ld">Min. 2 caracteres</div>';return;}r.innerHTML='<div class="ld"><span class="sp"></span>Buscando...</div>';_ptT=setTimeout(function(){_rpc('aos_search_pacientes',{p_query:q,p_limit:20},function(rows){if(!rows||!rows.length){r.innerHTML='<div class="ld">Sin resultados</div>';return;}r.innerHTML=rows.map(function(p){var n=((p.nombres||'')+' '+(p.apellidos||'')).trim();var t=p.telefono||'';var e=(p.estado||'PROSPECTO').toUpperCase();var bc=e==='PACIENTE'?'bg-pac':e==='PROSPECTO'?'bg-pros':'bg-inact';return '<div class="pt-c" data-num="'+h(t)+'" onclick="ptSel(\''+h(t)+'\')"><div class="pt-cn">'+h(n||'Sin nombre')+'</div><div class="pt-cm">'+h(t)+(p.dni?' \u00b7 '+h(p.dni):'')+'</div><div class="pt-cb"><span class="pt-bg '+bc+'">'+h(e)+'</span>'+(p.sede?'<span class="pt-bg" style="background:#EBF2FF;color:#0A4FBF;">'+h(p.sede)+'</span>':'')+'</div></div>';}).join('');});},300);}

function ptSel(num){
  document.querySelectorAll('.pt-c').forEach(function(c){c.classList.toggle('act',c.getAttribute('data-num')===num);});
  el('pt-rt').classList.remove('hidden');
  el('pt-empty').style.display='none';
  var f=el('pt-ficha');f.style.display='block';f.innerHTML='<div class="ld"><span class="sp"></span>Cargando 360...</div>';
  _rpc('aos_paciente_360',{p_numero:num},function(d){
    if(!d||!d.found){f.innerHTML='<div class="ld">No encontrado</div>';return;}
    PT.data=d;PT.sel=d.paciente;PT.tab='compras';render360(d);renderNotas(d.notas||[]);
  });
}

function render360(d){
  var p=d.paciente;var n=((p.nombres||'')+' '+(p.apellidos||'')).trim();
  var ini=((p.nombres||'')[0]||'')+((p.apellidos||'')[0]||'');
  var wa='https://wa.me/51'+(p.telefono||'').replace(/[^0-9]/g,'');
  var e=(p.estado||'PROSPECTO').toUpperCase();var bc=e==='PACIENTE'?'bg-pac':e==='PROSPECTO'?'bg-pros':'bg-inact';
  var html='';
  // Header
  html+='<div class="fh"><div class="fav">'+h(ini.toUpperCase())+'</div><div style="flex:1"><div class="fn">'+h(n)+'</div><div class="fs">'+h(p.telefono||'')+' \u00b7 <span class="pt-bg '+bc+'">'+h(e)+'</span> \u00b7 '+(p.sede||'')+'</div></div><div class="fa"><a href="tel:'+h(p.telefono||'')+'" class="fab">\u260e Llamar</a><a href="'+wa+'" target="_blank" class="fab wa">WA</a></div></div>';
  // KPIs
  html+='<div class="fkr"><div class="fk"><div class="fkv">S/'+parseFloat(d.totalFacturado||0).toFixed(0)+'</div><div class="fkl">Facturado</div></div><div class="fk"><div class="fkv">'+(d.totalCompras||0)+'</div><div class="fkl">Compras</div></div><div class="fk"><div class="fkv">'+(d.citas||[]).length+'</div><div class="fkl">Citas</div></div><div class="fk"><div class="fkv">'+(d.llamadas||[]).length+'</div><div class="fkl">Llamadas</div></div></div>';
  // Datos personales - filiación completa
  var campos=[['DNI',p.dni],['Correo',p.correo],['Sexo',p.sexo],['Nacimiento',p.fecha_nac],['Estado civil',p.estado_civil],['Ocupaci\u00f3n',p.ocupacion],['Pa\u00eds',p.pais],['Departamento',p.departamento],['Ciudad',p.ciudad],['Distrito',p.distrito],['Direcci\u00f3n',p.direccion],['Contacto emerg.',p.contacto_emergencia],['Fuente',p.fuente],['Registro',p.fecha_registro],['Trat. principal',p.trat_principal]];
  html+='<div class="fd">';campos.forEach(function(r){html+='<div class="fdc"><div class="fdl">'+r[0]+'</div><div class="fdv">'+h(r[1]||'\u2014')+'</div></div>';});html+='</div>';
  // Duplicados
  if(d.duplicados&&d.duplicados.length){
    html+='<div class="dup-w"><div style="font-family:Exo\\ 2,sans-serif;font-weight:800;font-size:11px;color:#D97706;margin-bottom:4px;">\u26a0 Posibles duplicados</div>';
    d.duplicados.forEach(function(dup){html+='<div class="dup-c"><div><div class="dup-n">'+h((dup.nombres||'')+' '+(dup.apellidos||''))+'</div><div class="dup-m">Tel: '+h(dup.telefono||'')+'</div></div><div class="dup-b" onclick="ptSel(\''+h(dup.telefono||'')+'\')">Ver</div></div>';});
    html+='</div>';
  }
  // Tabs
  var tabs=[['compras','Compras ('+((d.compras||[]).length)+')'],['citas','Citas ('+((d.citas||[]).length)+')'],['llamadas','Llamadas ('+((d.llamadas||[]).length)+')'],['comprobantes','Comprobantes'],['consentimientos','Consentimientos']];
  html+='<div class="ftabs">';tabs.forEach(function(t){html+='<div class="ftab'+(PT.tab===t[0]?' act':'')+'" data-tab="'+t[0]+'" onclick="ptTab(\''+t[0]+'\')">'+t[1]+'</div>';});html+='</div>';
  html+='<div class="ftc" id="pt-tc"></div>';
  el('pt-ficha').innerHTML=html;renderTab();
}

function ptTab(t){PT.tab=t;document.querySelectorAll('.ftab').forEach(function(f){f.classList.toggle('act',f.getAttribute('data-tab')===t);});renderTab();}

function renderTab(){
  var b=el('pt-tc');if(!b||!PT.data)return;var d=PT.data;
  if(PT.tab==='compras'){
    var r=d.compras||[];if(!r.length){b.innerHTML='<div class="ld">Sin compras</div>';return;}
    b.innerHTML='<table class="tt"><thead><tr><th>Fecha</th><th>Tratamiento</th><th>Monto</th><th>Tipo</th><th>Sede</th><th>Asesor</th><th>Pago</th><th>Estado</th></tr></thead><tbody>'+r.map(function(v){return '<tr><td>'+h(v.fecha)+'</td><td>'+h(v.tratamiento)+'</td><td style="font-weight:700;color:#0A4FBF;">S/'+parseFloat(v.monto||0).toFixed(2)+'</td><td><span class="pt-bg" style="background:'+(v.tipo==='PRODUCTO'?'#F5F3FF;color:#7C3AED':'#EBF2FF;color:#0A4FBF')+'">'+h(v.tipo||'')+'</span></td><td>'+h((v.sede||'').substring(0,10))+'</td><td>'+h(v.asesor||'')+'</td><td style="font-size:9px;color:#6B7BA8;">'+h(v.pago||'')+'</td><td style="font-size:9px;">'+h(v.estado_pago||'')+'</td></tr>';}).join('')+'</tbody></table>';
  } else if(PT.tab==='citas'){
    var r=d.citas||[];if(!r.length){b.innerHTML='<div class="ld">Sin citas</div>';return;}
    b.innerHTML='<table class="tt"><thead><tr><th>Fecha</th><th>Hora</th><th>Tratamiento</th><th>Tipo</th><th>Sede</th><th>Estado</th><th>Doctora</th><th>Asesor</th></tr></thead><tbody>'+r.map(function(c){return '<tr><td>'+h(c.fecha)+'</td><td>'+h((c.hora||'').toString().substring(0,5))+'</td><td>'+h(c.tratamiento)+'</td><td style="font-size:9px;">'+h(c.tipo_cita||'')+'</td><td>'+h((c.sede||'').substring(0,10))+'</td><td><span class="est-b '+estCls(c.estado)+'">'+h(c.estado||'')+'</span></td><td>'+h((c.doctora||'').substring(0,12))+'</td><td>'+h(c.asesor||'')+'</td></tr>';}).join('')+'</tbody></table>';
  } else if(PT.tab==='llamadas'){
    var r=d.llamadas||[];if(!r.length){b.innerHTML='<div class="ld">Sin llamadas</div>';return;}
    b.innerHTML='<table class="tt"><thead><tr><th>Fecha</th><th>Hora</th><th>Trat.</th><th>Estado</th><th>Obs</th><th>Asesor</th></tr></thead><tbody>'+r.map(function(l){return '<tr><td>'+h(l.fecha)+'</td><td>'+h((l.hora||'').substring(0,5))+'</td><td>'+h((l.tratamiento||'').substring(0,14))+'</td><td style="color:'+(l.estado==='CITA CONFIRMADA'?'#0A4FBF':l.estado==='SIN CONTACTO'?'#DC2626':'#6B7BA8')+'">'+h(l.estado||'')+'</td><td style="font-size:9px;color:#6B7BA8;max-width:100px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">'+h((l.obs||'').substring(0,50))+'</td><td>'+h(l.asesor||'')+'</td></tr>';}).join('')+'</tbody></table>';
  } else if(PT.tab==='comprobantes'){
    var r=(d.compras||[]).filter(function(v){return v.estado_pago;});
    if(!r.length){b.innerHTML='<div class="ld">Sin comprobantes registrados</div>';return;}
    b.innerHTML='<table class="tt"><thead><tr><th>Fecha</th><th>Tratamiento</th><th>Monto</th><th>M\u00e9todo pago</th><th>Estado pago</th><th>Sede</th></tr></thead><tbody>'+r.map(function(v){var ep=v.estado_pago||'';var epCls=ep.indexOf('COMPLETO')>=0?'color:#16A34A':'color:#D97706';return '<tr><td>'+h(v.fecha)+'</td><td>'+h(v.tratamiento)+'</td><td style="font-weight:700;">S/'+parseFloat(v.monto||0).toFixed(2)+'</td><td>'+h(v.pago||'')+'</td><td style="font-weight:700;'+epCls+'">'+h(ep)+'</td><td>'+h((v.sede||'').substring(0,10))+'</td></tr>';}).join('')+'</tbody></table>';
  } else if(PT.tab==='consentimientos'){
    var r=d.documentos||[];
    b.innerHTML='<div style="margin-bottom:8px;display:flex;justify-content:flex-end;"><button class="pt-nb" onclick="ptSubirDoc()" style="font-size:10px;">+ Subir documento</button></div>';
    if(!r.length){b.innerHTML+='<div class="ld">Sin consentimientos ni documentos</div>';return;}
    b.innerHTML+='<table class="tt"><thead><tr><th>Fecha</th><th>Tipo</th><th>Nombre</th><th>Tratamiento</th><th>Autor</th></tr></thead><tbody>'+r.map(function(doc){return '<tr><td>'+h(doc.fecha||'')+'</td><td><span class="pt-bg" style="background:#EBF2FF;color:#0A4FBF;">'+h(doc.tipo_documento||'')+'</span></td><td>'+(doc.url_archivo?'<a href="'+h(doc.url_archivo)+'" target="_blank" style="color:#0A4FBF;text-decoration:underline;">'+h(doc.nombre_archivo||'Ver')+'</a>':h(doc.nombre_archivo||'--'))+'</td><td>'+h(doc.tratamiento||'')+'</td><td>'+h(doc.autor||'')+'</td></tr>';}).join('')+'</tbody></table>';
  }
}

function ptSubirDoc(){
  if(!PT.sel)return;
  var url=prompt('URL del documento (Google Drive, link directo):');
  if(!url)return;
  var tipo=prompt('Tipo: CONSENTIMIENTO, FOTO_ANTES, FOTO_DESPUES, RECETA, OTRO');
  if(!tipo)tipo='CONSENTIMIENTO';
  var trat=prompt('Tratamiento relacionado (opcional):');
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  _rest('aos_documentos_pacientes',{method:'POST',body:JSON.stringify({numero_limpio:PT.sel.telefono,tipo_documento:tipo.toUpperCase(),nombre_archivo:url.split('/').pop(),url_archivo:url,tratamiento:trat||'',autor:(ctx.asesor||'').toUpperCase(),id_autor:ctx.idAsesor||'',sede:''})}).then(function(r){
    if(!r.ok)throw new Error('Error');
    if(window.AOS_showToast)AOS_showToast('Documento guardado','','');
    ptSel(PT.sel.telefono);
  }).catch(function(e){alert('Error: '+e.message);});
}

// NOTAS CLÍNICAS
function renderNotas(notas){
  var list=el('pt-nl');
  if(!notas||!notas.length){list.innerHTML='<div class="ld">Sin notas cl\u00ednicas</div>';return;}
  var tipoMap={'RECEPCION':'nc-t-rec','INFORMATIVA':'nc-t-inf','ENFERMERIA':'nc-t-enf','DOCTORA':'nc-t-doc'};
  list.innerHTML=notas.map(function(n){
    var cls=tipoMap[(n.tipo_nota||'').toUpperCase()]||'nc-t-inf';
    var txt=n.contenido||'';
    if(n.evolucion)txt+=(txt?'\n':'')+'\u25B6 Evol: '+n.evolucion;
    if(n.diagnostico)txt+=(txt?'\n':'')+'\u25B6 Dx: '+n.diagnostico;
    if(n.plan_trabajo)txt+=(txt?'\n':'')+'\u25B6 Plan: '+n.plan_trabajo;
    if(n.triaje)txt+=(txt?'\n':'')+'\u25B6 Triaje: '+n.triaje;
    return '<div class="nc"><div class="nc-h"><span><span class="nc-tipo '+cls+'">'+h(n.tipo_nota||'')+'</span><span class="nc-a">'+h(n.autor||'')+(n.sede?' \u00b7 '+h(n.sede):'')+'</span></span><span class="nc-d">'+h((n.created_at||'').substring(0,16).replace('T',' '))+'</span></div><div class="nc-txt">'+h(txt)+'</div></div>';
  }).join('');
}

function ptAbrirNota(){
  if(!PT.sel){alert('Selecciona un paciente primero');return;}
  el('nt-contenido').value='';el('nt-tipo').value='RECEPCION';
  ['nt-evolucion','nt-diagnostico','nt-plan','nt-resultados','nt-signos','nt-adicional','nt-triaje','nt-evol-enf','nt-plan-enf'].forEach(function(id){var e=el(id);if(e)e.value='';});
  ptTipoNota();
  el('pt-m-nota').classList.add('open');
}
function ptCloseNota(){el('pt-m-nota').classList.remove('open');}

function ptTipoNota(){
  var t=el('nt-tipo').value;
  el('nt-clinico').style.display=t==='DOCTORA'?'block':'none';
  el('nt-enf').style.display=t==='ENFERMERIA'?'block':'none';
}

function ptGuardarNota(){
  if(!PT.sel)return;
  var tipo=el('nt-tipo').value;
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  var row={numero_limpio:PT.sel.telefono,tipo_nota:tipo,contenido:el('nt-contenido').value.trim(),autor:(ctx.asesor||'').toUpperCase(),id_autor:ctx.idAsesor||'',rol_autor:ctx.puesto||'',sede:el('nt-sede').value};
  if(tipo==='DOCTORA'){
    row.evolucion=el('nt-evolucion').value.trim();
    row.diagnostico=el('nt-diagnostico').value.trim();
    row.plan_trabajo=el('nt-plan').value.trim();
    row.resultado_estudios=el('nt-resultados').value.trim();
    row.signos_vitales=el('nt-signos').value.trim();
    row.nota_adicional=el('nt-adicional').value.trim();
  } else if(tipo==='ENFERMERIA'){
    row.triaje=el('nt-triaje').value.trim();
    row.evolucion=el('nt-evol-enf').value.trim();
    row.plan_trabajo=el('nt-plan-enf').value.trim();
  }
  _rest('aos_notas_pacientes',{method:'POST',body:JSON.stringify(row)}).then(function(r){
    if(!r.ok)throw new Error('Error');
    ptCloseNota();
    if(window.AOS_showToast)AOS_showToast('Nota guardada','','');
    ptSel(PT.sel.telefono);
  }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
}
