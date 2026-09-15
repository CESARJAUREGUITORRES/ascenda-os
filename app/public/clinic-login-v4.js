/* ASCENDA CLINIC — LOGIN V4.1 · visual/branding adapter only
   P0 mobile reliability: idempotent DOM work, safe OTP observer and native install gating. */
(function(){
'use strict';
var BRAND='ASCENDA CLINIC',deferredInstall=null;
function qs(s,r){return (r||document).querySelector(s)}
function qsa(s,r){return Array.prototype.slice.call((r||document).querySelectorAll(s))}
function setText(sel,value){var n=qs(sel);if(n&&n.textContent!==value)n.textContent=value}
function isStandalone(){return !!((window.matchMedia&&window.matchMedia('(display-mode: standalone)').matches)||window.navigator.standalone===true)}

function brandInitial(){
  document.title=BRAND+' — Iniciar sesión';
  var app=qs('meta[name="application-name"]');if(app&&app.getAttribute('content')!==BRAND)app.setAttribute('content',BRAND);
  var apple=qs('meta[name="apple-mobile-web-app-title"]');if(apple&&apple.getAttribute('content')!==BRAND)apple.setAttribute('content',BRAND);
  var brand=qs('.brand');
  if(brand&&brand.dataset.clinicBrand!=='2'){
    brand.dataset.clinicBrand='2';
    brand.innerHTML='<img class="clinic-wordmark-icon" src="/ascenda-clinic-mark.svg?v=20260915-1" alt=""><span class="clinic-wordmark-text">Ascenda <strong>Clinic</strong></span>';
  }
  var img=qs('.logo img');if(img){img.alt=BRAND;img.src='/ascenda-clinic-mark.svg?v=20260915-1';}
  setText('#login','Ingresar');
  var initialMuted=qs('#card>.muted');if(initialMuted)setText('#card>.muted','ASCENDA CLINIC · acceso seguro');
  setText('.install-title','📲 Instalar ASCENDA CLINIC');
  var note=qs('#installNote');if(note&&/AscendaOS|Acceso rápido/.test(note.textContent||''))note.textContent='Acceso rápido y seguro desde tu pantalla de inicio.';
  /* V4.1: no badge 2FA and no duplicated security note. */
  qsa('.clinic-chip,.clinic-security-note').forEach(function(n){try{n.remove()}catch(_){}});
}

function syncOtp(input,cells){
  var v=String(input.value||'').replace(/\D/g,'').slice(0,6);
  cells.forEach(function(cell,i){
    cell.textContent=v.charAt(i)||'';
    cell.classList.toggle('filled',i<v.length);
    cell.classList.toggle('active',document.activeElement===input&&i===Math.min(v.length,5));
  });
}
function enhanceOtp(){
  var input=qs('#otpCode');
  if(!input||input.dataset.clinicOtp==='1')return;
  input.dataset.clinicOtp='1';
  var otp=input.closest('.otp');if(!otp)return;
  otp.classList.add('otp-segmented');
  var cellsWrap=document.createElement('div');cellsWrap.className='otp-cells';cellsWrap.setAttribute('aria-hidden','true');
  for(var i=0;i<6;i++){var c=document.createElement('span');c.className='otp-cell';cellsWrap.appendChild(c)}
  otp.insertBefore(cellsWrap,input);
  var cells=qsa('.otp-cell',cellsWrap);
  function render(){syncOtp(input,cells)}
  input.addEventListener('input',render);
  input.addEventListener('focus',render);
  input.addEventListener('blur',render);
  input.addEventListener('paste',function(){setTimeout(render,0)});
  otp.addEventListener('click',function(){input.focus()});
  render();
  var h=qs('.head h2');if(h)h.textContent='Verificación de seguridad';
  var p=qs('.head p');if(p&&p.textContent.indexOf('Código enviado')>=0&&!p.dataset.clinicHelp){
    p.dataset.clinicHelp='1';
    p.insertAdjacentHTML('beforeend','<br><span style="font-size:11px;color:#8b9ab7">Ingresa los 6 dígitos para continuar.</span>');
  }
  var verify=qs('#verify');if(verify)verify.textContent='Verificar e ingresar';
}

function setupInstallV2(){
  var box=qs('#installCta'),btn=qs('#installBtn'),note=qs('#installNote'),close=qs('#installClose');
  if(!box||!btn)return;
  if(isStandalone()){box.hidden=true;return}
  var ua=String(navigator.userAgent||''),samsung=/SamsungBrowser/i.test(ua),android=/Android/i.test(ua);
  deferredInstall=null;
  if(samsung){
    box.hidden=false;
    btn.textContent='Ver pasos';
    if(note)note.textContent='Samsung Internet: instala desde ☰ Menú → Añadir página a / Pantalla de inicio.';
  }else{
    /* Chrome/Edge: never show a fake one-tap install CTA before the browser grants the install prompt. */
    box.hidden=true;
  }
  window.addEventListener('beforeinstallprompt',function(e){
    e.preventDefault();
    deferredInstall=e;
    box.hidden=false;
    btn.hidden=false;
    btn.disabled=false;
    btn.textContent='Instalar';
    if(note)note.textContent='Instala ASCENDA CLINIC como aplicación en este dispositivo.';
  });
  window.addEventListener('appinstalled',function(){
    deferredInstall=null;
    box.hidden=true;
  });
  btn.onclick=function(){
    if(deferredInstall){
      btn.disabled=true;
      if(note)note.textContent='Abriendo instalación segura…';
      deferredInstall.prompt();
      Promise.resolve(deferredInstall.userChoice).then(function(choice){
        if(choice&&choice.outcome==='accepted'){
          deferredInstall=null;
          if(note)note.textContent='Instalando ASCENDA CLINIC…';
          setTimeout(function(){box.hidden=true},1200);
        }else{
          btn.disabled=false;
          if(note)note.textContent='Instalación cancelada. Puedes intentarlo nuevamente.';
        }
      }).catch(function(){
        btn.disabled=false;
        if(note)note.textContent='No se pudo abrir el instalador. Usa el menú del navegador → Instalar aplicación.';
      });
      return;
    }
    if(samsung){
      if(note)note.textContent='Samsung Internet: ☰ Menú → Añadir página a → Pantalla de inicio. Si el sistema bloquea la instalación, prueba Chrome.';
      return;
    }
    if(android){
      if(note)note.textContent='Chrome: ⋮ → Instalar aplicación. ASCENDA no mostrará un botón de instalación si Chrome no ha habilitado el prompt nativo.';
      btn.textContent='Ver pasos';
      box.hidden=false;
      return;
    }
    if(note)note.textContent='Usa la opción “Añadir a pantalla de inicio” de tu navegador.';
  };
  if(close)close.onclick=function(){box.hidden=true};
}

function startOtpObserver(){
  var card=qs('#card');if(!card)return;
  var obs=new MutationObserver(function(){enhanceOtp()});
  obs.observe(card,{childList:true,subtree:true});
  enhanceOtp();
}
function boot(){
  brandInitial();
  setupInstallV2();
  startOtpObserver();
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});
else boot();
})();