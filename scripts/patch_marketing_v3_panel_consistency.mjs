import fs from 'node:fs';

const path = 'app/public/admin-marketing-v2.js';
let src = fs.readFileSync(path, 'utf8');
const marker = 'ASCENDA_MARKETING_V3_CONSISTENCY_PATCH_20260812';
if (src.includes(marker)) {
  console.log('Marketing consistency patch already present.');
  process.exit(0);
}

const patch = `

/* ${marker}
 * Stabilizes annual History/LTV during month changes, uses the fast attribution gateway,
 * and adds masked client-level audit detail to Intent -> Purchase.
 */
(function(){
  if(window.__AOS_MARKETING_V3_CONSISTENCY_PATCH)return;
  window.__AOS_MARKETING_V3_CONSISTENCY_PATCH=true;

  var lastAttr=null,lastIntent=[],lastDetail=[];
  function byId(x){return document.getElementById(x);}
  function num(v){return Number(v)||0;}
  function money(v){return 'S/'+Math.round(num(v)).toLocaleString('es-PE');}
  function esc(v){return String(v==null?'':v).replace(/[&<>\"']/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',\"'\":'&#39;'}[c];});}
  function rpc(fn,p){return fetch(SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json'},body:JSON.stringify(p||{})}).then(function(r){if(!r.ok)return r.text().then(function(t){throw new Error(fn+' HTTP '+r.status+' '+t.slice(0,180));});return r.json();});}
  function current(){var a=Number(byId('mk-anio').value),m=Number(byId('mk-mes').value);return{anio:a,mes:m};}

  function renderAttrFast(s){
    if(!s||typeof s!=='object'||MK.modo!=='mes')return;
    lastAttr=s;
    var b=byId('mk-v3-attr');if(!b)return;
    var items=[
      [num(s.personasUnicas),'PERSONAS ÚNICAS','#0A4FBF'],
      [num(s.touchpointsEfectivos),'TOUCHPOINTS EFECTIVOS','#0D9488'],
      [num(s.duplicadosTecnicosProbables),'DUPLICADOS TÉCNICOS','#DC2626'],
      [num(s.reingresosProspectoHistorico),'REINGRESOS PROSPECTO','#7C3AED'],
      [num(s.reingresosProspectoMismoMes),'REINGRESOS MISMO MES','#7C3AED'],
      [num(s.reingresosClienteExistente),'CLIENTES QUE REINGRESAN','#D97706'],
      [num(s.clientesAdquiridosM0),'CLIENTES M0','#059669'],
      [num(s.reactivacionesConfirmadas),'REACTIVACIONES CONF.','#00C9A7'],
      [money(s.revenueReactivacion),'REV. REACTIVACIÓN','#00A67E'],
      [num(s.operacionesSeguimiento),'OPS. SEGUIMIENTO','#4B5D82'],
      [num(s.anomaliasHigh),'REVISIÓN ALTA','#DC2626'],
      [num(s.anomaliasMedium),'REVISIÓN MEDIA','#D97706']
    ];
    b.innerHTML='<div class="g-row">'+items.map(function(x){return '<div class="g-c" style="background:#F8FAFF;border:1px solid #EEF2F8;"><div class="g-v" style="color:'+x[2]+'">'+x[0]+'</div><div class="g-l">'+x[1]+'</div></div>';}).join('')+'</div><div style="font-size:8px;color:#6B7BA8;margin-top:7px;line-height:1.5;"><b>Lectura:</b> reingreso no equivale automáticamente a reactivación. Reactivación exige compra previa + nuevo touchpoint + conversión atribuible. Clientes M0 son personas únicas con compra atribuida dentro del mes seleccionado.</div>';
  }

  function loadAttrFast(){
    if(MK.modo!=='mes')return;
    var r=current();
    rpc('aos_marketing_attribution_public_v3',{p_mes:r.mes,p_anio:r.anio}).then(renderAttrFast).catch(function(e){console.warn('[MKT V3.1] Atribución fast:',e.message);});
  }

  function renderIntentAudit(){
    if(MK.modo!=='mes')return;
    var b=byId('mk-v3-intent');if(!b)return;
    var rows=Array.isArray(lastIntent)?lastIntent:[],detail=Array.isArray(lastDetail)?lastDetail:[];
    if(!rows.length){b.innerHTML='<div class="ld">Sin compras atribuibles para esta cohorte.</div>';return;}
    var agg='<div style="overflow:auto;max-height:220px;"><table class="vt"><thead><tr><th>INTENCIÓN</th><th>COMPRA REAL</th><th>CLIENTES</th><th>OPS.</th><th>FACT.</th><th>% DEL INTERÉS</th></tr></thead><tbody>'+rows.map(function(r){return '<tr><td style="font-weight:700;">'+esc(r.tratamiento_interes)+'</td><td>'+esc(r.tratamiento_compra)+'</td><td>'+num(r.clientes)+'</td><td>'+num(r.operaciones)+'</td><td class="hi hi-g">'+money(r.facturacion)+'</td><td style="font-weight:700;color:'+(r.coincide_intencion?'#059669':'#6B7BA8')+';">'+num(r.porcentaje_facturacion_intencion).toFixed(1)+'%</td></tr>';}).join('')+'</tbody></table></div>';
    var det='';
    if(detail.length){
      det='<div id="mk-v4-intent-detail" style="margin-top:10px;border-top:1px solid #EEF2F8;padding-top:8px;"><div style="font-size:9px;font-weight:800;color:#1F2A44;margin-bottom:6px;">Auditoría por cliente <span style="font-weight:500;color:#7B8AAA;">— nombre, lead y líneas de compra</span></div><div style="overflow:auto;max-height:250px;"><table class="vt"><thead><tr><th>CLIENTE</th><th>LEAD / ANUNCIO</th><th>COMPRA / DETALLE</th><th>OPS.</th><th>FACT.</th></tr></thead><tbody>'+detail.map(function(d){var phone=d.telefono_ult4?'•••• '+esc(d.telefono_ult4):'—',ops=num(d.operaciones),badge=ops>1?'<span class="tag" style="background:#FFF7ED;color:#D97706;">'+ops+' ops</span>':String(ops);return '<tr title="'+esc(d.venta_ids||'')+'"><td><b>'+esc(d.cliente||'SIN NOMBRE')+'</b><div style="font-size:7px;color:#9AAAC8;">'+phone+'</div></td><td><b>#'+esc(d.lead_id)+'</b> · '+esc(d.lead_fecha)+'<div style="font-size:7px;color:#6B7BA8;max-width:180px;white-space:normal;">'+esc(d.lead_anuncio||'—')+'</div></td><td><b>'+esc(d.tratamiento_compra)+'</b><div style="font-size:7px;color:#6B7BA8;max-width:240px;white-space:normal;">'+esc(d.descripciones||'—')+'</div></td><td>'+badge+'</td><td class="hi hi-g">'+money(d.facturacion)+'</td></tr>';}).join('')+'</tbody></table></div><div style="font-size:8px;color:#6B7BA8;margin-top:6px;line-height:1.45;">Una persona puede aparecer en más de una fila si compró tipos distintos. <b>OPS.</b> cuenta líneas de venta; no se eliminan como duplicadas automáticamente. Pasa el cursor por una fila para ver sus Venta ID.</div></div>';
    }
    b.innerHTML=agg+det+'<div style="font-size:8px;color:#6B7BA8;margin-top:7px;line-height:1.5;">Intención = tratamiento del lead. Compra real = líneas de venta atribuidas a ese lead. El teléfono se muestra solo con los últimos 4 dígitos.</div>';
  }

  function loadIntentAudit(){
    if(MK.modo!=='mes')return;
    var r=current();
    rpc('aos_marketing_intent_public_v2',{p_mes:r.mes,p_anio:r.anio}).then(function(x){lastIntent=Array.isArray(x)?x:[];renderIntentAudit();}).catch(function(e){console.warn('[MKT V3.1] Intent agregado:',e.message);});
    rpc('aos_marketing_intent_detail_public_v3',{p_mes:r.mes,p_anio:r.anio}).then(function(x){lastDetail=Array.isArray(x)?x:[];renderIntentAudit();}).catch(function(e){console.warn('[MKT V3.1] Intent detalle:',e.message);});
  }

  function clarifyFunnel(){
    var e=byId('mk-emb');if(!e)return;
    var note=byId('mk-v4-funnel-note');if(!note){note=document.createElement('div');note.id='mk-v4-funnel-note';note.style.cssText='font-size:8px;color:#6B7BA8;margin-top:5px;line-height:1.4;';e.appendChild(note);}note.innerHTML='<b>Nota:</b> “Ventas” representa operaciones, no personas. Por eso el último ratio puede superar 100%; léelo como operaciones por cliente, no como conversión de personas.';
  }

  // Once V3 is active, never allow delayed legacy callbacks to shrink the annual History/LTV views.
  window.rHist=function(){return;};
  window.rLTV=function(){return;};

  var previousMkL=window.mkL;
  window.mkL=function(){
    var out=previousMkL.apply(this,arguments);
    setTimeout(loadAttrFast,80);
    setTimeout(loadIntentAudit,120);
    setTimeout(clarifyFunnel,250);
    setTimeout(loadAttrFast,1300);
    setTimeout(loadIntentAudit,1500);
    return out;
  };

  var observer=new MutationObserver(function(){
    if(MK.modo!=='mes')return;
    var a=byId('mk-v3-attr');
    if(lastAttr&&a&&/temporalmente no disponible/i.test(a.textContent||''))renderAttrFast(lastAttr);
    var i=byId('mk-v3-intent');
    if(lastIntent.length&&lastDetail.length&&i&&!byId('mk-v4-intent-detail'))renderIntentAudit();
  });
  observer.observe(document.body,{childList:true,subtree:true});

  setTimeout(function(){loadAttrFast();loadIntentAudit();clarifyFunnel();},350);
  setTimeout(function(){loadAttrFast();loadIntentAudit();clarifyFunnel();},1800);
  console.log('[ASCENDA] Marketing V3.1 consistency patch active');
})();
`;

src += patch;
fs.writeFileSync(path, src, 'utf8');
console.log('Appended Marketing V3 consistency patch.');
