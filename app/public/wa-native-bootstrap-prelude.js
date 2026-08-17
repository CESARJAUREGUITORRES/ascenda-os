// ASCENDA Conversations — PHASE S S7 minimal native bootstrap bridge.
// Deliberately contains no layout/Lead-360 mutations. Authentication authority
// is moving to the same-origin HttpOnly session cookie at PHASE S.
(function(){
'use strict';
var RETRYABLE={502:1,503:1,504:1};
var baseFetch=window.fetch.bind(window);
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
window.fetch=function(input,init){
  if(!isWaApi(input))return baseFetch(input,init);
  var next=Object.assign({},init||{}),h;
  try{h=new Headers((init&&init.headers)||(input&&input.headers)||{});}catch(_){h=new Headers();}
  var t=legacyToken();if(t.length>=32)h.set('X-AOS-App-Token',t);
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
};
})();
