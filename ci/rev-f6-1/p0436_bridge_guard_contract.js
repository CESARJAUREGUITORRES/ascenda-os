'use strict';
const fs=require('fs');
const vm=require('vm');
const assert=require('assert');
const src=fs.readFileSync('app/public/patients-f6-v2.js','utf8');
const wait=(ms)=>new Promise(resolve=>setTimeout(resolve,ms));
function baseDom(){
  const ficha={style:{},innerHTML:'',querySelector:function(){return null;}};
  const empty={style:{}};const right={classList:{toggle:function(){}}};
  return {ficha,document:{getElementById:function(id){if(id==='pt-ficha')return ficha;if(id==='pt-empty')return empty;if(id==='pt-right')return right;return {style:{},innerHTML:'',querySelector:function(){return null;},classList:{toggle:function(){}}};},querySelectorAll:function(){return [];}}};
}
function workerReady(){
  let updates=0;const sw={controller:{version:'current'},getRegistration:function(){return Promise.resolve(reg);},register:function(){throw new Error('unexpected register');},addEventListener:function(){},removeEventListener:function(){}};
  const reg={installing:null,waiting:null,update:function(){updates++;return Promise.resolve(reg);}};
  return {sw,updates:function(){return updates;}};
}
async function coreFirstSerialScenario(){
  const dom=baseDom(),w=workerReady();let renderCount=0;const calls=[];
  const win={PT:{},render360:function(){renderCount++;},h:function(v){return String(v==null?'':v);},_rpc:function(name,params,ok,err){
    calls.push(name+(params.p_section?':'+params.p_section:''));
    if(name==='aos_patient_360_current_v3'){
      assert.strictEqual(renderCount,0,'core cannot render before V3 success');
      ok({ok:true,found:true,paciente:{id:'P-5549'},identity:{canonical_patient_id:'P-5549'},identity_confidence:{enrichment_status:'DEFERRED'},lifecycle:{enrichment_status:'DEFERRED'},notas:[]});return;
    }
    if(name==='aos_patient_360_enrichment_v1'&&params.p_section==='IDENTITY_CONFIDENCE'){
      assert.strictEqual(renderCount,1,'operational record must render before identity enrichment starts');
      ok({ok:true,found:true,payload:{confidence_level:'MEDIUM'}});return;
    }
    if(name==='aos_patient_360_enrichment_v1'&&params.p_section==='LIFECYCLE'){
      assert.strictEqual(renderCount,1,'operational record stays rendered while lifecycle loads');
      assert.ok(calls.includes('aos_patient_360_enrichment_v1:IDENTITY_CONFIDENCE'),'identity must precede lifecycle');
      ok({ok:true,found:true,payload:{lifecycle_state:'ACTIVE_REPEAT'}});return;
    }
    if(err)err();else throw new Error('unexpected RPC '+name);
  }};
  vm.runInNewContext(src,{window:win,navigator:{serviceWorker:w.sw},document:dom.document,sessionStorage:{getItem:function(){return 'browser-token-not-authority';}},setTimeout,clearTimeout,Promise,console,URL},{filename:'patients-f6-v2.js'});
  await wait(10);assert.strictEqual(win.__AOS_PATIENT_BRIDGE_GUARD__,'p0436-v2-hotpath');win.ptSelCurrent('P-5549');await wait(30);
  assert.strictEqual(renderCount,1,'operational Patient 360 must render exactly once');
  assert.deepStrictEqual(calls,['aos_patient_360_current_v3','aos_patient_360_enrichment_v1:IDENTITY_CONFIDENCE','aos_patient_360_enrichment_v1:LIFECYCLE'],'deferred enrichment must be serial, not fan-out');
  assert.ok(w.updates()>=1,'worker readiness must still be checked');
}
async function noHeavyRetryScenario(){
  const dom=baseDom(),w=workerReady();let v3=0,enrich=0,renderCount=0;
  const win={PT:{},render360:function(){renderCount++;},h:function(v){return String(v==null?'':v);},_rpc:function(name,params,ok,err){if(name==='aos_patient_360_current_v3'){v3++;if(err)err();return;}if(name==='aos_patient_360_enrichment_v1'){enrich++;return;}throw new Error('unexpected RPC '+name);}};
  vm.runInNewContext(src,{window:win,navigator:{serviceWorker:w.sw},document:dom.document,sessionStorage:{getItem:function(){return '';}},setTimeout,clearTimeout,Promise,console,URL},{filename:'patients-f6-v2.js'});
  await wait(10);win.ptSelCurrent('P-6000');await wait(30);
  assert.strictEqual(v3,1,'operational timeout/error must not create a second heavy V3 request');
  assert.strictEqual(enrich,0,'enrichment must never start when operational core failed');
  assert.strictEqual(renderCount,0,'failed operational core must not render false data');
}
(async function(){await coreFirstSerialScenario();await noHeavyRetryScenario();console.log('P0436_PATIENT_HOTPATH_SERIAL_ENRICHMENT_CONTRACT_PASS');})().catch(function(err){console.error(err&&err.stack||err);process.exit(1);});
