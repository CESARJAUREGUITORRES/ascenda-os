// ASCENDA OS — F4 KronIA revenue proof bridge.
(function(){
'use strict';
if(window.__AOS_F4_KRONIA_REVENUE__)return;window.__AOS_F4_KRONIA_REVENUE__=true;
var previousFetch=window.fetch.bind(window);
function token(){try{return sessionStorage.getItem('aos_app_token')||''}catch(e){return ''}}
function urlOf(input){return typeof input==='string'?input:(input&&input.url)||''}
window.fetch=function(input,init){
  var url=urlOf(input),method=String((init&&init.method)||((input&&input.method)||'GET')).toUpperCase();
  try{
    var u=new URL(url,location.href);
    if(u.origin===location.origin&&u.pathname==='/api/kronia/chat'&&method==='POST'){
      var next=Object.assign({},init||{});var h=new Headers((init&&init.headers)||((input&&input.headers)||{}));var t=token();if(t)h.set('X-AOS-App-Token',t);next.headers=h;return previousFetch(input,next);
    }
  }catch(e){}
  return previousFetch(input,init);
};
})();
