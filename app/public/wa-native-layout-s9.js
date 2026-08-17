// ASCENDA Conversations — S9 deterministic workspace geometry + self-heal.
(function(){
'use strict';
var WRAP_TRIES=0,WRAP_MAX=80;
function el(id){return document.getElementById(id);}
function remember(key,val){try{localStorage.setItem(key,val?'1':'0');}catch(_){}}
function read(key,def){try{var v=localStorage.getItem(key);return v==null?def:v!=='0';}catch(_){return def;}}
function inject(){
  if(el('aos-wa9-layout-style'))return;
  var s=document.createElement('style');
  s.id='aos-wa9-layout-style';
  s.textContent='\
#aos-wa-native{position:absolute!important;inset:0!important;width:100%!important;height:100%!important;min-width:0!important;min-height:0!important;overflow:hidden!important}#wa8-grid{display:flex!important;flex-direction:row!important;align-items:stretch!important;width:100%!important;height:100%!important;min-width:0!important;min-height:0!important;overflow:hidden!important;grid-template-columns:none!important}.wa8-left{display:flex!important;flex:0 0 300px!important;width:300px!important;max-width:300px!important;min-width:0!important;height:100%!important;overflow:hidden!important}.wa8-center{display:flex!important;flex:1 1 auto!important;width:auto!important;min-width:360px!important;height:100%!important;overflow:hidden!important}.wa8-right{display:block!important;flex:0 0 340px!important;width:340px!important;max-width:340px!important;min-width:0!important;height:100%!important;overflow-y:auto!important;overflow-x:hidden!important}.wa9-left-closed .wa8-left{display:none!important}.wa9-right-closed .wa8-right{display:none!important}.wa9-center-only .wa8-center{min-width:0!important}@media(max-width:1180px){.wa8-left{flex-basis:260px!important;width:260px!important;max-width:260px!important}.wa8-right{flex-basis:300px!important;width:300px!important;max-width:300px!important}.wa8-center{min-width:320px!important}}@media(max-width:900px){.wa8-right{display:none!important}.wa8-center{min-width:300px!important}}';
  document.head.appendChild(s);
}
function geometry(){
  var g=el('wa8-grid'),l=document.querySelector('#wa8-grid .wa8-left'),c=document.querySelector('#wa8-grid .wa8-center'),r=document.querySelector('#wa8-grid .wa8-right');
  if(!g||!l||!c||!r)return null;
  var gr=g.getBoundingClientRect(),lr=l.getBoundingClientRect(),cr=c.getBoundingClientRect(),rr=r.getBoundingClientRect();
  return {grid:Math.round(gr.width),left:Math.round(lr.width),center:Math.round(cr.width),right:Math.round(rr.width),height:Math.round(gr.height)};
}
function expose(reason){
  var d=geometry();
  window.AOS_WA_LAYOUT_DIAG={version:'S9',reason:reason||'check',geometry:d,at:new Date().toISOString()};
  return d;
}
function applyState(state,reason){
  inject();
  var ws=el('workspace'),g=el('wa8-grid');if(!g)return false;
  if(ws){ws.style.overflow='hidden';ws.scrollTop=0;ws.scrollLeft=0;}
  g.classList.remove('left-closed','right-closed');
  g.classList.toggle('wa9-left-closed',!state.left);
  g.classList.toggle('wa9-right-closed',!state.right);
  g.classList.toggle('wa9-center-only',!state.left&&!state.right);
  remember('aos_wa_s9_left_open',state.left);remember('aos_wa_s9_right_open',state.right);
  var d=expose(reason||'apply');
  if(!d)return false;
  var bad=d.grid<500||d.center<300||(state.left&&d.left<180)||(state.right&&window.innerWidth>900&&d.right<220);
  if(bad){
    g.classList.remove('wa9-left-closed','wa9-right-closed');state.left=true;state.right=window.innerWidth>900;remember('aos_wa_s9_left_open',state.left);remember('aos_wa_s9_right_open',state.right);
    requestAnimationFrame(function(){expose('self-heal');});
  }
  return true;
}
function bindToggles(state){
  var l=el('wa8-left-toggle'),r=el('wa8-right-toggle');
  if(l)l.onclick=function(ev){if(ev){ev.preventDefault();ev.stopPropagation();}state.left=!state.left;applyState(state,'toggle-left');};
  if(r)r.onclick=function(ev){if(ev){ev.preventDefault();ev.stopPropagation();}state.right=!state.right;applyState(state,'toggle-right');};
}
function stabilize(state){
  var tries=0;
  function tick(){
    tries++;
    if(el('wa8-grid')){applyState(state,tries===1?'mount':'stabilize-'+tries);bindToggles(state);}
    if(tries<12)setTimeout(tick,tries<4?80:220);
  }
  tick();
}
function wrap(){
  WRAP_TRIES++;
  if(!window.AOS_WA_NATIVE||typeof window.AOS_WA_NATIVE.mount!=='function'){
    if(WRAP_TRIES<WRAP_MAX)setTimeout(wrap,50);return;
  }
  if(window.AOS_WA_NATIVE.__s9Wrapped){
    if(el('wa8-grid'))stabilize({left:read('aos_wa_s9_left_open',true),right:read('aos_wa_s9_right_open',true)});
    return;
  }
  var baseMount=window.AOS_WA_NATIVE.mount,baseUnmount=window.AOS_WA_NATIVE.unmount;
  window.AOS_WA_NATIVE.mount=function(viewId){
    var state={left:read('aos_wa_s9_left_open',true),right:read('aos_wa_s9_right_open',true)};
    baseMount(viewId);
    stabilize(state);
  };
  window.AOS_WA_NATIVE.unmount=function(){try{var ws=el('workspace');if(ws)ws.style.overflow='';}catch(_){}return baseUnmount.apply(this,arguments);};
  window.AOS_WA_NATIVE.__s9Wrapped=true;
  window.AOS_WA_NATIVE.layoutDiagnostics=function(){return expose('manual');};
  // If S8 mounted before this script was injected, repair that existing DOM immediately.
  if(el('wa8-grid'))stabilize({left:true,right:window.innerWidth>900});
}
wrap();
})();
