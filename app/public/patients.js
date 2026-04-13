// patients.js v3 — Pacientes 360 | AscendaOS v1 | 100% Supabase
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

// IMC calculator
function calcIMC(){
  var t=parseFloat(el('nt-talla').value)||0,w=parseFloat(el('nt-peso').value)||0;
  if(t>0&&w>0){var imc=(w/(t*t)).toFixed(1);el('nt-imc').value=imc;var v=parseFloat(imc);
    var lbl='',cls='';if(v<18.5){lbl='Bajo peso';cls='imc-bajo';}else if(v<25){lbl='Saludable';cls='imc-normal';}else if(v<30){lbl='Sobrepeso';cls='imc-sobre';}else{lbl='Obesidad';cls='imc-obeso';}
    el('nt-imc-pill').innerHTML='<span class="imc-pill '+cls+'">'+imc+' - '+lbl+'</span>';
  }else{el('nt-imc').value='';el('nt-imc-pill').innerHTML='';}
}

// SEARCH with duplicate detection
var _ptT=null;
function ptSearch(q){clearTimeout(_ptT);var r=el('pt-res');if(!q||q.length<2){r.innerHTML='<div class="ld">Min. 2 caracteres</div>';return;}r.innerHTML='<div class="ld"><span class="sp"></span>Buscando...</div>';_ptT=setTimeout(function(){_rpc('aos_search_pacientes',{p_query:q,p_limit:20},function(rows){
  if(!rows||!rows.length){r.innerHTML='<div class="ld">Sin resultados</div>';return;}
  // Detect duplicates: same name different number
  var nameMap={};rows.forEach(function(p){var k=((p.nombres||'')+(p.apellidos||'')).toUpperCase().replace(/\s/g,'');if(!nameMap[k])nameMap[k]=[];nameMap[k].push(p);});
  r.innerHTML=rows.map(function(p){
    var n=((p.nombres||'')+' '+(p.apellidos||'')).trim();var t=p.telefono||'';
    var e=(p.estado||'PROSPECTO').toUpperCase();var bc=e==='PACIENTE'?'bg-pac':e==='PROSPECTO'?'bg-pros':'bg-inact';
    var k=((p.nombres||'')+(p.apellidos||'')).toUpperCase().replace(/\s/g,'');
    var isDup=nameMap[k]&&nameMap[k].length>1;
    return '<div class="pt-c" data-num="'+h(t)+'" onclick="ptSel(\''+h(t)+'\')">'
      +'<div class="pt-cn">'+h(n||'Sin nombre')+'</div>'
      +'<div class="pt-cm">'+h(t)+(p.dni?' \u00b7 '+h(p.dni):'')+'</div>'
      +'<div class="pt-cb"><span class="pt-bg '+bc+'">'+h(e)+'</span>'
      +(isDup?'<span class="pt-bg bg-dup">\u26a0 Posible duplicado</span>':'')
      +(p.sede?'<span class="pt-bg" style="background:#EBF2FF;color:#0A4FBF;">'+h(p.sede)+'</span>':'')
      +'</div></div>';
  }).join('');
});},300);}

