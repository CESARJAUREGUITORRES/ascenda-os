'use strict'
const test=require('node:test')
const assert=require('node:assert/strict')
const {createL5Continuity,VERSION}=require('../../app/conversation-l5-continuity')
const CID='11111111-1111-4111-8111-111111111111',TID='22222222-2222-4222-8222-222222222222',NONCE='33333333-3333-4333-8333-333333333333'

function fixture(){
  const calls=[]
  const api=createL5Continuity({
    rest:async()=>[{id:'44444444-4444-4444-8444-444444444444',media_type:'image',title:'Toxina',description:'Resultado autorizado',public_url:'https://cdn.example.test/toxina.jpg',treatment_id:TID,tags:['toxina'],sort_order:1}],
    listTemplates:async()=>({templates:[{id:'1',name:'appointment_confirmation',status:'APPROVED',category:'UTILITY',language:'es'},{id:'2',name:'draft',status:'PENDING',category:'UTILITY',language:'es'}]}),
    rpc:async(name,payload)=>{calls.push({name,payload});if(name==='aos_wa_l5_prepare_confirmation_v1')return {ok:true,status:'AWAITING_CONFIRMATION',confirmation_nonce:NONCE};if(name==='aos_wa_l5_mark_explicit_confirmation_v1')return {ok:true,status:'CONFIRMED'};if(name==='aos_wa3_handoff_request_v1')return {ok:true,status:'HUMAN'};return {ok:false,error:'UNEXPECTED'}}
  })
  return {api,calls}
}

test('version and governed media allowlist',async()=>{const {api}=fixture();assert.equal(VERSION,'CONV-L5-CONTINUITY-V1');const out=await api.media({query:'toxina'});assert.equal(out.ok,true);assert.equal(out.items.length,1);assert.equal(out.items[0].url,'https://cdn.example.test/toxina.jpg');assert.equal(out.send_eligible,false);assert.equal(out.requires_human_send,true)})
test('only provider-approved templates are exposed',async()=>{const {api}=fixture();const out=await api.templates();assert.equal(out.count,1);assert.equal(out.items[0].name,'appointment_confirmation');assert.equal(out.send_eligible,false)})
test('booking prepare requires real conversation and explicit confirmation',async()=>{const {api,calls}=fixture();const out=await api.prepareBooking({treatment_id:TID,site:'SAN_ISIDRO',date:'2026-09-15',time:'10:00',given_name:'QA',family_name:'Canary'},{conversation_id:CID});assert.equal(out.ok,true);assert.equal(out.executed,false);assert.equal(out.requires_explicit_confirmation,true);assert.equal(calls[0].name,'aos_wa_l5_prepare_confirmation_v1')})
test('confirm only marks proof and never commits from tool layer',async()=>{const {api,calls}=fixture();const out=await api.confirmBooking({confirmation_nonce:NONCE,provider_message_id:'wamid.TEST123'},{conversation_id:CID});assert.equal(out.ok,true);assert.equal(out.executed,false);assert.equal(out.commit_deferred,true);assert.equal(out.requires_l4_authority,true);assert.equal(calls[0].name,'aos_wa_l5_mark_explicit_confirmation_v1');assert.ok(!calls.some(c=>c.name==='aos_wa_l5_commit_confirmed_v1'))})
test('handoff is deterministic',async()=>{const {api}=fixture();const out=await api.handoff({reason:'customer_requested'},{conversation_id:CID});assert.equal(out.ok,true);assert.equal(out.executed,true)})
test('unsafe inputs fail closed',async()=>{const {api}=fixture();assert.equal((await api.media({treatment_id:'bad'})).ok,false);assert.equal((await api.prepareBooking({treatment_id:TID,site:'BAD',date:'2026-09-15',time:'10:00'},{conversation_id:CID})).ok,false);assert.equal((await api.confirmBooking({confirmation_nonce:'bad',provider_message_id:'x'},{conversation_id:CID})).ok,false)})
