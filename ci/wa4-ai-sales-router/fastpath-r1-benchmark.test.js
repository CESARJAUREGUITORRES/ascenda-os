'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');
const path=require('path');
const bench=require('../../app/wa4-fastpath-benchmark');

test('FASTPATH benchmark percentile is deterministic and nearest-rank',()=>{
  assert.equal(bench.percentile([5,1,3,2,4],0.5),3);
  assert.equal(bench.percentile([5,1,3,2,4],0.95),5);
  assert.equal(bench.percentile([],0.95),null);
});

test('FASTPATH benchmark knowledge is synthetic, bounded and non-patient',()=>{
  const k=bench.syntheticKnowledge();
  assert.equal(k.version,'WA4-BENCH-SYNTHETIC-V1');
  assert.equal(k.items.length,1);
  assert.equal(k.items[0].knowledge_id,'bench-svc-1');
  assert.equal(k.items[0].facts.precio_oferta,199);
  assert.equal(k.items[0].facts.moneda,'PEN');
  const raw=JSON.stringify(k);
  assert.ok(raw.length<5000);
  assert.ok(!/conversation_id|patient|paciente|telefono|phone|dni|email/i.test(raw));
});

test('FASTPATH benchmark is OFF by default and boot loader is env-gated',async()=>{
  const previous=process.env.AOS_WA4_FASTPATH_BENCHMARK_ON_BOOT;
  delete process.env.AOS_WA4_FASTPATH_BENCHMARK_ON_BOOT;
  try{
    const out=await bench.runBootBenchmark();
    assert.equal(out.skipped,true);
  }finally{
    if(previous===undefined)delete process.env.AOS_WA4_FASTPATH_BENCHMARK_ON_BOOT;
    else process.env.AOS_WA4_FASTPATH_BENCHMARK_ON_BOOT=previous;
  }
  const src=fs.readFileSync(path.join(__dirname,'../../app/wa4-ai-resilience.js'),'utf8');
  assert.ok(src.includes("AOS_WA4_FASTPATH_BENCHMARK_ON_BOOT"));
  assert.ok(src.includes("require('./wa4-fastpath-benchmark').runBootBenchmark()"));
});
