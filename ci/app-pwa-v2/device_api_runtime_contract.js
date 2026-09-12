'use strict'
const assert=require('assert')
const {createDeviceApi}=require('../../app/device-api-v2')

function makeDeps(opts={}){
  const calls=[]
  const writes=[]
  const deps={
    verifyApp:async(token)=> token==='good' ? {ok:true,actor_id:'11111111-1111-1111-1111-111111111111'} : {ok:false,status:403},
    serviceRpc:async(name,args)=>{
      calls.push({name,args})
      if(opts.throwRpc) throw new Error('rpc down')
      if(name==='aos_device_upsert_v1') return {ok:true,device_id:'d1'}
      if(name==='aos_devices_actor_v1') return {ok:true,rows:[]}
      return {ok:true}
    },
    writeJson:(res,status,body)=>{writes.push({status,body});res.status=status;res.body=body;return body},
    readRaw:async(req)=> {
      if(opts.readError){const e=new Error('BODY_TOO_LARGE');e.status=413;throw e}
      return Buffer.from(req.raw||'{}')
    },
    parseJson:(s)=>{try{return JSON.parse(s)}catch(_){return null}}
  }
  return {deps,calls,writes}
}
async function hit(api,method,path,token,body){
  const req={method,headers:{'x-aos-app-token':token||''},raw:body===undefined?'{}':JSON.stringify(body)}
  const res={}
  await api.handle(req,res,new URL('https://ascenda.local'+path))
  return res
}
;(async()=>{
  {
    const x=makeDeps(); const api=createDeviceApi(x.deps)
    const r=await hit(api,'GET','/api/devices/health','','')
    assert.equal(r.status,200); assert.equal(r.body.auth,'actor-bound')
  }
  {
    const x=makeDeps(); const api=createDeviceApi(x.deps)
    const r=await hit(api,'GET','/api/devices','','')
    assert.equal(r.status,403); assert.equal(x.calls.length,0)
  }
  {
    const x=makeDeps(); const api=createDeviceApi(x.deps)
    const r=await hit(api,'POST','/api/devices/register','good',{user_id:'attacker',installation_id:'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'})
    assert.equal(r.status,200)
    assert.equal(x.calls[0].name,'aos_device_upsert_v1')
    assert.equal(x.calls[0].args.p_payload.user_id,'11111111-1111-1111-1111-111111111111')
  }
  {
    const x=makeDeps(); const api=createDeviceApi(x.deps)
    await hit(api,'POST','/api/devices/presence','good',{user_id:'attacker',device_id:'d1'})
    assert.equal(x.calls[0].args.p_payload.user_id,'11111111-1111-1111-1111-111111111111')
  }
  {
    const x=makeDeps(); const api=createDeviceApi(x.deps)
    await hit(api,'POST','/api/devices/preferences','good',{actor_id:'attacker',device_id:'d1'})
    assert.equal(x.calls[0].name,'aos_device_preferences_actor_v1')
    assert.equal(x.calls[0].args.p_payload.actor_id,'11111111-1111-1111-1111-111111111111')
  }
  {
    const x=makeDeps({throwRpc:true}); const api=createDeviceApi(x.deps)
    const r=await hit(api,'GET','/api/devices','good')
    assert.equal(r.status,503); assert.equal(r.body.error,'DEVICE_LIST_UNAVAILABLE')
  }
  {
    const x=makeDeps({readError:true}); const api=createDeviceApi(x.deps)
    const r=await hit(api,'POST','/api/devices/register','good',{})
    assert.equal(r.status,413); assert.equal(x.calls.length,0)
  }
  console.log('APP_PWA_V2_DEVICE_API_RUNTIME_CONTRACT=PASS')
})().catch(e=>{console.error(e);process.exit(1)})
