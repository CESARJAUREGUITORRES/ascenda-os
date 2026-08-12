/* ASCENDA OS — Marketing Attribution V2 UI adapter
 * Loads after admin-marketing.html legacy inline code.
 * Keeps existing layout and replaces only validated V2 reporting blocks.
 */
(function(){
  if(window.__AOS_MARKETING_V2_LOADED)return;
  window.__AOS_MARKETING_V2_LOADED=true;

  var orig={
    mkL:window.mkL,
    rKPI:window.rKPI,
    rEmb:window.rEmb,
    rHist:window.rHist,
    rLTV:window.rLTV,
    rAn:window.rAn,
    rCamp:window.rCamp,
    ldRender:window.ldRender,
    openLeadsModal:window.openLeadsModal,
    ldRng:window.ldRng,
    ldExport:window.ldExport
  };
  var legacyCache={kpi:null,emb:null,hist:null,an:null,camp:null};
  var V2={periodos:[],leadPage:1,leadSize:50,leadTotal:0,leadRows:[],leadSummary:null,searchTimer:null};

  function vrpc(fn,p){
    return fetch(SB+'/rest/v1/rpc/'+fn,{
      method:'POST',
      headers:{'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json'},
      body:JSON.stringify(p||{})
    }).then(function(r){
      if(!r.ok)return r.text().then(function(t){throw new Error(fn+' HTTP '+r.status+' '+t.slice(0,180));});
      return r.json();
    });
  }
  function n(v){return Number(v)||0;}
  function money(v){return 'S/'+Math.round(n(v)).toLocaleString('es-PE');}
  function esc(s){return h(s==null?'':String(s));}

  /* Capture legacy responses so a V2 RPC failure can fall back safely. */
  window.rHist=function(d){legacyCache.hist=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rHist)orig.rHist(d);};
  window.rLTV=function(k,hi,d){if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rLTV)orig.rLTV(k,hi,d);};
  window.rKPI=function(d){legacyCache.kpi=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rKPI)orig.rKPI(d);};
  window.rEmb=function(d){legacyCache.emb=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rEmb)orig.rEmb(d);};
  window.rAn=function(d){legacyCache.an=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rAn)orig.rAn(d);};
  window.rCamp=function(d){legacyCache.camp=d;if(!window.__AOS_MARKETING_V2_ACTIVE&&orig.rCamp)orig.rCamp(d);};
  window.__AOS_MARKETING_V2_ACTIVE=true;

  function ensureSummary(){
    if(document.getElementById('mk-v2-summary'))return document.getElementById('mk-v2-summary');
    var gest=document.getElementById('mk-gest');if(!gest)return null;
    var card=document.createElement('div');
    card.id='mk-v2-summary';
    card.className='crd';
    card.style.padding='9px 12px';
    card.innerHTML='<div class="ct" style="margin-bottom:6px;">🧭 Trazabilidad V2 <span class="tag tag-b">personas + touchpoints</span></div><div id="mk-v2-summary-grid" class="g-row"><div class="ld">Cargando...</div></div>';
    gest.insertAdjacentElement('afterend',card);
    return card;
  }
  function renderSummary(s){
    ensureSummary();var box=document.getElementById('mk-v2-summary-grid');if(!box)return;
    var rePros=n(s.reingresosProspectoHistorico)+n(s.reingresosProspectoMismoMes);
    var cards=[
      {v:n(s.personasUnicas),l:'PERSONAS ÚNICAS',c:'g-blue'},
      {v:n(s.touchpointsEfectivos),l:'TOUCHPOINTS',c:'g-cyan'},
      {v:n(s.duplicadosTecnicosProbables),l:'DUP. TÉCNICOS',c:'g-yellow'},
      {v:rePros,l:'REING. PROSPECTO',c:'g-purple'},
      {v:n(s.reingresosClienteExistente),l:'REING. CLIENTE',c:'g-green'},
      {v:n(s.reactivacionesConfirmadas),l:'REACTIVACIONES',c:'g-green'}
    ];
    box.innerHTML=cards.map(function(x){return '<div class="g-c '+x.c+'"><div class="g-v">'+x.v+'</div><div class="g-l">'+x.l+'</div></div>';}).join('');
  }

  function mapHist(rows){
    return (rows||[]).map(function(x){return{
      mes:x.mes,anio:x.anio,
      leads:n(x.personas_unicas),
      llamados:n(x.leads_gestionados),
      citas:n(x.citas_atribuidas),
      asistieron:n(x.asistencias_atribuidas),
      clientes:n(x.clientes_m0),
      ventas:n(x.ventas_m0),
      fact:n(x.fact_m0),
      fact_acumulado:n(x.fact_acumulado),
      conv:n(x.conversion_m0)
    };});
  }

  function loadInvestment(anio,mes){
    var q=SB+'/rest/v1/aos_inversion_campanas?select=inversion&anio=eq.'+encodeURIComponent(anio);
    if(mes!=null)q+='&mes_num=eq.'+encodeURIComponent(mes);
    return fetch(q,{headers:{'apikey':SK,'Authorization':'Bearer '+SK}}).then(function(r){if(!r.ok)throw new Error('investment HTTP '+r.status);return r.json();}).then(function(rows){return (Array.isArray(rows)?rows:[]).reduce(function(s,x){return s+n(x.inversion);},0);});
  }

  function renderTopV2(rows,inv){
    rows=rows||[];var src;
    if(MK.modo==='mes'){
      var m=Number(document.getElementById('mk-mes').value);src=rows.filter(function(x){return n(x.mes)===m;})[0]||{};
    }else{
      src=rows.reduce(function(a,x){
        a.personas_unicas+=n(x.personas_unicas);a.leads_gestionados+=n(x.leads_gestionados);a.llamadas_atribuidas+=n(x.llamadas_atribuidas);
        a.leads_con_cita+=n(x.leads_con_cita);a.leads_con_asistencia+=n(x.leads_con_asistencia);a.clientes_m0+=n(x.clientes_m0);a.ventas_m0+=n(x.ventas_m0);
        a.fact_m0+=n(x.fact_m0);a.fact_acumulado+=n(x.fact_acumulado);return a;
      },{personas_unicas:0,leads_gestionados:0,llamadas_atribuidas:0,leads_con_cita:0,leads_con_asistencia:0,clientes_m0:0,ventas_m0:0,fact_m0:0,fact_acumulado:0});
    }
    var leads=n(src.personas_unicas),ll=n(src.leads_gestionados),citas=n(src.leads_con_cita),asist=n(src.leads_con_asistencia),cli=n(src.clientes_m0),ventas=n(src.ventas_m0),fact=n(src.fact_m0),factAc=n(src.fact_acumulado),inversion=n(inv);
    var k={leads:leads,llamados:ll,llamadasTotal:n(src.llamadas_atribuidas),citas:citas,asistieron:asist,clientes:cli,nVentas:ventas,factTotal:fact,factAcumulado:factAc,invTotal:inversion,
      roas:inversion>0?fact/inversion:null,cac:cli>0&&inversion>0?inversion/cli:null,pctLlamados:leads>0?ll/leads*100:0,cpl:leads>0&&inversion>0?inversion/leads:null,ltvMultiplier:fact>0?factAc/fact:null};
    var tasas={llamados:leads>0?ll/leads*100:0,citas:ll>0?citas/ll*100:0,asist:citas>0?asist/citas*100:0,clientes:asist>0?cli/asist*100:0,ventas:cli>0?ventas/cli*100:0};
    if(orig.rKPI)orig.rKPI(k);
    if(orig.rEmb)orig.rEmb({leads:leads,llamados:ll,citas:citas,asistieron:asist,clientes:cli,ventas:ventas,factTotal:fact,tasas:tasas});
  }

  function renderLtvV2(rows){
    var box=document.getElementById('mk-ltv');if(!box)return;
    rows=rows||[];
    var tag=document.getElementById('mk-ltv-tag');if(tag)tag.textContent='Attribution V2 · '+rows.length+' cohortes';
    if(!rows.length){box.innerHTML='<div class="ld">Sin cohortes V2</div>';return;}
    var totInv=rows.reduce(function(s,r){return s+n(r.inversion);},0);
    var totLtv=rows.reduce(function(s,r){return s+n(r.ltv_total);},0);
    var totAdq=rows.reduce(function(s,r){return s+n(r.clientes_adquiridos);},0);
    var roas=totInv>0?totLtv/totInv:0;
    var html='<div class="g-row" style="margin-bottom:10px;">'+
      '<div class="g-c g-blue"><div class="g-v">'+totAdq+'</div><div class="g-l">CLIENTES ADQUIRIDOS</div></div>'+
      '<div class="g-c g-purple"><div class="g-v">'+money(totInv)+'</div><div class="g-l">INVERSIÓN</div></div>'+
      '<div class="g-c g-green"><div class="g-v">'+money(totLtv)+'</div><div class="g-l">LTV ATRIBUIDO</div></div>'+
      '<div class="g-c g-cyan"><div class="g-v">'+(roas?roas.toFixed(2)+'x':'—')+'</div><div class="g-l">ROAS LTV</div></div></div>';
    html+='<div style="overflow-x:auto;"><table class="vt"><thead><tr><th>COHORTE</th><th>PERSONAS</th><th>ADQ.</th><th>INV.</th><th style="color:#0A4FBF">M0</th><th style="color:#00C9A7">M+1</th><th style="color:#7C3AED">M+2</th><th style="color:#D97706">M+3</th><th>M+4</th><th style="color:#059669">LTV TOTAL</th><th>CAC</th><th>ROAS M0</th><th>ROAS LTV</th></tr></thead><tbody>';
    html+=rows.map(function(r){
      function cv(v,state){if(v===null||v===undefined)return '<span style="color:#CBD5E1">—</span>';var st=state==='PARTIAL'?' <span style="font-size:6px;color:#D97706">PARCIAL</span>':'';return money(v)+st;}
      return '<tr><td class="hi">'+MF[n(r.mes)].slice(0,3).toUpperCase()+' '+r.anio+'</td><td>'+n(r.personas_unicas)+'</td><td class="hi hi-g">'+n(r.clientes_adquiridos)+'</td><td>'+money(r.inversion)+'</td><td class="hi hi-b">'+cv(r.m0,r.m0_estado)+'</td><td>'+cv(r.m1,r.m1_estado)+'</td><td>'+cv(r.m2,r.m2_estado)+'</td><td>'+cv(r.m3,r.m3_estado)+'</td><td>'+cv(r.m4plus,'')+'</td><td class="hi hi-g">'+money(r.ltv_total)+'</td><td>'+(r.cac_adquisicion==null?'—':money(r.cac_adquisicion))+'</td><td>'+(r.roas_m0==null?'—':Number(r.roas_m0).toFixed(2)+'x')+'</td><td class="hi hi-c">'+(r.roas_ltv==null?'—':Number(r.roas_ltv).toFixed(2)+'x')+'</td></tr>';
    }).join('');
    html+='</tbody></table></div><div style="margin-top:7px;font-size:8px;color:#6B7BA8;">M0 = mes del touchpoint de adquisición. Las compras posteriores del cliente adquirido permanecen en el LTV de su cohorte; reactivación se mide por separado.</div>';
    box.innerHTML=html;
  }

  function mapAds(rows){return (rows||[]).map(function(a){return{
    nombre:a.anuncio,leads:n(a.touchpoints_efectivos),citas:n(a.leads_con_cita),asistieron:n(a.leads_con_asistencia),
    clientes:n(a.clientes_m0),ventas:n(a.ventas_m0),fact_mes:n(a.fact_m0),clientes_fuera:n(a.clientes_post),
    ventas_fuera:n(a.ventas_post),fact_acum:n(a.fact_acum)
  };});}
  function mapCamp(rows){return (rows||[]).map(function(t){return{
    nombre:t.tratamiento,leads:n(t.touchpoints_efectivos),citas:n(t.leads_con_cita),pctCita:n(t.touchpoints_efectivos)>0?(n(t.leads_con_cita)/n(t.touchpoints_efectivos)*100).toFixed(1):0,
    asistieron:n(t.leads_con_asistencia),clientes:n(t.clientes_m0),ventas:n(t.ventas_m0),fact_mes:n(t.fact_m0),fact_acum:n(t.fact_acum),
    inv:n(t.inversion),roas:t.roas_acum==null?null:Number(t.roas_acum)
  };});}

  function syncMonths(){
    var ys=Number(document.getElementById('mk-anio').value);var sel=document.getElementById('mk-mes');if(!sel||!V2.periodos.length)return;
    var allowed=V2.periodos.filter(function(p){return Number(p.anio)===ys;}).map(function(p){return Number(p.mes);});
    Array.from(sel.options).forEach(function(o){o.disabled=allowed.indexOf(Number(o.value))<0;});
    if(allowed.length&&allowed.indexOf(Number(sel.value))<0)sel.value=String(Math.max.apply(null,allowed));
  }
  function loadPeriodos(){
    return vrpc('aos_marketing_periodos_v2_preview',{}).then(function(rows){
      V2.periodos=Array.isArray(rows)?rows:[];var sel=document.getElementById('mk-anio');if(!sel)return;
      var cur=Number(sel.value)||new Date().getFullYear();var years=[];
      V2.periodos.forEach(function(p){var y=Number(p.anio);if(years.indexOf(y)<0)years.push(y);});years.sort(function(a,b){return b-a;});
      if(years.length){sel.innerHTML=years.map(function(y){return '<option value="'+y+'">'+y+'</option>';}).join('');sel.value=String(years.indexOf(cur)>=0?cur:years[0]);}
      syncMonths();
    }).catch(function(e){console.warn('[MKT-V2] periodos',e);});
  }

  function loadV2Blocks(){
    var anio=Number(document.getElementById('mk-anio').value);var mes=Number(document.getElementById('mk-mes').value);
    syncMonths();
    var histP=vrpc('aos_marketing_historico_v2_preview',{p_anio:anio});
    histP.then(function(rows){if(orig.rHist)orig.rHist(mapHist(rows));}).catch(function(e){console.warn('[MKT-V2] historico',e);if(legacyCache.hist&&orig.rHist)orig.rHist(legacyCache.hist);});
    Promise.all([histP,loadInvestment(anio,MK.modo==='mes'?mes:null)]).then(function(res){renderTopV2(res[0],res[1]);}).catch(function(e){console.warn('[MKT-V2] KPI/embudo',e);if(legacyCache.kpi&&orig.rKPI)orig.rKPI(legacyCache.kpi);if(legacyCache.emb&&orig.rEmb)orig.rEmb(legacyCache.emb);});
    vrpc('aos_marketing_cohortes_ltv_v2_preview',{p_anio:anio}).then(renderLtvV2).catch(function(e){console.warn('[MKT-V2] ltv',e);});
    if(MK.modo==='mes'){
      vrpc('aos_marketing_attribution_summary_v2_preview',{p_mes:mes,p_anio:anio}).then(renderSummary).catch(function(e){console.warn('[MKT-V2] summary',e);});
      vrpc('aos_marketing_anuncios_v2_preview',{p_mes:mes,p_anio:anio,p_search:null,p_limit:50,p_offset:0,p_order:'fact_acum'}).then(function(rows){if(orig.rAn)orig.rAn(mapAds(rows));}).catch(function(e){console.warn('[MKT-V2] ads',e);if(legacyCache.an&&orig.rAn)orig.rAn(legacyCache.an);});
      vrpc('aos_marketing_campanas_v2_preview',{p_mes:mes,p_anio:anio,p_search:null,p_limit:50,p_offset:0,p_order:'fact_acum'}).then(function(rows){if(orig.rCamp)orig.rCamp(mapCamp(rows));}).catch(function(e){console.warn('[MKT-V2] campaigns',e);if(legacyCache.camp&&orig.rCamp)orig.rCamp(legacyCache.camp);});
    } else {
      var sc=document.getElementById('mk-v2-summary');if(sc)sc.style.display='';
      vrpc('aos_marketing_attribution_summary_v2_anio_preview',{p_anio:anio}).then(renderSummary).catch(function(e){console.warn('[MKT-V2] annual summary',e);});
      vrpc('aos_marketing_anuncios_v2_anio_preview',{p_anio:anio,p_search:null,p_limit:200,p_offset:0,p_order:'fact_acum'}).then(function(rows){if(orig.rAn)orig.rAn(mapAds(rows));}).catch(function(e){console.warn('[MKT-V2] annual ads',e);if(legacyCache.an&&orig.rAn)orig.rAn(legacyCache.an);});
      vrpc('aos_marketing_campanas_v2_anio_preview',{p_anio:anio,p_search:null,p_limit:200,p_offset:0,p_order:'fact_acum'}).then(function(rows){if(orig.rCamp)orig.rCamp(mapCamp(rows));}).catch(function(e){console.warn('[MKT-V2] annual campaigns',e);if(legacyCache.camp&&orig.rCamp)orig.rCamp(legacyCache.camp);});
    }
  }

  window.mkL=function(){
    if(document.getElementById('mk-v2-summary'))document.getElementById('mk-v2-summary').style.display=MK.modo==='mes'?'':'none';
    if(orig.mkL)orig.mkL();
    loadV2Blocks();
  };

  /* ───── Ver Leads V2: SQL pagination + filtered summary ───── */
  function ensurePager(){
    var count=document.getElementById('ld-count');if(!count||document.getElementById('ld-v2-pager'))return;
    var p=document.createElement('div');p.id='ld-v2-pager';p.style.cssText='display:flex;align-items:center;gap:6px;margin-top:8px;justify-content:flex-end;font-size:9px;color:#6B7BA8;';
    p.innerHTML='<span>Filas</span><select id="ld-v2-size" class="ps" style="padding:4px 6px;font-size:9px" onchange="ldV2Size(this.value)"><option>25</option><option selected>50</option><option>100</option></select><button class="mbtn mbtn-c" style="padding:4px 9px" onclick="ldV2Prev()">←</button><span id="ld-v2-page">1 / 1</span><button class="mbtn mbtn-c" style="padding:4px 9px" onclick="ldV2Next()">→</button>';
    count.parentElement.appendChild(p);
  }
  function leadParams(){
    return{
      p_fecha_desde:document.getElementById('ld-desde').value,
      p_fecha_hasta:document.getElementById('ld-hasta').value,
      p_search:(document.getElementById('ld-buscar').value||'').trim()||null,
      p_estado:_ldFiltroEstado==='todos'?null:_ldFiltroEstado,
      p_limit:V2.leadSize,
      p_offset:(V2.leadPage-1)*V2.leadSize
    };
  }
  function renderLeadPage(){
    _ldData=V2.leadRows||[];
    var saveFilter=_ldFiltroEstado;var search=document.getElementById('ld-buscar');var saveSearch=search?search.value:'';
    /* Legacy renderer is reused only for row markup; data is already server-filtered. */
    _ldFiltroEstado='todos';if(search)search.value='';
    if(orig.ldRender)orig.ldRender();
    _ldFiltroEstado=saveFilter;if(search)search.value=saveSearch;
    var s=V2.leadSummary||{};
    document.getElementById('ld-count').textContent=n(s.total)+' resultados';
    document.getElementById('ld-k-total').textContent=n(s.total);
    document.getElementById('ld-k-llam').textContent=n(s.llamados);
    document.getElementById('ld-k-cita').textContent=n(s.conCita);
    document.getElementById('ld-k-ventas').textContent=n(s.vendidos);
    document.getElementById('ld-k-sin').textContent=n(s.sinContacto);
    document.getElementById('ld-k-monto').textContent=money(s.montoFacturado);
    ensurePager();
    var pages=Math.max(1,Math.ceil(n(s.total)/V2.leadSize));if(V2.leadPage>pages)V2.leadPage=pages;
    var pe=document.getElementById('ld-v2-page');if(pe)pe.textContent=V2.leadPage+' / '+pages;
  }
  window.ldLoad=function(){
    var p=leadParams();if(!p.p_fecha_desde||!p.p_fecha_hasta)return;
    document.getElementById('ld-body').innerHTML='<tr><td colspan="10" style="padding:40px;text-align:center;color:#9AAAC8;">Cargando V2...</td></tr>';
    Promise.all([
      vrpc('aos_marketing_leads_detalle_v2_paged',p),
      vrpc('aos_marketing_leads_detalle_v2_summary',{p_fecha_desde:p.p_fecha_desde,p_fecha_hasta:p.p_fecha_hasta,p_search:p.p_search,p_estado:p.p_estado})
    ]).then(function(res){V2.leadRows=Array.isArray(res[0])?res[0]:[];V2.leadSummary=res[1]||{};V2.leadTotal=n(V2.leadSummary.total);renderLeadPage();}).catch(function(e){console.error('[MKT-V2] leads',e);document.getElementById('ld-body').innerHTML='<tr><td colspan="10" style="padding:40px;text-align:center;color:#DC2626;">Error V2: '+esc(e.message)+'</td></tr>';});
  };
  window.ldRender=function(){clearTimeout(V2.searchTimer);V2.searchTimer=setTimeout(function(){V2.leadPage=1;window.ldLoad();},280);};
  window.ldEst=function(e){_ldFiltroEstado=e;V2.leadPage=1;document.querySelectorAll('.ld-chip[data-e]').forEach(function(c){c.classList.toggle('act',c.getAttribute('data-e')===e);});window.ldLoad();};
  window.openLeadsModal=function(){V2.leadPage=1;V2.leadSize=50;if(orig.openLeadsModal)orig.openLeadsModal();setTimeout(ensurePager,0);};
  window.ldV2Size=function(v){V2.leadSize=Math.max(25,Math.min(100,Number(v)||50));V2.leadPage=1;window.ldLoad();};
  window.ldV2Prev=function(){if(V2.leadPage>1){V2.leadPage--;window.ldLoad();}};
  window.ldV2Next=function(){var pages=Math.max(1,Math.ceil(V2.leadTotal/V2.leadSize));if(V2.leadPage<pages){V2.leadPage++;window.ldLoad();}};
  window.ldExport=function(){
    var p=leadParams();vrpc('aos_marketing_leads_detalle_v2',{p_fecha_desde:p.p_fecha_desde,p_fecha_hasta:p.p_fecha_hasta}).then(function(all){
      var q=(p.p_search||'').toLowerCase();var rows=(Array.isArray(all)?all:[]).filter(function(r){if(p.p_estado&&r.estado_lead!==p.p_estado)return false;if(!q)return true;return [r.celular,r.numero_limpio,r.anuncio,r.tratamiento].some(function(v){return String(v||'').toLowerCase().indexOf(q)>=0;});});
      if(!rows.length){alert('Sin datos para exportar');return;}
      var headers=['Fecha','Hora','Numero','Tratamiento','Anuncio','Llamadas','Ultimo Asesor','Citas','Monto Facturado','Estado'];var csv=headers.join(',')+'\n';
      function c(v){var s=String(v==null?'':v).replace(/"/g,'""');return /[",\n]/.test(s)?'"'+s+'"':s;}
      csv+=rows.map(function(r){var hora=r.hora_ingreso?new Date(r.hora_ingreso).toLocaleTimeString('es-PE',{hour:'2-digit',minute:'2-digit',hour12:false}):'';return [r.fecha,hora,r.celular,r.tratamiento,r.anuncio,r.llamadas_total,r.ultimo_asesor||'',r.citas_total,r.monto_facturado,r.estado_lead].map(c).join(',');}).join('\n');
      var blob=new Blob(['\ufeff'+csv],{type:'text/csv;charset=utf-8;'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='leads_v2_'+p.p_fecha_desde+'_a_'+p.p_fecha_hasta+'.csv';a.click();URL.revokeObjectURL(url);
    }).catch(function(e){console.error('[MKT-V2] export',e);alert('No se pudo exportar');});
  };

  ensureSummary();
  loadPeriodos().then(function(){loadV2Blocks();});
  console.log('[ASCENDA] Marketing Attribution V2 UI activo');
})();
