// KronIA Chrome — K1 Auth V3 adapter.
(function(){
  'use strict';
  if(!window.KroniaCore||window.__K1_EXT_AUTH__)return;window.__K1_EXT_AUTH__=true;
  var originalCreate=window.KroniaCore.create;
  window.KroniaCore.create=function(config){
    var core=originalCreate(config||{}),challenge='';
    core.loginRequest=function(usuario,password){
      return fetch((config&&config.baseUrl||'https://ascenda-os-production.up.railway.app')+'/api/kronia/login-request',{
        method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({usuario:usuario,password:password||''})
      }).then(function(r){return r.json()}).then(function(d){
        challenge=d&&d.challenge_id||'';
        if(d&&d.ok&&d.token){core.setToken(d.token,{usuario:d.usuario,id_asesor:d.codigo_asesor,rol:(Number(d.nivel)<=2?'ADMIN':'ASESOR'),sede:d.sede});}
        return d;
      });
    };
    core.loginVerify=function(usuario,codigo,deviceInfo){
      if(!challenge)return Promise.resolve({ok:false,error:'CHALLENGE_REQUIRED'});
      return fetch((config&&config.baseUrl||'https://ascenda-os-production.up.railway.app')+'/api/kronia/login-verify',{
        method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({challenge_id:challenge,codigo:codigo,device_info:deviceInfo||''})
      }).then(function(r){return r.json()}).then(function(d){
        if(d&&d.ok&&d.token){core.setToken(d.token,{usuario:d.usuario,id_asesor:d.codigo_asesor,rol:(Number(d.nivel)<=2?'ADMIN':'ASESOR'),sede:d.sede});challenge='';}
        return d;
      });
    };
    return core;
  };
})();
