// sales.js — Mis Ventas | AscendaOS v1 | 100% Supabase
var _SB='https://ituyqwstonmhnfshnaqz.supabase.co';
var _SK='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';
function _rpc(fn,p,ok,fail){fetch(_SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json'},body:JSON.stringify(p||{})}).then(function(r){return r.json();}).then(ok||function(){}).catch(fail||function(e){console.error('[SB]',fn,e);});}
function h(s){var o=String(s||'');o=o.split('&').join('&amp;');o=o.split(String.fromCharCode(60)).join('&lt;');o=o.split('>').join('&gt;');o=o.split('"').join('&quot;');return o;}
function el(id){return document.getElementById(id);}

var MF=['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
var VS={mes:new Date().getMonth()+1, anio:new Date().getFullYear(), data:null, filtro:'all'};

(function(){
  el('vs-mes').value=String(VS.mes);
  el('vs-anio').value=String(VS.anio);
  vsReload();
})();

function vsReload(){
  VS.mes=Number(el('vs-mes').value);
  VS.anio=Number(el('vs-anio').value);
  VS.filtro='all';
  document.querySelectorAll('.ftab').forEach(function(t){t.classList.toggle('act',t.getAttribute('data-f')==='all');});
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  var nom=(ctx.asesor||'').toUpperCase();
  var idAs=ctx.idAsesor||'';
  if(!nom){el('vs-fact').textContent='Sin sesion';return;}
  _rpc('aos_ventas_asesor',{p_asesor:nom,p_id_asesor:idAs,p_mes:VS.mes,p_anio:VS.anio},function(d){
    if(!d){el('vs-fact').textContent='Error';return;}
    VS.data=d;
    renderKPIs(d);
    renderDetalle(d.detalle||[], 'all');
    renderSedes(d.porSede||[]);
    renderHistorial(d.anual||[]);
    renderTop(d.topClientes||[]);
  });
}

function renderKPIs(d){
  el('vs-fact').textContent='S/'+parseFloat(d.factTotal||0).toFixed(2);
  el('vs-nv').textContent=d.nVentas||0;
  el('vs-ticket').textContent='S/'+parseFloat(d.ticketProm||0).toFixed(0);
  el('vs-nserv').textContent=d.nServ||0;
  el('vs-fserv').textContent='S/'+parseFloat(d.factServ||0).toFixed(0);
  el('vs-nprod').textContent=d.nProd||0;
  el('vs-fprod').textContent='S/'+parseFloat(d.factProd||0).toFixed(0);
}

function renderDetalle(rows, filtro){
  var filtered=filtro==='all'?rows:rows.filter(function(r){return(r.tipo||'')==filtro;});
  var tb=el('vs-tbody');
  if(!filtered.length){tb.innerHTML='<tr><td colspan="6" class="ld">Sin ventas</td></tr>';el('vs-tfact').textContent='S/0';el('vs-tcom').textContent='S/0';return;}
  var totFact=0, totCom=0;
  tb.innerHTML=filtered.map(function(v){
    var m=parseFloat(v.monto||0); var c=parseFloat(v.comision||0);
    totFact+=m; totCom+=c;
    var cli=((v.nombres||'')+' '+(v.apellidos||'')).trim();
    var cls=(v.tipo||'')==='PRODUCTO'?'tb-prod':'tb-serv';
    return '<tr><td style="color:#6B7BA8;white-space:nowrap;">'+h(v.fecha||'')+'</td>'+
      '<td><div style="font-weight:700;font-size:11px;">'+h((cli||v.numero_limpio||'--').substring(0,22))+'</div>'+
      '<div style="font-size:9px;color:#9AAAC8;">'+h(v.numero_limpio||'')+'</div></td>'+
      '<td style="font-size:10px;color:#6B7BA8;">'+h((v.tratamiento||'').substring(0,18))+'</td>'+
      '<td style="font-weight:700;color:#0D1B3E;">S/'+m.toFixed(2)+'</td>'+
      '<td><span class="com-v">S/'+c.toFixed(2)+'</span></td>'+
      '<td><span class="tipo-b '+cls+'">'+((v.tipo||'')==='PRODUCTO'?'PROD':'SERV')+'</span></td></tr>';
  }).join('');
  el('vs-tfact').textContent='S/'+totFact.toFixed(2);
  el('vs-tcom').textContent='S/'+totCom.toFixed(2);
}

function vsFilter(btn){
  document.querySelectorAll('.ftab').forEach(function(t){t.classList.remove('act');});
  btn.classList.add('act');
  VS.filtro=btn.getAttribute('data-f');
  if(VS.data)renderDetalle(VS.data.detalle||[], VS.filtro);
}

function renderSedes(sedes){
  var box=el('vs-sedes');
  if(!sedes.length){box.innerHTML='<div class="ld">Sin datos</div>';return;}
  box.innerHTML=sedes.map(function(s){
    return '<div class="sede-card"><div class="sede-card-lbl">'+h(s.sede||'Sin sede')+'</div><div class="sede-card-val">S/'+parseFloat(s.total||0).toFixed(0)+'</div></div>';
  }).join('');
}

function renderHistorial(anual){
  var hb=el('vs-hist');
  if(!anual.length){hb.innerHTML='<tr><td colspan="5" class="ld">Sin historial</td></tr>';return;}
  hb.innerHTML=anual.map(function(row){
    var mn=parseInt(row.mes_num); var cur=mn===VS.mes;
    var f=parseFloat(row.facturado||0);
    var cs=parseFloat(row.com_serv||0);
    var cp=parseFloat(row.com_prod||0);
    var ct=cs+cp;
    return '<tr'+(cur?' class="cur"':'')+'><td style="font-weight:'+(cur?'700':'500')+';">'+h(MF[mn]||'')+'</td>'+
      '<td>S/'+f.toFixed(0)+'</td><td>S/'+cs.toFixed(2)+'</td><td>S/'+cp.toFixed(2)+'</td>'+
      '<td style="font-weight:700;color:#16A34A;">S/'+ct.toFixed(2)+'</td></tr>';
  }).join('');
}

function renderTop(tops){
  var box=el('vs-top');
  if(!tops.length){box.innerHTML='<div class="ld">Sin clientes</div>';return;}
  var medals=['\uD83E\uDD47','\uD83E\uDD48','\uD83E\uDD49','4','5'];
  box.innerHTML=tops.map(function(cl,i){
    var wa='https://wa.me/51'+(cl.num||'').replace(/[^0-9]/g,'');
    return '<div class="top-row"><div class="top-rank">'+(medals[i]||String(i+1))+'</div>'+
      '<div class="top-info"><div class="top-nom">'+h((cl.cliente||'').substring(0,22))+'</div>'+
      '<div class="top-met">'+h(cl.num||'')+' &middot; '+h(cl.ult_fecha||'')+'</div></div>'+
      '<div class="top-fact">S/'+parseFloat(cl.total||0).toFixed(2)+'</div>'+
      '<div class="wa-sm" onclick="window.open(\''+wa+'\',\'_blank\')">WA</div></div>';
  }).join('');
}