function ptSel(num){
  document.querySelectorAll('.pt-c').forEach(function(c){c.classList.toggle('act',c.getAttribute('data-num')===num);});
  el('pt-rt').classList.remove('hidden');el('pt-empty').style.display='none';
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
  var vip=p.etiqueta_vip||'NORMAL';
  var html='';
  html+='<div class="fh"><div class="fav">'+h(ini.toUpperCase())+'</div><div style="flex:1"><div class="fn">'+h(n)+' <span class="vip-badge vip-'+h(vip)+'">'+h(vip)+'</span></div><div class="fs">'+h(p.telefono||'')+' \u00b7 <span class="pt-bg '+bc+'">'+h(e)+'</span> \u00b7 '+(p.sede||'')+'</div></div><div class="fa"><button class="fab edit" onclick="ptEditarDatos()">&#9999; Editar</button><a href="tel:'+h(p.telefono||'')+'" class="fab">\u260e Llamar</a><a href="'+wa+'" target="_blank" class="fab wa">WA</a></div></div>';
  html+='<div class="fkr"><div class="fk"><div class="fkv">S/'+parseFloat(d.totalFacturado||0).toFixed(0)+'</div><div class="fkl">Facturado</div></div><div class="fk"><div class="fkv">'+(d.totalCompras||0)+'</div><div class="fkl">Compras</div></div><div class="fk"><div class="fkv">'+(d.citas||[]).length+'</div><div class="fkl">Citas</div></div><div class="fk"><div class="fkv">'+(d.llamadas||[]).length+'</div><div class="fkl">Llamadas</div></div></div>';
  var campos=[['DNI',p.dni],['Correo',p.correo],['Sexo',p.sexo],['Nacimiento',p.fecha_nac],['Estado civil',p.estado_civil],['Ocupaci\u00f3n',p.ocupacion],['Pa\u00eds',p.pais],['Departamento',p.departamento],['Ciudad',p.ciudad],['Distrito',p.distrito],['Direcci\u00f3n',p.direccion],['Contacto emerg.',p.contacto_emergencia],['Fuente',p.fuente],['Registro',p.fecha_registro],['Trat. principal',p.trat_principal]];
  html+='<div class="fd">';campos.forEach(function(r){html+='<div class="fdc"><div class="fdl">'+r[0]+'</div><div class="fdv">'+h(r[1]||'\u2014')+'</div></div>';});html+='</div>';
  if(d.duplicados&&d.duplicados.length){
    html+='<div class="dup-w"><div style="font-family:Exo\\ 2,sans-serif;font-weight:800;font-size:11px;color:#D97706;margin-bottom:4px;">\u26a0 Posibles duplicados ('+d.duplicados.length+')</div>';
    d.duplicados.forEach(function(dup){html+='<div class="dup-c"><div><div class="dup-n">'+h((dup.nombres||'')+' '+(dup.apellidos||''))+'</div><div class="dup-m">Tel: '+h(dup.telefono||'')+' | DNI: '+h(dup.dni||'')+'</div></div><div class="dup-b" onclick="ptSel(\''+h(dup.telefono||'')+'\')">Ver</div></div>';});
    html+='</div>';
  }
  var tabs=[['compras','Compras ('+((d.compras||[]).length)+')'],['citas','Citas ('+((d.citas||[]).length)+')'],['llamadas','Llamadas ('+((d.llamadas||[]).length)+')'],['comprobantes','Comprobantes'],['consentimientos','Consentimientos']];
  html+='<div class="ftabs">';tabs.forEach(function(t){html+='<div class="ftab'+(PT.tab===t[0]?' act':'')+'" data-tab="'+t[0]+'" onclick="ptTab(\''+t[0]+'\')">'+t[1]+'</div>';});html+='</div><div class="ftc" id="pt-tc"></div>';
  el('pt-ficha').innerHTML=html;renderTab();
}

