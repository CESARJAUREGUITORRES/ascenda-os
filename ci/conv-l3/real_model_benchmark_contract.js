'use strict';
const assert=require('assert');
const fs=require('fs');
const bench=fs.readFileSync(require('path').join(__dirname,'../../app/conv-l3-real-model-benchmark.js'),'utf8');
const server=fs.readFileSync(require('path').join(__dirname,'../../app/server-f17.js'),'utf8');

assert(bench.includes("provider_send_eligible:false"));
assert(bench.includes("direct_sql=false"));
assert(bench.includes("direct_meta=false"));
assert(bench.includes("aos_integration_secrets_v1?tipo=eq.groq"));
assert(bench.includes("AOS_CONV_L3_REAL_BENCHMARK_ON_BOOT"));
assert(!bench.includes("WHATSAPP_ACCESS_TOKEN"));
assert(!bench.includes("WHATSAPP_APP_SECRET"));
assert(!bench.includes("/api/wa/send"));
assert(!bench.includes("graph.facebook.com"));
assert(server.includes("AOS_CONV_L3_REAL_BENCHMARK_ON_BOOT"));
assert(server.includes("conv-l3-real-model-benchmark"));
console.log(JSON.stringify({status:'PASS',suite:'CONV-L3 real-model benchmark safety contract'}));
