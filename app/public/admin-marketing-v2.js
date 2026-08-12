/* ASCENDA OS — Marketing progressive alignment adapter
 * Safe progressive enhancement: legacy renders first and always remains the fallback.
 * This adapter only applies validated cohort metrics after successful V2 RPC responses.
 */
(function(){
  if(window.__AOS_MARKETING_PROGRESSIVE_ACTIVE)return;
  window.__AOS_MARKETING_V2_LOADED=true;
  window.__AOS_MARKETING_V2_ACTIVE=false;
  window.__AOS_MARKETING_PROGRESSIVE_ACTIVE=true;

  var orig={
    mkL:window.mkL,
    rKPI:window.rKPI,
    rEmb:window.rEmb,
    rHist:window.rHist,
    ldLoad:window.ldLoad,
    ldRender:window.ldRender
  };
  var S={legacyKpi:null,legacyEmb:null,leadSummary:null,leadReq:0,blockReq:0,periodos:[]};

  function vrpc(fn,p){
    return fetch(SB+'/rest/v1/rpc/'+fn,{
      method:'POST',
      headers:{'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json'},
      body:JSON.stringify(p||{})
    }).then(function(r){
      if(!r.ok)return r.text().then(function(t){throw new Error(fn+' HTTP '+r.status+' '+t.slice(0,160));});
      return r.json();
    });
  }
  function n(v){return Number(v)||0;}
  function money(v){return 'S/'+Math.round(n(v)).toLocaleString('es-PE');}

  /* Keep the stable renderer active. We only remember its KPI/embudo payload. */
  window.rKPI=function(k){S.legacyKpi=k||null;orig.rKPI(k);scheduleBlocks();};
  window.rEmb=function(e){S.legacyEmb=e||null;orig.rEmb(e);};

  function currentMonthRange(){
    var a=Number(el('mk-anio').value),m=Number(el('mk-mes').value);
    var d1=a+'-'+String(m).padStart(2,'0')+'-01';
    var last=new Date(a,m,0).getDate();
    return{anio:a,mes:m,desde:d1,hasta:a+'-'+String(m).padStart(2,'0')+'-'+String(last).padStart(2,'0')};
  }

  function ensureTrace(){
    var card=document.getElementById('mk-progressive-trace');
    if(card)return card;
    var gest=document.getElementById('mk-gest');if(!gest)return null;
    card=document.createElement('div');card.id='mk-progressive-trace';card.className='crd';card.style.padding='8px 12px';
    card.innerHTML='<div class="ct" style="margin-bottom:6px;">🧭 Trazabilidad del período <span class="tag tag-b">personas vs ingresos</span></div><div id="mk-progressive-trace-grid" class="g-row"><div class="ld">Validando...</div></div><div id="mk-progressive-trace-note" style="font-size:8px;color:#6B7BA8;margin-top:6px;line-height:1.45;"></div>';
    gest.insertAdjacentElement('afterend',card);
    return card;
  }
  function renderTrace(s){
    var card=ensureTrace();if(!card)return;
    card.style.display=MK.modo==='mes'?'':'none';if(MK.modo!=='mes')return;
    var box=document.getElementById('mk-progressive-trace-grid');
    var items=[
      [n(s.ingresos),'INGRESOS','#0A4FBF'],[n(s.personasUnicas),'PERSONAS ÚNICAS','#0D9488'],[n(s.reingresos),'REINGRESOS','#7C3AED'],
      [n(s.personasGestionadas),'GESTIÓN POST-INGRESO','#059669'],[n(s.personasCitaTel),'CITAS TEL.','#D97706'],[n(s.personasConCita),'CITAS AGENDA','#7C3AED'],[n(s.clientesM0),'CLIENTES M0','#059669']
    ];
    box.innerHTML=items.map(function(x){return '<div class="g-c" style="background:#F8FAFF;border:1px solid #EEF2F8;"><div class="g-v" style="color:'+x[2]+'">'+x[0]+'</div><div class="g-l">'+x[1]+'</div></div>';}).join('');
    var note=document.getElementById('mk-progressive-trace-note');
    if(note)note.innerHTML='Embudo causal: la gestión cuenta solo después del ingreso del lead. La franja azul de <b>Gestión</b> sigue siendo actividad operativa total del mes y puede incluir seguimientos de cohortes anteriores. Citas Tel. = tipificación del Call Center; Citas Agenda = citas realmente registradas.';
  }

  function renderTopFromSummary(s){
    if(!S.legacyKpi||MK.modo!=='mes')return;
    var inv=n(S.legacyKpi.invTotal),leads=n(s.personasUnicas),ll=n(s.personasGestionadas),citas=n(s.personasCitaTel),asist=n(s.personasAsistieron),cli=n(s.clientesM0),ventas=n(s.ventasM0),fact=n(s.factM0);
    var k={};Object.keys(S.legacyKpi||{}).forEach(function(x){k[x]=S.legacyKpi[x];});
    k.leads=leads;k.llamados=ll;k.citas=citas;k.asistieron=asist;k.clientes=cli;k.nVentas=ventas;k.factTotal=fact;
    k.pctLlamados=leads>0?Math.round(ll/leads*10000)/100:0;
    k.roas=inv>0?Math.round(fact/inv*100)/100:null;
    k.cac=cli>0&&inv>0?Math.round(inv/cli*100)/100:null;
    k.cpl=leads>0&&inv>0?Math.round(inv/leads*100)/100:null;
    orig.rKPI(k);
    orig.rEmb({
      leads:leads,llamados:ll,citas:citas,asistieron:asist,clientes:cli,ventas:ventas,factTotal:fact,
      tasas:{
        llamados:leads>0?Math.round(ll/leads*10000)/100:0,
        citas:ll>0?Math.round(citas/ll*10000)/100:0,
        asist:citas>0?Math.round(asist/citas*10000)/100:0,
        clientes:asist>0?Math.round(cli/asist*10000)/100:0,
        ventas:cli>0?Math.round(ventas/cli*10000)/100:0
      }
    });
    renderTrace(s);
  }

  function applyHistory(rows){
    if(!Array.isArray(rows)||!rows.length)return;
    var mapped=rows.map(function(r){
      return{
        mes:n(r.mes),anio:n(r.anio),leads:n(r.leads),
        llamados:(n(r.llamados)===0&&n(r.citas)>0?'—':n(r.llamados)),
        citas:n(r.citas),asistieron:n(r.asistieron),clientes:n(r.clientes),ventas:n(r.ventas),
        fact:n(r.fact),fact_acumulado:n(r.fact_acumulado),conv:n(r.conv).toFixed(2)
      };
    });
    orig.rHist(mapped);
    var hist=document.getElementById('mk-hist');if(!hist)return;
    var old=document.getElementById('mk-progressive-hist-note');if(old)old.remove();
    var note=document.createElement('div');note.id='mk-progressive-hist-note';note.style.cssText='font-size:8px;color:#6B7BA8;margin-top:6px;line-height:1.45;';
    note.innerHTML='Histórico anual fijo: no se recorta al cambiar el mes. Leads = personas únicas; Llamados = gestión posterior al ingreso; Citas = Agenda; Clientes/Ventas/Facturación = atribución M0. <b>—</b> indica ausencia de histórico confiable de llamadas.';
    hist.appendChild(note);
    if(MK.modo==='mes'){
      var target=MF[Number(el('mk-mes').value)].slice(0,3).toUpperCase();
      Array.from(hist.querySelectorAll('tbody tr')).forEach(function(tr){var td=tr.querySelector('td');if(td&&td.textContent.indexOf(target+' ')===0){tr.style.background='#F0F7FF';tr.style.outline='1px solid #D9E8FF';}});
    }
  }

  function scheduleBlocks(){setTimeout(loadBlocks,30);}
  function loadBlocks(){
    var req=++S.blockReq;
    var anio=Number(el('mk-anio').value);
    vrpc('aos_marketing_historico_public_v2',{p_anio:anio}).then(function(rows){if(req!==S.blockReq)return;applyHistory(rows);}).catch(function(e){console.warn('[MKT progressive] histórico mantiene legacy:',e.message);});
    if(MK.modo==='mes'){
      var r=currentMonthRange();
      vrpc('aos_marketing_period_summary_v2',{p_fecha_desde:r.desde,p_fecha_hasta:r.hasta}).then(function(s){if(req!==S.blockReq)return;renderTopFromSummary(s||{});}).catch(function(e){console.warn('[MKT progressive] KPIs mantienen legacy:',e.message);});
    }else{
      var card=document.getElementById('mk-progressive-trace');if(card)card.style.display='none';
    }
  }

  window.mkL=function(){orig.mkL();scheduleBlocks();};

  /* Leads del período: use attribution-safe rows, with automatic legacy fallback. */
  function setLeadCard(id,value,label){
    var v=document.getElementById(id);if(!v)return;v.textContent=value;
    var lab=v.parentElement&&v.parentElement.querySelector('.ld-kpi-l');if(lab&&label)lab.textContent=label;
  }
  function ensureLeadNote(){
    var note=document.getElementById('ld-progressive-note');if(note)return note;
    var v=document.getElementById('ld-k-total');if(!v||!v.parentElement||!v.parentElement.parentElement)return null;
    var grid=v.parentElement.parentElement;
    note=document.createElement('div');note.id='ld-progressive-note';note.style.cssText='font-size:8px;color:#6B7BA8;background:#F8FAFF;border:1px solid #EEF2F8;border-radius:8px;padding:7px 9px;margin:7px 0;line-height:1.45;';
    grid.insertAdjacentElement('afterend',note);return note;
  }
  function applyLeadSummary(){
    var s=S.leadSummary;if(!s)return;
    var filtro=(typeof _ldFiltroEstado!=='undefined'?_ldFiltroEstado:'todos');
    var q=(el('ld-buscar').value||'').trim();
    var note=ensureLeadNote();
    if(note)note.innerHTML='<b>'+n(s.ingresos)+' ingresos</b> corresponden a <b>'+n(s.personasUnicas)+' personas únicas</b> ('+n(s.reingresos)+' reingresos). Personas: '+n(s.personasGestionadas)+' gestionadas después del ingreso · '+n(s.personasCitaTel)+' Citas Tel. · '+n(s.personasConCita)+' citas en Agenda · '+n(s.clientesM0)+' clientes M0 · '+n(s.ventasM0)+' operaciones M0 · '+money(s.factM0)+' M0. La tabla y sus filtros representan <b>touchpoints/ingresos</b>; “VENDIDO” solo aparece cuando la venta fue atribuida a ese ingreso.';
    var count=document.getElementById('ld-count');
    if(filtro==='todos'&&!q){
      if(count)count.textContent=n(s.ingresos)+' ingresos · '+n(s.personasUnicas)+' personas';
      setLeadCard('ld-k-total',n(s.personasUnicas),'PERSONAS ÚNICAS');
      setLeadCard('ld-k-llam',n(s.personasGestionadas),'GESTIÓN POST-INGRESO');
      setLeadCard('ld-k-cita',n(s.personasConCita),'CON CITA EN AGENDA');
      setLeadCard('ld-k-ventas',n(s.clientesM0),'CLIENTES M0');
      setLeadCard('ld-k-sin',n(s.personasSinGestion),'SIN GESTIÓN POST-INGRESO');
      setLeadCard('ld-k-monto',money(s.factM0),'FACTURACIÓN M0');
    }else{
      if(count)count.textContent=count.textContent+' · '+n(s.personasUnicas)+' personas en período';
      var labels=[['ld-k-total','INGRESOS FILTRADOS'],['ld-k-llam','CON LLAMADAS'],['ld-k-cita','CON CITAS ATRIB.'],['ld-k-ventas','VENDIDOS'],['ld-k-sin','SIN CONTACTO'],['ld-k-monto','FACTURADO FILTRO']];
      labels.forEach(function(x){var e=document.getElementById(x[0]);var lab=e&&e.parentElement&&e.parentElement.querySelector('.ld-kpi-l');if(lab)lab.textContent=x[1];});
    }
  }

  window.ldRender=function(){orig.ldRender();applyLeadSummary();};
  window.ldLoad=function(){
    var desde=el('ld-desde').value,hasta=el('ld-hasta').value;
    if(!desde||!hasta){orig.ldLoad();return;}
    var req=++S.leadReq;
    el('ld-body').innerHTML='<tr><td colspan="10" style="padding:40px;text-align:center;color:#9AAAC8;">Validando atribución...</td></tr>';
    Promise.all([
      vrpc('aos_marketing_leads_detalle_v2',{p_fecha_desde:desde,p_fecha_hasta:hasta}),
      vrpc('aos_marketing_period_summary_v2',{p_fecha_desde:desde,p_fecha_hasta:hasta})
    ]).then(function(res){
      if(req!==S.leadReq)return;
      _ldData=Array.isArray(res[0])?res[0]:[];S.leadSummary=res[1]||null;window.ldRender();
    }).catch(function(e){
      if(req!==S.leadReq)return;
      console.warn('[MKT progressive] Leads V2 falló; usando legacy:',e.message);S.leadSummary=null;orig.ldLoad();
    });
  };

  /* Years/months come from real data; failure leaves the original hardcoded selector untouched. */
  function loadPeriodos(){
    vrpc('aos_marketing_periodos_v2_preview',{}).then(function(rows){
      if(!Array.isArray(rows)||!rows.length)return;S.periodos=rows;
      var ys=el('mk-anio'),ms=el('mk-mes');if(!ys||!ms)return;
      var current=Number(ys.value),years=[];rows.forEach(function(r){var y=Number(r.anio);if(years.indexOf(y)<0)years.push(y);});years.sort(function(a,b){return b-a;});
      ys.innerHTML=years.map(function(y){return '<option value="'+y+'">'+y+'</option>';}).join('');ys.value=String(years.indexOf(current)>=0?current:years[0]);
      var allowed=rows.filter(function(r){return Number(r.anio)===Number(ys.value);}).map(function(r){return Number(r.mes);});
      Array.from(ms.options).forEach(function(o){o.disabled=allowed.indexOf(Number(o.value))<0;});
    }).catch(function(e){console.warn('[MKT progressive] períodos mantienen selector legacy:',e.message);});
  }

  loadPeriodos();
  /* Enhance the already-rendered initial view; later legacy renders trigger another safe pass. */
  setTimeout(loadBlocks,250);
  console.log('[ASCENDA] Marketing progressive alignment activo: legacy-first + V2 on success.');
})();