function ptTab(t){PT.tab=t;document.querySelectorAll('.ftab').forEach(function(f){f.classList.toggle('act',f.getAttribute('data-tab')===t);});renderTab();}
function renderTab(){
  var b=el('pt-tc');if(!b||!PT.data)return;var d=PT.data;
  if(PT.tab==='compras'){var r=d.compras||[];if(!r.length){b.innerHTML='<div class="ld">Sin compras</div>';return;}b.innerHTML='<table class="tt"><thead><tr><th>Fecha</th><th>Tratamiento</th><th>Monto</th><th>Tipo</th><th>Sede</th><th>Asesor</th><th>Pago</th></tr></thead><tbody>'+r.map(function(v){return '<tr><td>'+h(v.fecha)+'</td><td>'+h(v.tratamiento)+'</td><td style="font-weight:700;color:#0A4FBF;">S/'+parseFloat(v.monto||0).toFixed(2)+'</td><td><span class="pt-bg" style="background:'+(v.tipo==='PRODUCTO'?'#F5F3FF;color:#7C3AED':'#EBF2FF;color:#0A4FBF')+'">'+h(v.tipo||'')+'</span></td><td>'+h((v.sede||'').substring(0,10))+'</td><td>'+h(v.asesor||'')+'</td><td style="font-size:9px;">'+h(v.pago||'')+'</td></tr>';}).join('')+'</tbody></table>';}
  else if(PT.tab==='citas'){var r=d.citas||[];if(!r.length){b.innerHTML='<div class="ld">Sin citas</div>';return;}b.innerHTML='<table class="tt"><thead><tr><th>Fecha</th><th>Hora</th><th>Tratamiento</th><th>Tipo</th><th>Sede</th><th>Estado</th><th>Doctora</th><th>Asesor</th></tr></thead><tbody>'+r.map(function(c){return '<tr><td>'+h(c.fecha)+'</td><td>'+h((c.hora||'').toString().substring(0,5))+'</td><td>'+h(c.tratamiento)+'</td><td style="font-size:9px;">'+h(c.tipo_cita||'')+'</td><td>'+h((c.sede||'').substring(0,10))+'</td><td><span class="est-b '+estCls(c.estado)+'">'+h(c.estado||'')+'</span></td><td>'+h((c.doctora||'').substring(0,12))+'</td><td>'+h(c.asesor||'')+'</td></tr>';}).join('')+'</tbody></table>';}
  else if(PT.tab==='llamadas'){var r=d.llamadas||[];if(!r.length){b.innerHTML='<div class="ld">Sin llamadas</div>';return;}b.innerHTML='<table class="tt"><thead><tr><th>Fecha</th><th>Hora</th><th>Trat.</th><th>Estado</th><th>Obs</th><th>Asesor</th></tr></thead><tbody>'+r.map(function(l){return '<tr><td>'+h(l.fecha)+'</td><td>'+h((l.hora||'').substring(0,5))+'</td><td>'+h((l.tratamiento||'').substring(0,14))+'</td><td>'+h(l.estado||'')+'</td><td style="font-size:9px;color:#6B7BA8;max-width:100px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">'+h((l.obs||'').substring(0,50))+'</td><td>'+h(l.asesor||'')+'</td></tr>';}).join('')+'</tbody></table>';}
  else if(PT.tab==='comprobantes'){var r=(d.compras||[]).filter(function(v){return v.pago;});if(!r.length){b.innerHTML='<div class="ld">Sin comprobantes</div>';return;}b.innerHTML='<table class="tt"><thead><tr><th>Fecha</th><th>Tratamiento</th><th>Monto</th><th>Pago</th><th>Estado</th><th>Sede</th></tr></thead><tbody>'+r.map(function(v){return '<tr><td>'+h(v.fecha)+'</td><td>'+h(v.tratamiento)+'</td><td style="font-weight:700;">S/'+parseFloat(v.monto||0).toFixed(2)+'</td><td>'+h(v.pago||'')+'</td><td>'+h(v.estado_pago||'')+'</td><td>'+h((v.sede||'').substring(0,10))+'</td></tr>';}).join('')+'</tbody></table>';}
  else if(PT.tab==='consentimientos'){var r=d.documentos||[];b.innerHTML='<div style="margin-bottom:8px;display:flex;justify-content:flex-end;"><button class="pt-nb" onclick="ptAbrirDoc()">+ Subir documento</button></div>';if(!r.length){b.innerHTML+='<div class="ld">Sin documentos</div>';return;}b.innerHTML+='<table class="tt"><thead><tr><th>Fecha</th><th>Tipo</th><th>Nombre</th><th>Autor</th></tr></thead><tbody>'+r.map(function(doc){return '<tr><td>'+h(doc.fecha||'')+'</td><td><span class="pt-bg" style="background:#EBF2FF;color:#0A4FBF;">'+h(doc.tipo_documento||'')+'</span></td><td>'+(doc.url_archivo?'<a href="'+h(doc.url_archivo)+'" target="_blank" style="color:#0A4FBF;text-decoration:underline;">'+h(doc.nombre_archivo||'Ver')+'</a>':h(doc.nombre_archivo||'--'))+'</td><td>'+h(doc.autor||'')+'</td></tr>';}).join('')+'</tbody></table>';}
}

