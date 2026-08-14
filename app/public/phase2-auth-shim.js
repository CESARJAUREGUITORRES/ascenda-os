// ASCENDA OS — Phase 2 auth compatibility shim.
// Keeps the existing login UI while moving proof generation/verification to v3.
(function(){
  'use strict';
  var nativeFetch=window.fetch.bind(window);
  var challengeId='';
  function urlOf(input){return typeof input==='string'?input:(input&&input.url)||'';}
  function parseBody(init){try{return JSON.parse((init&&init.body)||'{}')}catch(e){return {};}}
  function response(obj,status){return new Response(JSON.stringify(obj),{status:status||200,headers:{'Content-Type':'application/json'}});}
  function saveTokens(d){
    if(!d)return;
    var app=d.app_token||'';
    var fin=d.finance_token||app;
    try{
      if(app)sessionStorage.setItem('aos_app_token',app);
      if(fin)sessionStorage.setItem('aos_si_token',fin);
    }catch(e){}
  }
  function postRpc(url,init,name,body){
    var next=Object.assign({},init||{}, {method:'POST',body:JSON.stringify(body||{})});
    return nativeFetch(url.replace(/\/rpc\/[^/?]+(?:\?.*)?$/,'/rpc/'+name),next);
  }
  window.fetch=function(input,init){
    var url=urlOf(input);
    if(/\/rest\/v1\/rpc\/aos_login_v2(?:\?|$)/.test(url)){
      var b=parseBody(init);
      return postRpc(url,init,'aos_login_v3',{p_usuario:b.p_usuario,p_password:b.p_password}).then(function(r){
        return r.json().then(function(d){
          saveTokens(d);
          if(d&&d.require_2fa){
            challengeId=d.challenge_id||'';
            // Legacy UI expects these keys; no recipient or OTP plaintext is exposed.
            d.email=d.email_masked||'';
            d.email_real=d.email_masked||'';
            d.code='';
          }
          return response(d,r.ok?200:r.status);
        });
      });
    }
    if(/\/api\/send-2fa(?:\?|$)/.test(url) && challengeId){
      // v3 sends server-side from PostgreSQL; the browser never handles the OTP.
      return Promise.resolve(response({ok:true,delivery:'server-side-v3'},200));
    }
    if(/\/rest\/v1\/rpc\/aos_verificar_2fa(?:\?|$)/.test(url)){
      var vb=parseBody(init);
      if(!challengeId)return Promise.resolve(response({ok:false,error:'Sesión 2FA inválida. Inicia sesión nuevamente.'},401));
      return postRpc(url,init,'aos_verificar_2fa_v3',{p_challenge_id:challengeId,p_codigo:vb.p_codigo}).then(function(r){
        return r.json().then(function(d){
          if(d&&d.ok){saveTokens(d);challengeId='';}
          return response(d,r.ok?200:r.status);
        });
      });
    }
    return nativeFetch(input,init);
  };
})();
