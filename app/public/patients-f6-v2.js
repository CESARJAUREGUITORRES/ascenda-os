// REV-F6.1 — Patient Commercial 360 V2 UI bridge.
// Upgrades the existing patients.html/patients.js surface; does not create a second patient panel.
(function(){'use strict';
if(window.__AOS_PATIENTS_F6_V2__==='installed'||window.__AOS_PATIENTS_F6_V2__==='waiting')return;
window.__AOS_PATIENTS_F6_V2__='waiting';
var installed=false,timer=null;
function esc(v){return typeof window.h==='function'?window.h(v):String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function pct(o){return o&&o.pct!=null?Number(o.pct).toFixed(2)+'%':'—';}
function schedule(){if(!installed)timer=setTimeout(install,1000);}
function install(){
  if(installed)return;
  if(typeof window._rpc!=='function'||typeof window.render360!=='function'||typeof window.renderTab!=='function'||!window.PT){schedule();return;}
  installed=true;if(timer)clearTimeout(timer);window.__AOS_PATIENTS_F6_V2__='installed';
  var baseRender360=window.render360,baseRenderTab=window.renderTab;

  window.ptSearch=function(q){
    clearTimeout(window._ptT);var r=document.getElementById('pt-res');
    if(!q||q.length<2){r.innerHTML='<div class="ld">Min. 2 caracteres</div>';return;}
    r.innerHTML='<div class="ld"><span class="sp"></span>Buscando identidad canónica...</div>';
    window._ptT=setTimeout(function(){window._rpc('aos_patient_search_v2',{p_query:q,p_limit:20},function(d){
      var rows=d&&d.results||[],warn=d&&d.lookup_status==='IDENTITY_CONFLICT';
      if(!rows.length){r.innerHTML=(warn?'<div style="padding:8px;margin:6px;background:#FEF2F2;border:1px solid #FECACA;border-radius:8px;color:#B91C1C;font-size:10px;font-weight:700;">IDENTITY_CONFLICT · el identificador pertenece a más de un candidato y no se asignó automáticamente.</div>':'')+'<div class="ld">Sin resultados</div>';return;}
      var html=warn?'<div style="padding:8px;margin:6px;background:#FEF2F2;border:1px solid #FECACA;border-radius:8px;color:#B91C1C;font-size:10px;font-weight:700;">IDENTITY_CONFLICT · selecciona explícitamente el paciente correcto; no hubo auto-merge.</div>':'';
      html+=rows.map(function(p){var n=((p.nombres||'')+' '+(p.apellidos||'')).trim(),cid=p.canonical_patient_id||'',e=(p.estado||'PROSPECTO').toUpperCase(),bc=e==='PACIENTE'||e==='ACTIVO'?'bg-pac':e==='PROSPECTO'||e==='NUEVO'?'bg-pros':'bg-inact';return '<div class="pt-c" data-cid="'+esc(cid)+'" onclick="ptSelV2(\'CANONICAL_ID\',\''+esc(cid)+'\')"><div class="pt-cn">'+esc(n||'Sin nombre')+'</div><div class="pt-cm">'+esc(p.telefono||'')+(p.dni?' · '+esc(p.dni):'')+'</div><div class="pt-cb"><span class="pt-bg '+bc+'">'+esc(e)+'</span><span class="pt-bg" style="background:#EEF2FF;color:#4338CA;">'+esc(p.identity_status||'CANONICAL')+'</span>'+(p.alias_match?'<span class="pt-bg" style="background:#ECFDF5;color:#047857;">Alias V2</span>':'')+(p.sede?'<span class="pt-bg" style="background:#EBF2FF;color:#0A4FBF;">'+esc(p.sede)+'</span>':'')+'</div></div>';}).join('');r.innerHTML=html;
    },function(){r.innerHTML='<div class="ld">Error de búsqueda</div>';});},250);
  };

  window.ptSelV2=function(type,value){
    document.querySelectorAll('.pt-c').forEach(function(c){c.classList.toggle('act',type==='CANONICAL_ID'&&c.getAttribute('data-cid')===value);});
    var f=document.getElementById('pt-ficha');document.getElementById('pt-empty').style.display='none';f.style.display='block';f.innerHTML='<div class="ld"><span class="sp"></span>Cargando Patient Commercial 360 V2...</div>';
    window._rpc('aos_patient_commercial_360_v2',{p_lookup_type:type,p_lookup_value:value},function(d){
      if(!d||!d.found){var st=d&&d.identity_resolution&&d.identity_resolution.status||'UNRESOLVED';f.innerHTML='<div style="padding:16px;background:#FEF2F2;border:1px solid #FECACA;border-radius:10px;color:#B91C1C;font-size:11px;font-weight:700;">'+esc(st)+' · no se asignó una identidad automáticamente.</div>';return;}
      window.PT.data=d;window.PT.sel=d.paciente;window.PT.tab='cotizaciones';baseRender360(d);augment360(d);
      var rt=document.getElementById('pt-right');if(rt){rt.classList.toggle('hidden',!d.clinical_access);}
      if(typeof window.renderNotas==='function')window.renderNotas(d.notas||[]);
    });
  };
  window.ptSel=function(num){window.ptSelV2('PHONE',num);};

  window.render360=function(d){baseRender360(d);augment360(d);};
  window.renderTab=function(){
    if(window.PT&&window.PT.tab==='timeline')return renderTimeline(window.PT.data&&window.PT.data.timeline||[]);
    return baseRenderTab();
  };

  function augment360(d){
    var root=document.getElementById('pt-ficha');if(!root||root.querySelector('[data-f61="identity"]'))return;
    var id=d.identity||{},mt=d.metric_trust||{},cov=mt.coverage||{},cs=d.commercial_summary||{};
    var fh=root.querySelector('.fh');if(fh){fh.insertAdjacentHTML('afterend','<div data-f61="identity" style="margin-bottom:10px;padding:10px 12px;background:#F8FAFF;border:1px solid #DDE4F5;border-radius:10px;"><div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;"><span style="font-family:\'Exo 2\',sans-serif;font-weight:800;font-size:11px;color:#0D1B3E;">Identidad canónica V2</span><span class="pt-bg" style="background:#EEF2FF;color:#4338CA;">'+esc(id.status||'—')+'</span><span class="pt-bg" style="background:'+(id.confidence_band==='CONFLICT'?'#FEF2F2;color:#B91C1C':'#ECFDF5;color:#047857')+';">Confianza '+esc(id.confidence_band||'—')+'</span><span class="pt-bg" style="background:#F8FAFC;color:#475569;">'+esc(id.duplicate_evidence_class||'—')+'</span></div><div style="margin-top:6px;font-size:9px;color:#64748B;">Aliases: '+Number(id.alias_count||0)+' · teléfonos '+Number(id.phone_alias_count||0)+' · históricos '+Number(id.historical_phone_alias_count||0)+' · conflictos '+Number(id.alias_conflicts||0)+(id.historical_contact_indicator?' · historial multi-contacto':'')+'</div></div>');}
    var fkr=root.querySelector('.fkr');if(fkr){fkr.insertAdjacentHTML('afterend','<div data-f61="trust" style="margin:0 0 10px;padding:10px 12px;background:#0F172A;color:#E2E8F0;border-radius:10px;font-size:9px;line-height:1.55;"><div style="font-family:\'Exo 2\',sans-serif;font-size:11px;font-weight:800;color:white;margin-bottom:4px;">Metric Trust · REV-F6.0/F6.1</div><div>Identity '+pct(cov.identity)+' · Sales linkage '+pct(cov.sales_linkage)+' · F3 producto '+pct(cov.f3_product)+' · F4 evidencia '+pct(cov.f4_financial_evidence)+' · Histórico transaccional '+pct(cov.historical_transaction_source_availability)+'</div><div style="color:#FBBF24;margin-top:3px;">2024/2025 = NO_CERTIFIED_SOURCE, no ventas cero. Total observado no equivale a lifetime.</div><div style="margin-top:3px;color:#94A3B8;">Lifecycle: '+esc(cs.lifecycle_state||'PENDING_REV_F6_2')+' · F4 linked sales: '+Number(cs.f4_linked_sales||0)+' · payment evidence: '+Number(cs.payment_evidence_rows||0)+'</div></div>');}
    var tabs=root.querySelector('.ftabs');if(tabs&&!tabs.querySelector('[data-tab="timeline"]')){tabs.insertAdjacentHTML('beforeend','<div class="ftab" data-tab="timeline" onclick="ptTab(\'timeline\')">Timeline V2 ('+((d.timeline||[]).length)+')</div>');}
  }

  function renderTimeline(rows){var b=document.getElementById('pt-tc');if(!b)return;if(!rows.length){b.innerHTML='<div class="ld">Sin eventos canónicos observados</div>';return;}b.innerHTML='<table class="tt"><thead><tr><th>Fecha</th><th>Tipo</th><th>Evento</th><th>Estado</th><th>Provenance</th></tr></thead><tbody>'+rows.map(function(e){return '<tr><td>'+esc(e.event_date||'')+'</td><td><span class="pt-bg" style="background:#EEF2FF;color:#4338CA;">'+esc(e.event_type||'')+'</span></td><td>'+esc(e.label||'')+(e.amount!=null?' · S/'+Number(e.amount||0).toFixed(2):'')+'</td><td>'+esc(e.status||'')+'</td><td style="font-size:8px;color:#64748B;">'+esc(e.provenance||'')+'</td></tr>';}).join('')+'</tbody></table>';}
}
install();
})();
