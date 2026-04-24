// commissions.js — Panel Comisiones Asesor | AscendaOS v1 | 100% Supabase
var _SB='https://ituyqwstonmhnfshnaqz.supabase.co';
var _SK='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0';

function _rpc(fn,p,ok,fail){
  fetch(_SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':_SK,'Authorization':'Bearer '+_SK,'Content-Type':'application/json'},body:JSON.stringify(p||{})})
  .then(function(r){return r.json();}).then(ok||function(){}).catch(fail||function(e){console.error('[SB]',fn,e);});
}

var MEDALS=['','#1','#2','#3','#4','#5'];
var MF=['','Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
var VCom={mes:new Date().getMonth()+1, anio:new Date().getFullYear()};

function h(s){var o=String(s||'');o=o.split('&').join('&amp;');o=o.split(String.fromCharCode(60)).join('&lt;');o=o.split('>').join('&gt;');o=o.split('"').join('&quot;');return o;}
function el(id){return document.getElementById(id);}

// Init
(function(){
  var mSel=el('mes-sel');
  if(mSel)mSel.value=String(VCom.mes);
  var aSel=el('anio-sel');
  if(aSel)aSel.value=String(VCom.anio);
  reload();
})();

function reload(){
  VCom.mes=Number(el('mes-sel').value);
  VCom.anio=Number(el('anio-sel').value);
  var ctx=(window.AOS_getCtx&&window.AOS_getCtx())||{};
  var nom=(ctx.asesor||'').toUpperCase();
  var idAs=ctx.idAsesor||'';
  if(!nom){
    el('h-com-total').textContent='Sin sesion';
    return;
  }
  _rpc('aos_comisiones_asesor',{p_asesor:nom,p_id_asesor:idAs,p_mes:VCom.mes,p_anio:VCom.anio},function(d){
    if(!d){el('h-com-total').textContent='Sin datos';return;}
    renderData(d);
  });
}

function renderData(d){
  var comT=parseFloat(d.comTotal||0);
  var comS=parseFloat(d.comServ||0);
  var comP=parseFloat(d.comProd||0);
  var factT=parseFloat(d.factTotal||0);
  var meta=parseFloat(d.meta||100);
  var pct=parseFloat(d.pct||0);
  var rank=parseInt(d.ranking||1);
  var nv=parseInt(d.nVentas||0);
  var ns=parseInt(d.nServ||0);
  var np=parseInt(d.nProd||0);

  // Hero KPIs
  el('h-com-total').textContent='S/. '+comT.toFixed(2);
  el('h-com-meta').textContent='Meta: S/. '+meta.toFixed(2)+' | Fact. S/. '+factT.toFixed(2);
  el('h-com-prog').style.width=Math.min(pct,100)+'%';
  el('h-com-pct').textContent=pct.toFixed(1)+'% completado';
  el('h-com-rank').textContent='Rank #'+rank;

  el('h-com-serv').textContent='S/. '+comS.toFixed(2);
  el('h-com-serv-sub').textContent=ns+' vta'+((ns!==1)?'s':'')+' | fact S/'+factT.toFixed(0)+' x 0.5%';
  el('h-com-prod').textContent='S/. '+comP.toFixed(2);
  el('h-com-prod-sub').textContent=np+' vta'+((np!==1)?'s':'')+' | tabla de rangos';

  // Ranking
  var medalEmoji=rank===1?'\uD83E\uDD47':rank===2?'\uD83E\uDD48':rank===3?'\uD83E\uDD49':'\uD83C\uDFC5';
  el('h-rank-emoji').textContent=medalEmoji;
  el('h-rank-pos').textContent='#'+rank;

  // Delta vs mes anterior
  var anual=d.anual||[];
  var prevMes=anual.find(function(a){return parseInt(a.mes_num)===(VCom.mes-1);});
  var dEl=el('h-delta');
  if(prevMes&&parseFloat(prevMes.comision)>0){
    var prevCom=parseFloat(prevMes.comision);
    var delta=((comT-prevCom)/prevCom*100);
    var up=delta>=0;
    dEl.textContent='vs mes anterior: '+(up?'+':'')+delta.toFixed(1)+'%';
    dEl.className='delta-chip '+(up?'delta-up':'delta-dn');
  } else {
    dEl.textContent='vs mes anterior: --';
    dEl.className='delta-chip delta-n';
  }

  // Historial anual
  var hb=el('hist-body');
  if(anual.length){
    hb.innerHTML=anual.map(function(row){
      var mn=parseInt(row.mes_num);
      var cur=mn===VCom.mes;
      var fact=parseFloat(row.facturado||0);
      var cs=parseFloat(row.com_serv||0);
      var cp=parseFloat(row.com_prod||0);
      var ct=parseFloat(row.comision||0);
      return '<tr'+(cur?' class="cur"':'')+'>'+'<td style="font-weight:'+(cur?'700':'500')+';">'+h(MF[mn]||'')+'</td>'+'<td>S/'+fact.toFixed(2)+'</td>'+'<td>S/'+cs.toFixed(2)+'</td>'+'<td>S/'+cp.toFixed(2)+'</td>'+'<td style="font-weight:700;color:#0A4FBF;">S/'+ct.toFixed(2)+'</td>'+'</tr>';
    }).join('');
  } else {
    hb.innerHTML='<tr><td colspan="5" class="ld">Sin historial</td></tr>';
  }

  // Top clientes
  var tops=d.topClientes||[];
  var tcEl=el('top-clientes');
  if(tops.length){
    tcEl.innerHTML=tops.map(function(cl,i){
      var medal=i===0?'\uD83E\uDD47':i===1?'\uD83E\uDD48':i===2?'\uD83E\uDD49':String(i+1);
      var wa='https://api.whatsapp.com/send?phone=51'+(cl.num||'').replace(/[^0-9]/g,'');
      var nom=h(((cl.cliente||cl.num||'--')).substring(0,25));
      var f=parseFloat(cl.total||0);
      return '<div class="top-row">'+'<div class="top-rank">'+medal+'</div>'+'<div class="top-info"><div class="top-nom">'+nom+'</div>'+'<div class="top-met">'+h(cl.num||'')+' - '+(cl.compras||0)+' compras - ult: '+(cl.ult_fecha||'')+'</div></div>'+'<div class="top-fact">S/'+f.toFixed(2)+'</div>'+'<div class="wa-sm" onclick="window.open(\''+wa+'\',\'_blank\')">WA</div>'+'</div>';
    }).join('');
  } else {
    tcEl.innerHTML='<div class="ld">Sin clientes</div>';
  }

  // Detalle ventas
  var det=d.detalle||[];
  el('det-count').textContent=det.length+' venta'+(det.length!==1?'s':'');
  var db=el('det-body');
  if(det.length){
    db.innerHTML=det.map(function(v){
      var com=parseFloat(v.comision_calculada||0);
      var monto=parseFloat(v.monto||0);
      var cls=(v.tipo||'')==='PRODUCTO'?'tb-prod':'tb-serv';
      var cliente=((v.nombres||'')+' '+(v.apellidos||'')).trim();
      return '<tr>'+'<td style="color:#6B7BA8;">'+h(v.fecha||'')+'</td>'+'<td><div style="font-weight:700;font-size:11px;">'+h((cliente||v.numero_limpio||'--').substring(0,22))+'</div>'+'<div style="font-size:10px;color:#9AAAC8;">'+h(v.numero_limpio||'')+'</div></td>'+'<td style="font-size:10px;color:#6B7BA8;">'+h((v.tratamiento||'').substring(0,18))+'</td>'+'<td style="font-weight:700;font-size:12px;color:#0D1B3E;">S/'+monto.toFixed(2)+'</td>'+'<td><span class="com-v">S/'+com.toFixed(2)+'</span></td>'+'<td><span class="tipo-b '+cls+'">'+((v.tipo||'')==='PRODUCTO'?'PROD':'SERV')+'</span></td>'+'</tr>';
    }).join('');
  } else {
    db.innerHTML='<tr><td colspan="6" class="ld">Sin ventas</td></tr>';
  }

  // Ranking mini (otros asesores)
  loadRankingMini();
}

function loadRankingMini(){
  var mesI=VCom.anio+'-'+String(VCom.mes).padStart(2,'0')+'-01';
  var mesFin=VCom.anio+'-'+String(VCom.mes).padStart(2,'0')+'-31';
  fetch(_SB+'/rest/v1/aos_ventas?select=asesor,monto,tipo&fecha=gte.'+mesI+'&fecha=lte.'+mesFin+'&asesor=not.in.(NO+APLICA,DRA+CAROLINA,DRA+YESSICA,VINO+SOLA(O))',{
    headers:{'apikey':_SK,'Authorization':'Bearer '+_SK}
  }).then(function(r){return r.json();}).then(function(rows){
    if(!rows||!rows.length){el('h-rank-mini').innerHTML='Sin datos';return;}
    var by={};
    rows.forEach(function(v){
      var a=v.asesor||'';if(!a)return;
      if(!by[a])by[a]={fact:0,com:0};
      var m=parseFloat(v.monto||0);
      by[a].fact+=m;
      if(v.tipo==='SERVICIO')by[a].com+=Math.round(m*0.005*100)/100;
      else if(v.tipo==='PRODUCTO'){
        var c=0;if(m>=201)c=6;else if(m>=149)c=5;else if(m>=101)c=4;else if(m>=51)c=3;else if(m>=18)c=1;else c=0.3;
        by[a].com+=c;
      }
    });
    var arr=Object.keys(by).map(function(a){return{asesor:a,com:by[a].com,fact:by[a].fact};});
    arr.sort(function(a,b){return b.com-a.com;});
    var html=arr.slice(0,5).map(function(r,i){
      var medal=i===0?'\uD83E\uDD47':i===1?'\uD83E\uDD48':i===2?'\uD83E\uDD49':'#'+(i+1);
      return '<div style="display:flex;align-items:center;justify-content:space-between;padding:3px 0;">'+'<span style="font-size:11px;">'+medal+' '+h(r.asesor.split(' ')[0])+'</span>'+'<span style="font-weight:800;font-size:12px;color:#0A4FBF;">S/'+r.com.toFixed(2)+'</span>'+'</div>';
    }).join('');
    el('h-rank-mini').innerHTML=html;
  }).catch(function(){el('h-rank-mini').innerHTML='Error';});
}
