'use strict';
const fs=require('fs');
const p='ci/kronia-k1-phase2/fixture_pre_k1.sql';
let s=fs.readFileSync(p,'utf8').replace(/\r\n/g,'\n');
const marker='-- CURRENT provider-secret boundary (synthetic shape + dummy credential only).';
const i=s.indexOf(marker);
if(i>=0){
  s=s.slice(0,i).replace(/\s+$/,'')+'\n';
}
if(s.includes('create table if not exists public.aos_integration_secrets_v1')) throw new Error('fixture still pre-creates private vault');
if(!s.includes('alter table public.aos_integraciones')) throw new Error('CURRENT integration shape fixture missing');
fs.writeFileSync(p,s,'utf8');
console.log('KRONIA_K1_V4_FIXTURE_BOOTSTRAP_CHRONOLOGY=PASS');
