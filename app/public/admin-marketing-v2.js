/* ASCENDA CIA Phase 5 — preserve Marketing V2 + add central audience entry */
(function(){
  'use strict';
  function injectAudienceEntry(){
    setTimeout(function(){
      try{
        var role=(window.AOS&&AOS.role)||'';
        if(role!=='ADMIN') return;
        if(document.getElementById('mk-audiencias-btn')) return;
        var hdr=document.querySelector('.mk-hdr > div:last-child')||document.querySelector('.mk-hdr');
        if(!hdr) return;
        var b=document.createElement('button');
        b.id='mk-audiencias-btn';
        b.className='mk-inv';
        b.style.background='linear-gradient(135deg,#7C3AED,#0A4FBF)';
        b.textContent='🧠 Bases & Audiencias';
        b.title='Abrir el panel central de inteligencia comercial';
        b.onclick=function(){window.open('/admin-audiencias.html','_blank','noopener');};
        hdr.appendChild(b);
      }catch(e){console.warn('[CIA] No se pudo inyectar acceso de Audiencias',e);}
    },0);
  }
  var s=document.createElement('script');
  s.src='/admin-marketing-v2-original.js?v='+(typeof _APP_VERSION!=='undefined'?_APP_VERSION:Date.now());
  s.onload=injectAudienceEntry;
  s.onerror=function(){console.error('[Marketing] Error cargando adapter V2 original');injectAudienceEntry();};
  document.head.appendChild(s);
})();
