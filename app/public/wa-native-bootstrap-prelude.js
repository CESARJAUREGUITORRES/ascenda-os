// ASCENDA Conversations — PHASE S S5 native bootstrap prelude.
// Runs before WA-3 inline app code inside the same-origin embedded Hub.
(function(){
'use strict';
var RETRYABLE={403:1,502:1,503:1,504:1};
try{
  if(window.parent&&window.parent!==window){
    var p=window.parent.sessionStorage;
    var t=p.getItem('aos_app_token')||p.getItem('aos_si_token')||'';
    if(String(t).trim().length>=32)sessionStorage.setItem('aos_app_token',String(t).trim());
  }
}catch(e){console.warn('[WA-S5] parent token sync skipped',e);}

var baseFetch=window.fetch.bind(window);
window.fetch=function(input,init){
  var url='';
  try{url=typeof input==='string'?input:String(input&&input.url||'');}catch(_){url='';}
  if(url.indexOf('/api/wa3/bootstrap')<0)return baseFetch(input,init);
  var attempt=0;
  function run(){
    attempt++;
    return baseFetch(input,init).then(function(r){
      if(r.ok||!RETRYABLE[r.status]||attempt>=5)return r;
      var wait=Math.min(1200,200*attempt);
      return new Promise(function(resolve){setTimeout(resolve,wait);}).then(run);
    });
  }
  return run();
};
})();
