// ASCENDA OS — F4 production canary P0 browser cleanup.
(function(){
'use strict';
if(window.__AOS_F4_PRODUCTION_CANARY_P0__)return;
window.__AOS_F4_PRODUCTION_CANARY_P0__=true;

function cleanCajaClosedState(){
  var box=document.getElementById('no-sesion-msg');
  if(!box)return;
  var extras=box.querySelectorAll('.btn-abrir-inline');
  Array.prototype.forEach.call(extras,function(b){b.remove();});
}

function run(){cleanCajaClosedState();}
run();

try{
  var obs=new MutationObserver(function(){run();});
  obs.observe(document.documentElement||document.body,{childList:true,subtree:true});
}catch(e){}
})();
