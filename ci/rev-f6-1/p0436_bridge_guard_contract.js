'use strict';
const fs=require('fs');
const vm=require('vm');
const assert=require('assert');
const src=fs.readFileSync('app/public/patients-f6-v2.js','utf8');
const wait=(ms)=>new Promise(resolve=>setTimeout(resolve,ms));

function baseDom(){
  const ficha={style:{},innerHTML:'',querySelector:function(){return null;}};
  const empty={style:{}};
  return {
    ficha,
    document:{
      getElementById:function(id){if(id==='pt-ficha')return ficha;if(id==='pt-empty')return empty;return {style:{},innerHTML:'',querySelector:function(){return null;}};},
      querySelectorAll:function(){return [];}
    }
  };
}

async function activationScenario(){
  const dom=baseDom();
  let updateCount=0,activateCount=0,v3Calls=0,renderCount=0;
  const controllerListeners=[];
  const stateListeners=[];
  const serviceWorker={
    controller:null,
    getRegistration:function(){return Promise.resolve(reg);},
    register:function(){throw new Error('registration should already exist');},
    addEventListener:function(type,fn){if(type==='controllerchange')controllerListeners.push(fn);},
    removeEventListener:function(type,fn){if(type!=='controllerchange')return;const i=controllerListeners.indexOf(fn);if(i>=0)controllerListeners.splice(i,1);}
  };
  const waiting={
    state:'installed',
    addEventListener:function(type,fn){if(type==='statechange')stateListeners.push(fn);},
    postMessage:function(msg){
      assert.strictEqual(msg.type,'ASCENDA_ACTIVATE_NOW');
      activateCount++;
      waiting.state='activated';
      serviceWorker.controller={version:'current'};
      stateListeners.slice().forEach(fn=>fn());
      controllerListeners.slice().forEach(fn=>fn());
    }
  };
  const reg={installing:null,waiting:waiting,update:function(){updateCount++;return Promise.resolve(reg);}};
  const win={
    PT:{},
    render360:function(){renderCount++;},
    h:function(v){return String(v==null?'':v);},
    _rpc:function(name,params,ok){
      if(name!=='aos_patient_360_current_v3')throw new Error('unexpected RPC '+name);
      v3Calls++;
      assert.ok(serviceWorker.controller,'V3 RPC must run only after worker controller takeover');
      assert.strictEqual(params.p_canonical_patient_id,'P-5549');
      ok({found:true,paciente:{id:'P-5549'},identity:{canonical_patient_id:'P-5549'},identity_confidence:{},lifecycle:{},notas:[]});
    }
  };
  const context={
    window:win,navigator:{serviceWorker},document:dom.document,
    sessionStorage:{getItem:function(){return 'browser-token-is-not-authority-1234567890';}},
    setTimeout,clearTimeout,Promise,console,URL
  };
  vm.runInNewContext(src,context,{filename:'patients-f6-v2.js'});
  await wait(20);
  assert.strictEqual(win.__AOS_PATIENT_BRIDGE_GUARD__,'p0436-v1');
  win.ptSelCurrent('P-5549');
  await wait(20);
  assert.ok(updateCount>=1,'bridge guard must call registration.update()');
  assert.strictEqual(activateCount,1,'waiting canonical worker must be activated exactly once');
  assert.strictEqual(v3Calls,1,'canonical Patient 360 should execute once after bridge readiness');
  assert.strictEqual(renderCount,1,'successful canonical record must render');
}

async function retryScenario(){
  const dom=baseDom();
  let updateCount=0,v3Calls=0,renderCount=0;
  const serviceWorker={
    controller:{version:'current'},
    getRegistration:function(){return Promise.resolve(reg);},
    register:function(){throw new Error('registration should already exist');},
    addEventListener:function(){},removeEventListener:function(){}
  };
  const reg={installing:null,waiting:null,update:function(){updateCount++;return Promise.resolve(reg);}};
  const win={
    PT:{},
    render360:function(){renderCount++;},
    h:function(v){return String(v==null?'':v);},
    _rpc:function(name,params,ok){
      if(name!=='aos_patient_360_current_v3')throw new Error('unexpected RPC '+name);
      v3Calls++;
      if(v3Calls===1){ok({ok:false,found:false});return;}
      ok({found:true,paciente:{id:'P-6000'},identity:{canonical_patient_id:'P-6000'},identity_confidence:{},lifecycle:{},notas:[]});
    }
  };
  const context={
    window:win,navigator:{serviceWorker},document:dom.document,
    sessionStorage:{getItem:function(){return ''; }},
    setTimeout,clearTimeout,Promise,console,URL
  };
  vm.runInNewContext(src,context,{filename:'patients-f6-v2.js'});
  await wait(10);
  win.ptSelCurrent('P-6000');
  await wait(30);
  assert.strictEqual(v3Calls,2,'non-canonical-missing failure may receive exactly one controlled repair retry');
  assert.ok(updateCount>=2,'repair retry must refresh bridge readiness instead of bypassing worker authority');
  assert.strictEqual(renderCount,1,'retry success must render exactly once');
}

(async function(){
  await activationScenario();
  await retryScenario();
  console.log('P0436_PATIENT_BRIDGE_GUARD_CONTRACT_PASS');
})().catch(function(err){console.error(err&&err.stack||err);process.exit(1);});
