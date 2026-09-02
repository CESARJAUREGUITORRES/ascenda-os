// REV Patient 360 Current V3 — canonical operational hot path + serial deferred enrichment.
(function(){'use strict';
if(window.__AOS_PATIENTS_360_V3__==='installed'||window.__AOS_PATIENTS_360_V3__==='waiting')return;
window.__AOS_PATIENTS_360_V3__='waiting';
window.__AOS_PATIENT_BRIDGE_GUARD__='p0436-v2-hotpath';
window.__AOS_PATIENT_FILIATION_CONTACTS__='v1';
var installed=false,timer=null,cards={},bridgeReadyPromise=null,activeCid='',enrichmentSeq=0;
function esc(v){return typeof window.h==='function'?window.h(v):String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function token(){try{return sessionStorage.getItem('aos_app_token')||'';}catch(_){return '';}}
function schedule(){if(!installed)timer=setTimeout(install,800);}
function showError(msg){var f=document.getElementById('pt-ficha');if(!f)return;f.innerHTML='<div style="padding:16px;background:#FEF2F2;border:1px solid #FECACA;border-radius:10px;color:#B91C1C;font-size:11px;font-weight:700;">'+esc(msg)+'</div>';}
function ensurePatientBridge(force){
  if(!('serviceWorker' in navigator))return Promise.resolve(false);
  if(bridgeReadyPromise&&!force)return bridgeReadyPromise;
  bridgeReadyPromise=navigator.serviceWorker.getRegistration('/').then(function(reg){
    if(reg)return reg;return navigator.serviceWorker.register('/phase2-service-worker.js',{scope:'/',updateViaCache:'none'});
  }).then(function(reg){return reg.update().catch(function(){return reg;}).then(function(){return reg;});}).then(function(reg){
    return new Promise(function(resolve){
      var done=false,pending=reg.installing||reg.waiting,timeout=null;
      function finish(ok){if(done)return;done=true;if(timeout)clearTimeout(timeout);try{navigator.serviceWorker.removeEventListener('controllerchange',onController);}catch(_){}resolve(!!ok);}
      function onController(){finish(!!navigator.serviceWorker.controller);}
      navigator.serviceWorker.addEventListener('controllerchange',onController);
      if(reg.waiting){try{reg.waiting.postMessage({type:'ASCENDA_ACTIVATE_NOW'});}catch(_){} }
      if(!pending){finish(!!navigator.serviceWorker.controller);return;}
      try{pending.addEventListener('statechange',function(){if(pending.state==='activated'||pending.state==='redundant')finish(!!navigator.serviceWorker.controller);});}catch(_){}
      timeout=setTimeout(function(){finish(!!navigator.serviceWorker.controller);},4500);
    });
  }).catch(function(){return false;});
  return bridgeReadyPromise;
}
function install(){
  if(installed)return;
  if(typeof window._rpc!=='function'||typeof window.render360!=='function'||!window.PT){schedule();return;}
  installed=true;if(timer)clearTimeout(timer);window.__AOS_PATIENTS_360_V3__='installed';
  var baseRender360=window.render360;
  ensurePatientBridge(false);

  window.ptSearch=function(q){
    clearTimeout(window._ptT);var r=document.getElementById('pt-res');
    if(!q||q.length<2){r.innerHTML='<div class="ld">Min. 2 caracteres</div>';return;}
    r.innerHTML='<div class="ld"><span class="sp"></span>Buscando paciente actual...</div>';
    window._ptT=setTimeout(function(){window._rpc('aos_patient_search_v2',{p_token:token(),p_query:q,p_limit:20},function(d){
      var rows=d&&d.results||[],warn=d&&d.lookup_status==='IDENTITY_CONFLICT';cards={};
      if(!rows.length){r.innerHTML=(warn?'<div style="padding:8px;margin:6px;background:#FEF2F2;border:1px solid #FECACA;border-radius:8px;color:#B91C1C;font-size:10px;font-weight:700;">IDENTITY_CONFLICT · revisa el identificador compartido.</div>':'')+'<div class="ld">Sin resultados</div>';return;}
      var html=warn?'<div style="padding:8px;margin:6px;background:#FFF7ED;border:1px solid #FED7AA;border-radius:8px;color:#C2410C;font-size:10px;font-weight:700;">Hay un identificador compartido. La ficha actual se abrirá únicamente por su ID canónico.</div>':'';
      html+=rows.map(function(p){var cid=p.canonical_patient_id||'',n=((p.nombres||'')+' '+(p.apellidos||'')).trim(),e=(p.estado||'PROSPECTO').toUpperCase(),bc=e==='PACIENTE'||e==='ACTIVO'?'bg-pac':e==='PROSPECTO'||e==='NUEVO'?'bg-pros':'bg-inact';cards[cid]=p;var hist=p.identity_status==='REVIEW_REQUIRED'?'<span class="pt-bg" style="background:#FFF7ED;color:#C2410C;">HISTÓRICO REVIEW</span>':'<span class="pt-bg" style="background:#F8FAFC;color:#475569;">HISTÓRICO '+esc(p.identity_status||'SIN REVIEW')+'</span>';return '<div class="pt-c" data-cid="'+esc(cid)+'" onclick="ptSelCurrent(\''+esc(cid)+'\')"><div class="pt-cn">'+esc(n||'Sin nombre')+'</div><div class="pt-cm">'+esc(p.telefono||'')+(p.dni?' · '+esc(p.dni):'')+'</div><div class="pt-cb"><span class="pt-bg '+bc+'">'+esc(e)+'</span><span class="pt-bg" style="background:#ECFDF5;color:#047857;">ACTUAL RESOLVED</span>'+hist+(p.sede?'<span class="pt-bg" style="background:#EBF2FF;color:#0A4FBF;">'+esc(p.sede)+'</span>':'')+'</div></div>';}).join('');r.innerHTML=html;
    },function(){r.innerHTML='<div class="ld">Error de búsqueda</div>';});},250);
  };

  function contextHtml(d){
    var id=d.identity||{},conf=d.identity_confidence||{},life=d.lifecycle||{},link=d.legacy_link_status||'UNKNOWN';
    var confText=conf.enrichment_status==='DEFERRED'?'cargando…':conf.enrichment_status==='UNAVAILABLE'?'no disponible':(conf.confidence_level||'—');
    var lifeText=life.enrichment_status==='DEFERRED'?'cargando…':life.enrichment_status==='UNAVAILABLE'?'no disponible':(life.lifecycle_state||life.classification_status||'—');
    return '<div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;"><span style="font-family:\'Exo 2\',sans-serif;font-weight:800;font-size:11px;color:#0D1B3E;">Paciente actual · '+esc(id.canonical_patient_id||'')+'</span><span class="pt-bg" style="background:#ECFDF5;color:#047857;">ACTUAL '+esc(id.current_status||'RESOLVED')+'</span><span class="pt-bg" style="background:'+(id.historical_review_required?'#FFF7ED;color:#C2410C':'#F8FAFC;color:#475569')+';">HISTÓRICO '+esc(id.historical_status||'—')+'</span><span class="pt-bg" style="background:#EEF2FF;color:#4338CA;">Confianza '+esc(confText)+'</span></div><div style="margin-top:6px;font-size:9px;color:#64748B;">360 core: '+esc(link)+' · lifecycle: '+esc(lifeText)+' · el contexto analítico nunca bloquea la ficha.</div>';
  }
  function augment(d){
    var root=document.getElementById('pt-ficha');if(!root)return;
    var box=root.querySelector('[data-p360v3="identity"]');
    if(!box){var fh=root.querySelector('.fh');if(fh){fh.insertAdjacentHTML('afterend','<div data-p360v3="identity" style="margin-bottom:10px;padding:10px 12px;background:#F8FAFF;border:1px solid #DDE4F5;border-radius:10px;"></div>');box=root.querySelector('[data-p360v3="identity"]');}}
    if(box)box.innerHTML=contextHtml(d);
    if(!root.querySelector('[data-p360v3="trust"]')){var fkr=root.querySelector('.fkr');if(fkr)fkr.insertAdjacentHTML('afterend','<div data-p360v3="trust" style="margin:0 0 10px;padding:9px 12px;background:#0F172A;color:#E2E8F0;border-radius:10px;font-size:9px;line-height:1.5;"><b style="color:white;">Revenue enrichment</b> · el expediente operativo carga primero; identidad/lifecycle se enriquecen en serie. 2024/2025 transaccional sigue siendo NO_CERTIFIED_SOURCE.</div>');}
  }
  function ensureFiliationContacts(d){
    var root=document.getElementById('pt-ficha'),grid=root&&root.querySelector('.fd');if(!grid)return;
    var p=d&&d.paciente||{},labels=grid.querySelectorAll('.fdl'),seen={};
    for(var i=0;i<labels.length;i++)seen[String(labels[i].textContent||'').trim().toUpperCase()]=true;
    function card(label,value,key){if(seen[label.toUpperCase()])return;var node=document.createElement('div');node.className='fdc';node.setAttribute('data-p360v3',key);node.innerHTML='<div class="fdl">'+esc(label)+'</div><div class="fdv">'+esc(value||'—')+'</div>';grid.insertBefore(node,grid.firstChild);seen[label.toUpperCase()]=true;}
    card('Teléfono',p.telefono,'filiation-phone');
    card('Correo',p.correo,'filiation-email');
  }
  function renderCurrent(d){window.PT.data=d;window.PT.sel=d.paciente;window.PT.tab='cotizaciones';baseRender360(d);augment(d);ensureFiliationContacts(d);var rt=document.getElementById('pt-right');if(rt&&rt.classList)rt.classList.toggle('hidden',!d.clinical_access);if(typeof window.renderNotas==='function')window.renderNotas(d.notas||[]);}
  function applyDeferred(cid,seq,section,res){
    if(activeCid!==cid||seq!==enrichmentSeq||!window.PT.data)return;
    var payload=res&&res.payload||null;
    if(section==='IDENTITY_CONFIDENCE')window.PT.data.identity_confidence=payload||{enrichment_status:'UNAVAILABLE'};
    else if(section==='LIFECYCLE')window.PT.data.lifecycle=payload||{enrichment_status:'UNAVAILABLE'};
    augment(window.PT.data);
  }
  function loadDeferred(cid,seq,section,done){
    window._rpc('aos_patient_360_enrichment_v1',{p_token:token(),p_canonical_patient_id:cid,p_section:section},function(res){if(res&&res.ok&&res.found)applyDeferred(cid,seq,section,res);else applyDeferred(cid,seq,section,null);if(done)done();},function(){applyDeferred(cid,seq,section,null);if(done)done();});
  }
  function loadDeferredSerial(cid,seq){loadDeferred(cid,seq,'IDENTITY_CONFIDENCE',function(){if(activeCid!==cid||seq!==enrichmentSeq)return;loadDeferred(cid,seq,'LIFECYCLE');});}
  function loadCurrent(cid,seq){
    window._rpc('aos_patient_360_current_v3',{p_token:token(),p_canonical_patient_id:cid},function(d){
      if(activeCid!==cid||seq!==enrichmentSeq)return;
      if(d&&d.found){renderCurrent(d);loadDeferredSerial(cid,seq);return;}
      var status=d&&d.identity_resolution&&d.identity_resolution.status||'';
      if(status==='CANONICAL_TARGET_MISSING'){showError('El registro canónico actual '+cid+' ya no existe o fue fusionado. No se modificó ningún dato.');return;}
      showError('No se pudo cargar el expediente operativo del paciente '+cid+'. No se modificó ningún dato.');
    },function(){if(activeCid===cid&&seq===enrichmentSeq)showError('Error al cargar el expediente operativo de Pacientes 360. No se modificó ningún dato.');});
  }

  window.ptSelCurrent=function(cid){
    cid=String(cid||'').trim();if(!cid){showError('Paciente canónico inválido.');return;}
    activeCid=cid;var seq=++enrichmentSeq;
    document.querySelectorAll('.pt-c').forEach(function(c){c.classList.toggle('act',c.getAttribute('data-cid')===cid);});
    var f=document.getElementById('pt-ficha'),empty=document.getElementById('pt-empty');if(empty)empty.style.display='none';if(!f)return;f.style.display='block';f.innerHTML='<div class="ld"><span class="sp"></span>Cargando expediente operativo...</div>';
    ensurePatientBridge(false).then(function(ok){if(activeCid!==cid||seq!==enrichmentSeq)return;if(!ok){showError('No está disponible el puente seguro de Pacientes. Recarga ASCENDA e inicia sesión nuevamente.');return;}loadCurrent(cid,seq);});
  };

  window.ptSel=function(value){value=String(value||'').trim();if(/^P-/i.test(value)){window.ptSelCurrent(value);return;}window._rpc('aos_patient_search_v2',{p_token:token(),p_query:value,p_limit:10},function(d){var rows=d&&d.results||[];if(rows.length===1&&rows[0].canonical_patient_id){window.ptSelCurrent(rows[0].canonical_patient_id);return;}showError(rows.length>1?'El teléfono corresponde a más de un paciente actual. Selecciona la ficha por nombre.':'No se encontró un paciente actual para ese identificador.');},function(){showError('No se pudo resolver el botón legado hacia un paciente actual.');});};
  window.render360=function(d){baseRender360(d);augment(d);ensureFiliationContacts(d);};
}
install();
})();