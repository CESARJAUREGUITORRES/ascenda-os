'use strict'
const fs=require('fs')
const test=require('node:test')
const assert=require('node:assert/strict')
const source=fs.readFileSync('app/marketing-read-gateway.js','utf8')
const {createMarketingReadGateway}=require('../../app/marketing-read-gateway')

test('gateway keeps bounded 1 MiB response and never puts raw app token in cache key',()=>{
  assert.match(source,/MAX_BODY_BYTES=1024\*1024/)
  assert.match(source,/if\(k!=='p_token'\)ordered\[k\]=payload\[k\]/)
  assert.match(source,/const authInflight=new Map\(\)/)
})

test('concurrent reads coalesce admin verification and still scope lineage token upstream',async()=>{
  let authCalls=0
  let lineageCalls=0
  let releaseAuth
  const authGate=new Promise(resolve=>{releaseAuth=resolve})
  const gateway=createMarketingReadGateway({
    rpc:async(name,payload)=>{
      if(name==='aos_cia_verify_admin_session_v1'){
        authCalls++
        await authGate
        return {status:200,body:{ok:true,user_id:'00000000-0000-0000-0000-000000000001',usuario:'admin'}}
      }
      if(name==='aos_marketing_lineage_admin_v43'){
        lineageCalls++
        assert.equal(payload.p_token,'z'.repeat(40))
        return {status:200,body:{ok:true,rows:[]}}
      }
      return {status:200,body:{ok:true}}
    }
  })
  const token='z'.repeat(40)
  const a=gateway.execute({token,name:'aos_marketing_lineage_admin_v43',payload:{p_anio:2026,p_mes:9,p_token:'browser-value-must-be-replaced'}})
  const b=gateway.execute({token,name:'aos_marketing_period_summary_v2',payload:{p_fecha_desde:'2026-09-01',p_fecha_hasta:'2026-09-30'}})
  await new Promise(resolve=>setImmediate(resolve))
  assert.equal(authCalls,1)
  releaseAuth()
  const out=await Promise.all([a,b])
  assert.equal(out[0].status,200)
  assert.equal(out[1].status,200)
  assert.equal(lineageCalls,1)
})
