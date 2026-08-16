// ASCENDA Conversations — WA-3 cross-tab session bridge.
// Hydrates the existing 2FA application token from the same-origin Phase 2 cache
// when WA-3 is opened in a different browser tab. No token is persisted beyond
// the existing governed cache/sessionStorage locations.
(function(){
'use strict';

function sessionToken(){
  try{return sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||'';}catch(e){return '';}
}

async function bridgeToken(){
  var current=sessionToken();
  if(current)return current;
  if(!('caches' in window))return '';
  try{
    var cache=await caches.open('aos-phase2-auth');
    var response=await cache.match('/__aos_app_token');
    var token=response?String(await response.text()).trim():'';
    if(token.length>=32){
      try{sessionStorage.setItem('aos_app_token',token);}catch(e){}
      return token;
    }
  }catch(e){}
  return '';
}

window.ASCENDA_WA3_SESSION_BRIDGE={getToken:bridgeToken,sessionToken:sessionToken};
})();
