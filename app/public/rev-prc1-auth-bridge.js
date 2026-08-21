// ASCENDA OS — REV-PRC1 Auth Bridge v1
// Keeps Product Resolution Center inside the existing Auth V3/2FA boundary.
(function(){
'use strict';
if(window.__AOS_REV_PRC1_AUTH_BRIDGE__)return;
window.__AOS_REV_PRC1_AUTH_BRIDGE__=true;

var downstreamFetch=window.fetch.bind(window);
var ALLOWED={
  aos_product_review_admin_v1:1,
  aos_product_review_admin_v2:1,
  aos_product_review_resolve_v2:1,
  aos_product_review_reopen_v1:1,
  aos_product_batch_review_v1:1
};

function rpcName(input){
  var u=typeof input==='string'?input:(input&&input.url)||'';
  var m=u.match(/\/rest\/v1\/rpc\/([^?]+)/);
  return m&&m[1]||'';
}
function parseBody(init){
  try{return JSON.parse((init&&init.body)||'{}');}catch(e){return {};}
}
function unique(xs){
  var out=[];
  (xs||[]).forEach(function(x){x=String(x||'').trim();if(x&&out.indexOf(x)<0)out.push(x);});
  return out;
}
function sessionToken(){
  try{return String(sessionStorage.getItem('aos_app_token')||'').trim();}catch(e){return '';}
}
function cacheToken(){
  if(!('caches' in window))return Promise.resolve('');
  return caches.open('aos-phase2-auth').then(function(c){return c.match('/__aos_app_token');}).then(function(r){return r?r.text():'';}).then(function(t){return String(t||'').trim();}).catch(function(){return '';});
}
function tokenCandidates(){
  var first=sessionToken();
  return cacheToken().then(function(cached){return unique([first,cached]);});
}
function rememberToken(t){
  t=String(t||'').trim();if(!t)return;
  try{sessionStorage.setItem('aos_app_token',t);}catch(e){}
  if('caches' in window){
    try{caches.open('aos-phase2-auth').then(function(c){return c.put('/__aos_app_token',new Response(t));}).catch(function(){});}catch(e){}
  }
}
function authError(d,status){
  var e=String(d&&d.error||d&&d.message||'').toUpperCase();
  return status===401||status===403||e==='UNAUTHORIZED'||e==='F4_STRONG_SESSION_REQUIRED'||e==='APP_SESSION_REQUIRED';
}
function synthetic(obj,status){
  return new Response(JSON.stringify(obj),{status:status||200,headers:{'Content-Type':'application/json','Cache-Control':'no-store','X-Ascenda-PRC1-Bridge':'browser-v1'}});
}
function proxy(name,payload,token){
  return downstreamFetch('/api/prc1/rpc',{
    method:'POST',
    headers:{'Content-Type':'application/json','Accept':'application/json','X-AOS-App-Token':token},
    body:JSON.stringify({name:name,payload:payload||{}}),
    cache:'no-store',credentials:'same-origin'
  });
}
function bridgedRpc(name,payload){
  delete payload.p_token;
  return tokenCandidates().then(function(tokens){
    if(!tokens.length)return synthetic({ok:false,error:'F4_STRONG_SESSION_REQUIRED'},401);
    var i=0,last=null;
    function attempt(){
      if(i>=tokens.length)return last||synthetic({ok:false,error:'F4_STRONG_SESSION_REQUIRED'},401);
      var token=tokens[i++];
      return proxy(name,payload,token).then(function(r){
        last=r;
        return r.clone().json().catch(function(){return null;}).then(function(d){
          if(authError(d,r.status)&&i<tokens.length)return attempt();
          if(r.ok&&d&&d.ok===true)rememberToken(token);
          return r;
        });
      });
    }
    return attempt();
  });
}

window.fetch=function(input,init){
  var name=rpcName(input);
  if(!ALLOWED[name])return downstreamFetch(input,init);
  return bridgedRpc(name,parseBody(init));
};
})();
