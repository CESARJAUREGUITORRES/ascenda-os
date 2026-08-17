'use strict';
const https=require('https');
const base='https://ascenda-os-production.up.railway.app';
function get(path){return new Promise((resolve,reject)=>{const req=https.get(base+path,{headers:{'User-Agent':'AscendaOS-WA-S5-Probe/1.0'}},res=>{let raw='';res.setEncoding('utf8');res.on('data',c=>raw+=c);res.on('end',()=>{if(res.statusCode<200||res.statusCode>=300)return reject(new Error(path+' HTTP '+res.statusCode));resolve(raw);});});req.setTimeout(10000,()=>req.destroy(new Error(path+' timeout')));req.on('error',reject);});}
(async()=>{
  const health=await get('/health');
  if(!health.includes('ascenda-phase-s'))throw new Error('Phase S health marker missing');
  const sw=await get('/phase2-service-worker.js?probe=20260817s5native');
  if(!sw.includes('wa-native-bootstrap-prelude.js'))throw new Error('live SW missing native prelude injection');
  const prelude=await get('/wa-native-bootstrap-prelude.js?probe=20260817s5native');
  if(!prelude.includes('[WA-S5]'))throw new Error('live native prelude marker missing');
  if(!prelude.includes('/api/wa3/bootstrap'))throw new Error('live prelude bootstrap retry contract missing');
  console.log('WA S5 LIVE ASSETS PASS');
})().catch(e=>{console.error(e.stack||e);process.exit(1);});
