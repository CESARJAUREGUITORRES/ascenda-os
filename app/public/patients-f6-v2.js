// REV Patient 360 Current V3 — rebuild over the proven pre-F6 patient flow.
// Search resolves a canonical current patient once. Selection then reads that canonical
// patient directly; F5/F6 enrich the payload but never gate visibility of the current record.
(function(){'use strict';
if(window.__AOS_PATIENTS_360_V3__==='installed'||window.__AOS_PATIENTS_360_V3__==='waiting')return;
window.__AOS_PATIENTS_360_V3__='waiting';
window.__AOS_PATIENT_BRIDGE_GUARD__='p0436-v1';
var installed=false,timer=null,cards={},bridgeReadyPromise=null;
function esc(v){return typeof window.h==='function'?window.h(v):String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function token(){try{return sessionStorage.getItem('aos_app_token')||'';}catch(_){return '';}}
function schedule(){if(!installed)timer=setTimeout(install,800);}
function showError(msg){var f=document.getElementById('pt-ficha');if(!f)return;f.innerHTML='<div style="padding:16px;background:#FEF2F2;border:1px solid #FECACA;border-radius:10px;color:#B91C1C;font-size:11px;font-weight:700;">'+esc(msg)+'</div>';}

// P0 #436: the governed token bridge is service-worker authority. A long-lived installed
// ASCENDA client may still be controlled by a pre-#323 worker even after current code deploys.
// Refresh the registration exactly once per Patients runtime and wait a bounded interval for
// activation/controller takeover. No polling, no browser-token fallback, no auth weakening.
function ensurePatientBridge(force){
  if(!('serviceWorker' in navigator))return Promise.resolve(false);
  if(bridgeReadyPromise&&!force)return bridgeReadyPromise;
  bridgeReadyPromise=navigator.serviceWorker.getRegistration('/').then(function(reg){
    if(reg)return reg;
    return navigator.serviceWorker.register('/phase2-service-worker.js',{scope:'/',updateViaCache:'none'});
  }).then(function(reg){
    return reg.update().catch(function(){return reg;}).then(function(){return reg;});
  }).then(function(reg){
    return new Promise(function(resolve){
      var done=false,pending=reg.installing||reg.waiting,timeout=null;
      function finish(ok){
        if(done)return;done=true;
        if(timeout)clearTimeout(timeout);
        try{navigator.serviceWorker.removeEventListener('controllerchange',onController);}catch(_){}
        resolve(!!ok);
      }
      function onController(){finish(!!navigator.serviceWorker.controller);}
      navigator.serviceWorker.addEventListener('controllerchange',onController);
      if(reg.waiting){try{reg.waiting.postMessage({type:'ASCENDA_ACTIVATE_NOW'});}catch(_){} }
      if(!pending){finish(!!navigator.serviceWorker.controller);return;}
      try{pending.addEventListener('statechange',function(){
        if(pending.state==='activated')finish(!!navigator.serviceWorker.controller);
        else if(pending.state==='redundant')finish(!!navigator.serviceWorker.controller);
      });}catch(_){}
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

  // Warm the bridge update in the background once. It is bounded and single-flight.
  ensurePatientBridge(false);

  window.ptSearch=function(q){
    clearTimeout(window._ptT);var r=document.getElementById('pt-res');
    if(!q||q.length<2){r.innerHTML='<div class="ld">Min. 2 caracteres</div>';return;}
    r.innerHTML='<div class="ld"><span class="sp"></span>Buscando paciente actual...</div>';
    window._ptT=setTimeout(function(){
      window._rpc('aos_patient_search_v2',{p_token:token(),p_query:q,p_limit:20},function(d){
        var rows=d&&d.results||[],warn=d&&d.lookup_status==='IDENTITY_CONFLICT';cards={};
        if(!rows.length){r.innerHTML=(warn?'<div style="padding:8px;margin:6px;background:#FEF2F2;border:1px solid #FECACA;border-radius:8px;color:#B91C1C;font-size:10px;font-weight:700;">IDENTITY_CONFLICT · revisa el identificador compartido.</div>':'')+'<div class="ld">Sin resultados</div>';return;}
        var html=warn?'<div style="padding:8px;margin:6px;background:#FFF7ED;border:1px solid #FED7AA;border-radius:8px;color:#C2410C;font-size:10px;font-weight:700;">Hay un identificador compartido. La ficha actual se abrirá únicamente por su ID canónico.</div>':'';
        html+=rows.map(function(p){
          var cid=p.canonical_patient_id||'',n=((p.nombres||'')+' '+(p.apellidos||'')).trim(),e=(p.estado||'PROSPECTO').toUpperCase(),bc=e==='PACIENTE'||e==='ACTIVO'?'bg-pac':e==='PROSPECTO'||e==='NUEVO'?'bg-pros':'bg-inact';cards[cid]=p;
          var hist=p.identity_status==='REVIEW_REQUIRED'?'<span class="pt-bg" style="background:#FFF7ED;color:#C2410C;">HISTÓRICO REVIEW</span>':'<span class="pt-bg" style="background:#F8FAFC;color:#475569;">HISTÓRICO '+esc(p.identity_status||'SIN REVIEW')+'</span>';
          return '<div class="pt-c" data-cid="'+esc(cid)+'" onclick="ptSelCurrent(\''+esc(cid)+'\')"><div class="pt-cn">'+esc(n||'Sin nombre')+'</div><div class="pt-cm">'+esc(p.telefono||'')+(p.dni?' · '+esc(p.dni):'')+'</div><div class="pt-cb"><span class="pt-bg '+bc+'">'+esc(e)+'</span><span class="pt-bg" style="background:#ECFDF5;color:#047857;">ACTUAL RESOLVED</span>'+hist+(p.sede?'<span class="pt-bg" style="background:#EBF2FF;color:#0A4FBF;">'+esc(p.sede)+'</span>':'')+'</div></div>';
        }).join('');r.innerHTML=html;
      },function(){r.innerHTML='<div class="ld">Error de búsqueda</div>';});
    },250);
  };

  function renderCurrent(d){
    window.PT.data=d;window.PT.sel=d.paciente;window.PT.tab='cotizaciones';baseRender360(d);augment(d);
    var rt=document.getElementById('pt-right');if(rt)rt.classList.toggle('hidden',!d.clinical_access);
    if(typeof window.renderNotas==='function')window.renderNotas(d.notas||[]);
  }

  function loadCurrent(cid,allowRepair){
    window._rpc('aos_patient_360_current_v3',{p_token:token(),p_canonical_patient_id:cid},function(d){
      if(d&&d.found){renderCurrent(d);return;}
      var status=d&&d.identity_resolution&&d.identity_resolution.status||'';
      if(status==='CANONICAL_TARGET_MISSING'){
        showError('El registro canónico actual '+cid+' ya no existe o fue fusionado. No se modificó ningún dato.');return;
      }
      if(allowRepair){
        bridgeReadyPromise=null;
        ensurePatientBridge(true).then(function(ok){
          if(ok){loadCurrent(cid,false);return;}
          showError('El puente seguro de Pacientes está desactualizado o no pudo activarse. Recarga ASCENDA e inicia sesión nuevamente.');
        });return;
      }
      showError('No se pudo validar el registro canónico actual '+cid+' mediante el puente seguro. No se modificó ningún dato.');
    },function(){
      if(allowRepair){
        bridgeReadyPromise=null;
        ensurePatientBridge(true).then(function(ok){
          if(ok){loadCurrent(cid,false);return;}
          showError('El puente seguro de Pacientes está desactualizado o no pudo activarse. Recarga ASCENDA e inicia sesión nuevamente.');
        });return;
      }
      showError('Error al cargar Pacientes 360 mediante el puente seguro. El registro actual no fue modificado.');
    });
  }

  window.ptSelCurrent=function(cid){
    cid=String(cid||'').trim();if(!cid){showError('Paciente canónico inválido.');return;}
    document.querySelectorAll('.pt-c').forEach(function(c){c.classList.toggle('act',c.getAttribute('data-cid')===cid);});
    var f=document.getElementById('pt-ficha'),empty=document.getElementById('pt-empty');if(empty)empty.style.display='none';if(!f)return;f.style.display='block';f.innerHTML='<div class="ld"><span class="sp"></span>Cargando Pacientes 360...</div>';
    ensurePatientBridge(false).then(function(ok){
      if(!ok){showError('No está disponible el puente seguro de Pacientes. Recarga ASCENDA e inicia sesión nuevamente.');return;}
      loadCurrent(cid,true);
    });
  };

  // Compatibility for old buttons that still pass a phone number. Resolve once through
  // governed search, then open the returned canonical current ID. Never auto-merge.
  window.ptSel=function(value){
    value=String(value||'').trim();if(/^P-/i.test(value)){window.ptSelCurrent(value);return;}
    window._rpc('aos_patient_search_v2',{p_token:token(),p_query:value,p_limit:10},function(d){
      var rows=d&&d.results||[];
      if(rows.length===1&&rows[0].canonical_patient_id){window.ptSelCurrent(rows[0].canonical_patient_id);return;}
      showError(rows.length>1?'El teléfono corresponde a más de un paciente actual. Selecciona la ficha por nombre.':'No se encontró un paciente actual para ese identificador.');
    },function(){showError('No se pudo resolver el botón legado hacia un paciente actual.');});
  };

  window.render360=function(d){baseRender360(d);augment(d);};
  function augment(d){
    var root=document.getElementById('pt-ficha');if(!root||root.querySelector('[data-p360v3="identity"]'))return;
    var id=d.identity||{},conf=d.identity_confidence||{},life=d.lifecycle||{},link=d.legacy_link_status||'UNKNOWN';
    var fh=root.querySelector('.fh');if(fh){fh.insertAdjacentHTML('afterend','<div data-p360v3="identity" style="margin-bottom:10px;padding:10px 12px;background:#F8FAFF;border:1px solid #DDE4F5;border-radius:10px;"><div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;"><span style="font-family:\'Exo 2\',sans-serif;font-weight:800;font-size:11px;color:#0D1B3E;">Paciente actual · '+esc(id.canonical_patient_id||'')+'</span><span class="pt-bg" style="background:#ECFDF5;color:#047857;">ACTUAL '+esc(id.current_status||'RESOLVED')+'</span><span class="pt-bg" style="background:'+(id.historical_review_required?'#FFF7ED;color:#C2410C':'#F8FAFC;color:#475569')+';">HISTÓRICO '+esc(id.historical_status||'—')+'</span><span class="pt-bg" style="background:#EEF2FF;color:#4338CA;">Confianza '+esc(conf.confidence_level||'—')+'</span></div><div style="margin-top:6px;font-size:9px;color:#64748B;">360 core: '+esc(link)+' · lifecycle: '+esc(life.lifecycle_state||life.classification_status||'—')+' · el histórico pendiente no bloquea esta ficha.</div></div>');}
    var fkr=root.querySelector('.fkr');if(fkr){fkr.insertAdjacentHTML('afterend','<div data-p360v3="trust" style="margin:0 0 10px;padding:9px 12px;background:#0F172A;color:#E2E8F0;border-radius:10px;font-size:9px;line-height:1.5;"><b style="color:white;">Revenue enrichment</b> · F5/F6 se muestra como contexto gobernado. 2024/2025 transaccional sigue siendo NO_CERTIFIED_SOURCE hasta que exista fuente certificada.</div>');}
  }
}
install();
})();
