/* ASCENDA CLINIC — LOGIN V4 · visual/branding adapter only */
(function(){
'use strict';
var BRAND='ASCENDA CLINIC';
function qs(s,r){return (r||document).querySelector(s)}
function qsa(s,r){return Array.prototype.slice.call((r||document).querySelectorAll(s))}
function setText(sel,value){var n=qs(sel);if(n)n.textContent=value}
function ensureChip(){
  var head=qs('.head');if(!head||qs('.clinic-chip',head.parentNode))return;
  var chip=document.createElement('div');chip.className='clinic-chip';chip.textContent='Acceso protegido · 2FA';
  head.parentNode.insertBefore(chip,head);
}
function brandInitial(){
  document.title=BRAND+' — Iniciar sesión';
  var app=qs('meta[name="application-name"]');if(app)app.setAttribute('content',BRAND);
  var apple=qs('meta[name="apple-mobile-web-app-title"]');if(apple)apple.setAttribute('content',BRAND);
  setText('.brand','');
  var brand=qs('.brand');
  if(brand){brand.appendChild(document.createTextNode('ASCENDA '));var span=document.createElement('span');span.textContent='CLINIC';brand.appendChild(span);}
  var img=qs('.logo img');if(img)img.alt=BRAND;
  setText('#login','Ingresar');
  setText('.muted','ASCENDA CLINIC · acceso seguro');
  setText('.install-title','📲 Instalar ASCENDA CLINIC');
  var note=qs('#installNote');if(note&&/AscendaOS|Acceso rápido/.test(note.textContent||''))note.textContent='Acceso rápido y seguro desde tu pantalla de inicio.';
  ensureChip();
  var card=qs('#card');
  if(card&&!qs('.clinic-security-note',card)){
    var n=document.createElement('div');n.className='clinic-security-note';n.innerHTML='<span class="clinic-security-dot"></span><span>Sesión protegida por autenticación de dos pasos</span>';card.appendChild(n);
  }
}
function syncOtp(input,cells){
  var v=String(input.value||'').replace(/\D/g,'').slice(0,6);
  cells.forEach(function(cell,i){
    cell.textContent=v.charAt(i)||'';
    cell.classList.toggle('filled',i<v.length);
    var active=document.activeElement===input && i===Math.min(v.length,5);
    cell.classList.toggle('active',active);
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
  var p=qs('.head p');if(p&&p.textContent.indexOf('Código enviado')>=0)p.insertAdjacentHTML('beforeend','<br><span style="font-size:11px;color:#8b9ab7">Ingresa los 6 dígitos para continuar.</span>');
  var verify=qs('#verify');if(verify)verify.textContent='Verificar e ingresar';
  ensureChip();
}
function reconcile(){
  brandInitial();
  enhanceOtp();
}
var obs=new MutationObserver(function(){reconcile()});
document.addEventListener('DOMContentLoaded',function(){
  reconcile();
  obs.observe(document.documentElement,{childList:true,subtree:true});
});
})();