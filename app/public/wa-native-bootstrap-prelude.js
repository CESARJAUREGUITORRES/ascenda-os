// ASCENDA Conversations — PHASE S S7 minimal native bootstrap bridge.
// Deliberately contains no layout/Lead-360 mutations. Authentication authority
// remains the server-side strong session; the browser cache is only a continuity
// bridge for a token that was already issued after successful Auth V3/2FA.
(function(){
'use strict';
var RETRYABLE={502:1,503:1,504:1};
var baseFetch=window.fetch.bind(window);
var recoveredTokenPromise=null;
function isWaApi(input){
  var raw='';
  try{raw=typeof input==='string'?input:String(input&&input.url||'');}catch(_){return false;}
  try{var u=new URL(raw,location.href);return u.origin===location.origin&&u.pathname.indexOf('/api/wa3/')===0;}catch(_){return raw.indexOf('/api/wa3/')>=0;}
}
function isBootstrap(input){
  var raw='';try{raw=typeof input==='string'?input:String(input&&input.url||'');}catch(_){return false;}
  return raw.indexOf('/api/wa3/bootstrap')>=0;
}
function legacyToken(){
  try{return String(sessionStorage.getItem('aos_app_token')||sessionStorage.getItem('aos_si_token')||'').trim();}catch(_){return '';}
}
function cachedStrongToken(){
  if(recoveredTokenPromise)return recoveredTokenPromise;
  if(!('caches' in window))return Promise.resolve('');
  recoveredTokenPromise=caches.open('aos-phase2-auth').then(function(c){
    return c.match('/__aos_app_token');
  }).then(function(r){
    return r?r.text():'';
  }).then(function(raw){
    var t=String(raw||'').trim();
    if(t.length<32)return '';
    try{sessionStorage.setItem('aos_app_token',t);}catch(_){}
    return t;
  }).catch(function(){return '';});
  return recoveredTokenPromise;
}
function dispatchWa(input,init,t){
  var next=Object.assign({},init||{}),h;
  try{h=new Headers((init&&init.headers)||(input&&input.headers)||{});}catch(_){h=new Headers();}
  if(String(t||'').trim().length>=32)h.set('X-AOS-App-Token',String(t).trim());
  h.set('Accept','application/json');
  next.headers=h;
  next.cache='no-store';
  next.credentials='same-origin';
  if(!isBootstrap(input))return baseFetch(input,next);
  var attempt=0;
  function run(){
    attempt++;
    return baseFetch(input,next).then(function(r){
      if(r.ok||!RETRYABLE[r.status]||attempt>=5)return r;
      var wait=Math.min(1200,200*attempt);
      return new Promise(function(resolve){setTimeout(resolve,wait);}).then(run);
    });
  }
  return run();
}
window.fetch=function(input,init){
  if(!isWaApi(input))return baseFetch(input,init);
  var t=legacyToken();
  if(t.length>=32)return dispatchWa(input,init,t);
  return cachedStrongToken().then(function(recovered){return dispatchWa(input,init,recovered);});
};
})();
