// ASCENDA Auth V3 — cookie-session logout compatibility bridge.
(function(){
'use strict';
var tries=0;
function clearLegacy(){
  try{sessionStorage.removeItem('aos_app_token');sessionStorage.removeItem('aos_si_token');sessionStorage.removeItem('aos_si_expires_at');}catch(_){}
  try{if('caches' in window)caches.open('aos-phase2-auth').then(function(c){return c.delete('/__aos_app_token');}).catch(function(){});}catch(_){}
}
function install(){
  tries++;
  if(typeof window.doLogout!=='function'){
    if(tries<100)setTimeout(install,100);
    return;
  }
  if(window.doLogout.__aosCookieWrapped)return;
  var base=window.doLogout;
  var wrapped=function(){
    clearLegacy();
    try{fetch('/api/auth/v3/logout',{method:'POST',credentials:'same-origin',cache:'no-store',keepalive:true}).catch(function(){});}catch(_){}
    return base.apply(this,arguments);
  };
  wrapped.__aosCookieWrapped=true;
  window.doLogout=wrapped;
}
install();
})();
