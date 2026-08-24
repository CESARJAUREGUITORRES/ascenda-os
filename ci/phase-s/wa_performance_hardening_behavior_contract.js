'use strict';
const fs=require('fs');
const vm=require('vm');
const assert=require('assert');

function jsonResponse(n,url){
  return new Response(JSON.stringify({n,url}),{status:200,headers:{'content-type':'application/json'}});
}

async function main(){
  const source=fs.readFileSync('app/public/wa-performance-hardening.js','utf8');
  let network=0;
  let teamResolve=null;
  let queueResolve=null;
  let delayTeam=true;
  let delayQueue=true;
  const listeners={};
  const baseFetch=(input,init)=>{
    network++;
    const method=String(init&&init.method||'GET').toUpperCase();
    const url=String(input);
    if(method==='GET'&&url.indexOf('/api/wa3/team-summary')>=0&&delayTeam){
      delayTeam=false;
      const n=network;
      return new Promise(resolve=>{teamResolve=()=>resolve(jsonResponse(n,url));});
    }
    if(method==='GET'&&url.indexOf('/api/wa3/queue-summary')>=0&&delayQueue){
      delayQueue=false;
      const n=network;
      return new Promise(resolve=>{queueResolve=()=>resolve(jsonResponse(n,url));});
    }
    return Promise.resolve(jsonResponse(network,url));
  };
  const window={
    fetch:baseFetch,
    addEventListener:(name,fn)=>{listeners['w:'+name]=fn;},
    dispatchEvent:()=>{}
  };
  const document={hidden:false,addEventListener:(name,fn)=>{listeners['d:'+name]=fn;}};
  const context={
    window,document,location:new URL('https://ascenda.test/app.html'),URL,Headers,Response,
    CustomEvent:class{constructor(type,opts){this.type=type;this.detail=opts&&opts.detail;}},
    Map,Date,Promise,console
  };
  vm.createContext(context);
  vm.runInContext(source,context);
  assert(window.AOS_WA_PERF&&window.AOS_WA_PERF.installed,'perf shim did not install');

  const first=await window.fetch('/api/wa3/inbox?limit=120');
  assert.strictEqual(first.headers.get('x-aos-wa-perf'),'MISS');
  await first.text();
  const second=await window.fetch('/api/wa3/inbox?limit=120');
  assert.strictEqual(second.headers.get('x-aos-wa-perf'),'HIT');
  await second.text();
  assert.strictEqual(network,1,'second inbox read escaped cache');

  const team1=window.fetch('/api/wa3/team-summary');
  const team2=window.fetch('/api/wa3/team-summary');
  assert.strictEqual(network,2,'concurrent team reads were not coalesced');
  assert(teamResolve,'delayed team resolver missing');
  teamResolve();
  const teamRows=await Promise.all([team1,team2]);
  assert.strictEqual(teamRows[0].headers.get('x-aos-wa-perf'),'MISS');
  assert.strictEqual(teamRows[1].headers.get('x-aos-wa-perf'),'COALESCED');

  const staleQueue=window.fetch('/api/wa3/queue-summary');
  assert(queueResolve,'delayed queue resolver missing');
  await window.fetch('/api/wa3/claim-next',{method:'POST',body:'{}'});
  queueResolve();
  const retriedQueue=await staleQueue;
  assert.strictEqual(retriedQueue.headers.get('x-aos-wa-perf'),'MISS','pre-write queue read must transparently retry after invalidation');
  const beforeQueueHit=network;
  const queueHit=await window.fetch('/api/wa3/queue-summary');
  assert.strictEqual(queueHit.headers.get('x-aos-wa-perf'),'HIT','retried post-write queue snapshot should seed the new cache generation');
  assert.strictEqual(network,beforeQueueHit,'stale pre-mutation queue response should not force another network read');

  await window.fetch('/api/wa3/inbox?limit=120');
  const beforePresence=network;
  await window.fetch('/api/wa3/presence',{method:'POST',body:'{}'});
  const afterPresence=await window.fetch('/api/wa3/inbox?limit=120');
  assert.strictEqual(afterPresence.headers.get('x-aos-wa-perf'),'HIT');
  assert.strictEqual(network,beforePresence+1,'presence heartbeat invalidated read cache');

  const stats=window.AOS_WA_PERF.stats();
  assert(stats.cache_hits>=3,'expected cache hits were not recorded');
  assert(stats.coalesced>=1,'expected coalesced read was not recorded');
  assert(stats.invalidations>=1,'write invalidation was not recorded');
  assert(stats.stale_retries>=1,'stale pre-write read was not retried');
  console.log('WA_PERFORMANCE_HARDENING_BEHAVIOR_CONTRACT_PASS',stats);
}

main().catch(err=>{console.error(err);process.exit(1);});