// EDITAR DATOS PACIENTE
function ptEditarDatos(){
  if(!PT.sel)return;var p=PT.sel;
  el('ep-nom').value=p.nombres||'';el('ep-ape').value=p.apellidos||'';
  el('ep-dni').value=p.dni||'';el('ep-correo').value=p.correo||'';
  el('ep-sexo').value=p.sexo||'';el('ep-nac').value=p.fecha_nac||'';
  el('ep-ecivil').value=p.estado_civil||'';el('ep-ocup').value=p.ocupacion||'';
  el('ep-pais').value=p.pais||'Per\u00fa';el('ep-depto').value=p.departamento||'Lima';
  el('ep-ciudad').value=p.ciudad||'Lima';el('ep-dist').value=p.distrito||'';
  el('ep-dir').value=p.direccion||'';el('ep-emerg').value=p.contacto_emergencia||'';
  el('pt-m-edit').classList.add('open');
}
function ptGuardarDatos(){
  if(!PT.sel)return;
  var upd={"Nombres":el('ep-nom').value.trim(),"Apellidos":el('ep-ape').value.trim(),
    "N\u00b0 documento":el('ep-dni').value.trim(),"Email":el('ep-correo').value.trim(),
    "Sexo":el('ep-sexo').value,"Fecha de nacimiento":el('ep-nac').value,
    estado_civil:el('ep-ecivil').value,"Ocupaci\u00f3n":el('ep-ocup').value,
    pais:el('ep-pais').value,departamento:el('ep-depto').value,
    ciudad:el('ep-ciudad').value,distrito:el('ep-dist').value,
    "Direcci\u00f3n":el('ep-dir').value.trim(),contacto_emergencia:el('ep-emerg').value.trim()};
  var tel=PT.sel.telefono;
  _rest('aos_pacientes?numero_limpio=eq.'+tel,{method:'PATCH',body:JSON.stringify(upd)}).then(function(r){
    if(!r.ok)throw new Error('HTTP '+r.status);
    el('pt-m-edit').classList.remove('open');
    if(window.AOS_showToast)AOS_showToast('Datos actualizados','','');
    ptSel(tel);
  }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
}

// NOTAS CLÍNICAS
function renderNotas(notas){
  var list=el('pt-nl');if(!notas||!notas.length){list.innerHTML='<div class="ld">Sin notas cl\u00ednicas</div>';return;}
  var tm={'RECEPCION':'nc-t-rec','INFORMATIVA':'nc-t-inf','ENFERMERIA':'nc-t-enf','DOCTORA':'nc-t-doc'};
  list.innerHTML=notas.map(function(n){var cls=tm[(n.tipo_nota||'').toUpperCase()]||'nc-t-inf';
    var txt=n.contenido||'';
    if(n.evolucion)txt+='\n\u25B6 Evoluci\u00f3n: '+n.evolucion;
    if(n.resultado_estudios)txt+='\n\u25B6 Estudios: '+n.resultado_estudios;
    if(n.diagnostico)txt+='\n\u25B6 Dx: '+n.diagnostico;
    if(n.pronostico)txt+='\n\u25B6 Pron\u00f3stico: '+n.pronostico;
    if(n.plan_trabajo)txt+='\n\u25B6 Plan: '+n.plan_trabajo;
    if(n.triaje)txt+='\n\u25B6 Triaje: '+n.triaje;
    if(n.nota_adicional)txt+='\n\u25B6 Adicional: '+n.nota_adicional;
    return '<div class="nc"><div class="nc-h"><span><span class="nc-tipo '+cls+'">'+h(n.tipo_nota||'')+'</span><span class="nc-a">'+h(n.autor||'')+(n.sede?' \u00b7 '+h(n.sede):'')+'</span></span><span class="nc-d">'+h((n.created_at||'').substring(0,16).replace('T',' '))+'</span></div><div class="nc-txt">'+h(txt)+'</div></div>';
  }).join('');
}
function ptAbrirNota(){if(!PT.sel){alert('Selecciona un paciente');return;}el('nt-contenido').value='';el('nt-tipo').value='RECEPCION';
  ['nt-evolucion','nt-diagnostico','nt-pronostico','nt-plan','nt-resultados','nt-adicional','nt-talla','nt-peso','nt-pa','nt-fc','nt-motivo','nt-evol-enf','nt-plan-enf'].forEach(function(id){var e=el(id);if(e)e.value='';});
  el('nt-imc').value='';el('nt-imc-pill').innerHTML='';ptTipoNota();el('pt-m-nota').classList.add('open');}
function ptCloseNota(){el('pt-m-nota').classList.remove('open');}
function ptTipoNota(){var t=el('nt-tipo').value;el('nt-clinico').style.display=t==='DOCTORA'?'block':'none';el('nt-enf').style.display=t==='ENFERMERIA'?'block':'none';}

function ptGuardarNota(){
  if(!PT.sel)return;var tipo=el('nt-tipo').value;
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  var row={numero:PT.sel.telefono,tipo_nota:tipo,texto:el('nt-contenido').value.trim(),usuario:(ctx.asesor||'').toUpperCase(),rol:ctx.puesto||'',rol_autor:ctx.puesto||'',sede:el('nt-sede').value,fecha:new Date().toISOString().slice(0,10),hora:new Date().toTimeString().slice(0,8)};
  if(tipo==='DOCTORA'){row.evolucion=el('nt-evolucion').value.trim();row.diagnostico=el('nt-diagnostico').value.trim();row.pronostico=el('nt-pronostico').value.trim();row.plan_trabajo=el('nt-plan').value.trim();row.resultado_estudios=el('nt-resultados').value.trim();row.nota_adicional=el('nt-adicional').value.trim();}
  else if(tipo==='ENFERMERIA'){
    var triaje='Talla:'+el('nt-talla').value+' Peso:'+el('nt-peso').value+' IMC:'+el('nt-imc').value+' P/A:'+el('nt-pa').value+' FC:'+el('nt-fc').value+' Motivo:'+el('nt-motivo').value;
    row.triaje=triaje;row.signos_vitales='P/A:'+el('nt-pa').value+' FC:'+el('nt-fc').value;
    row.evolucion=el('nt-evol-enf').value.trim();row.plan_trabajo=el('nt-plan-enf').value.trim();
  }
  _rest('aos_notas_pacientes',{method:'POST',body:JSON.stringify(row)}).then(function(r){
    if(!r.ok)throw new Error('Error');ptCloseNota();if(window.AOS_showToast)AOS_showToast('Nota guardada','','');ptSel(PT.sel.telefono);
  }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
}

// SUBIR DOCUMENTO
function ptAbrirDoc(){if(!PT.sel)return;el('doc-url').value='';el('doc-nombre').value='';el('doc-trat').value='';el('doc-tipo').value='CONSENTIMIENTO';el('pt-m-doc').classList.add('open');}
function ptGuardarDoc(){
  if(!PT.sel)return;var url=el('doc-url').value.trim();if(!url){alert('Ingresa la URL del documento');return;}
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  _rest('aos_documentos_pacientes',{method:'POST',body:JSON.stringify({numero:PT.sel.telefono,tipo:el('doc-tipo').value,nombre_archivo:el('doc-nombre').value.trim()||url.split('/').pop(),url_drive:url,usuario:(ctx.asesor||'').toUpperCase(),fecha:new Date().toISOString().slice(0,10)})}).then(function(r){
    if(!r.ok)throw new Error('Error');el('pt-m-doc').classList.remove('open');if(window.AOS_showToast)AOS_showToast('Documento guardado','','');ptSel(PT.sel.telefono);
  }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
}

// NUEVO PACIENTE
function ptNuevoPac(){
  ['np-nom','np-ape','np-tel','np-dni','np-correo','np-fuente'].forEach(function(id){el(id).value='';});
  el('np-sexo').value='';el('np-sede').value='SAN ISIDRO';
  el('pt-m-nuevo').classList.add('open');
}
function ptCrearPac(){
  var nom=el('np-nom').value.trim(),ape=el('np-ape').value.trim(),tel=el('np-tel').value.trim().replace(/\D/g,'');
  if(!nom||!ape){alert('Nombres y apellidos son obligatorios');return;}
  if(!tel||tel.length<7){alert('Teléfono válido obligatorio');return;}
  var now=new Date();
  var row={"Nombres":nom.toUpperCase(),"Apellidos":ape.toUpperCase(),"Teléfono":tel,
    numero_limpio:tel,"N° documento":el('np-dni').value.trim(),"Email":el('np-correo').value.trim(),
    "Sexo":el('np-sexo').value,"SEDE_PRINCIPAL":el('np-sede').value,
    "FUENTE":el('np-fuente').value.trim(),"ESTADO_PACIENTE":"PROSPECTO",
    "FECHA_REGISTRO":now.toISOString().slice(0,10),
    "ID_PACIENTE":"P-"+Date.now(),
    pais:"Perú",departamento:"Lima",ciudad:"Lima",
    etiqueta_vip:"NORMAL"};
  _rest('aos_pacientes',{method:'POST',body:JSON.stringify(row)}).then(function(r){
    if(!r.ok)throw new Error('HTTP '+r.status);
    el('pt-m-nuevo').classList.remove('open');
    if(window.AOS_showToast)AOS_showToast('Paciente creado','','toast-venta');
    ptSel(tel);
  }).catch(function(e){if(window.AOS_showToast)AOS_showToast('Error',e.message||'','toast-alerta');});
}
