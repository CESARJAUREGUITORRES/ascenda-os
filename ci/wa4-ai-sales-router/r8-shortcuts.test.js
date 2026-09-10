'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {createCopilot}=require('../../app/wa4-copilot');
const style=require('../../app/wa4-conversation-style');

function message(direction,message_body,seconds){return {direction,message_body,created_at:new Date(Date.UTC(2026,8,10)+seconds*1000).toISOString()};}
async function run(messages,authorized=true){
  const calls=[];let output;
  const suggest=createCopilot({
    authorize:async()=>({ok:authorized,actor_id:'synthetic-admin'}),
    serviceGet:async path=>{calls.push(path);if(path.startsWith('/rest/v1/aos_wa_conversations_v1?'))return {data:[{id:'synthetic-conversation'}]};if(path.startsWith('/rest/v1/aos_wa_messages_v1?'))return {data:messages.slice().reverse()};throw new Error('DEPENDENCY_OFFLINE');},
    serviceRpc:async()=>{calls.push('RPC');throw new Error('DEPENDENCY_OFFLINE');},
    // A pending audit sink must not hold the patient response open.
    servicePost:()=>{calls.push('AUDIT');return new Promise(()=>{});},
    getGroqKey:async()=>{calls.push('MODEL');throw new Error('MODEL_OFFLINE');},
    writeJson:(_res,status,body)=>{output={status,body};}
  });
  await suggest({}, {},'synthetic-conversation');return {calls,output};
}
test('R8 returning greeting works through the full handler without knowledge or models',async()=>{
  const {calls,output}=await run([message('INBOUND','hola',0),message('OUTBOUND',style.firstContactOrganic(),10),message('INBOUND','hola',30)]);
  assert.equal(output.status,200);assert.equal(output.body.needs_human,false);
  assert.match(output.body.suggestion.reply,/Aquí sigo/);assert.equal(output.body.suggestion.reply.includes('Soy Sofía'),false);
  assert.equal(calls.length,3);assert.equal(calls.includes('RPC'),false);assert.equal(calls.includes('MODEL'),false);
});
test('R8 clinical escalation survives unavailable enrichment and audit latency',async()=>{
  const {calls,output}=await run([message('INBOUND','Estoy embarazada, puedo usar toxina?',0)]);
  assert.equal(output.status,200);assert.equal(output.body.next_action,'HUMAN_CLINICAL');
  assert.equal(output.body.auto_send,false);assert.equal(output.body.needs_human,true);assert.equal(calls.length,3);
});
test('R8 clinical risk in the first fragment cannot be hidden by a later greeting',async()=>{
  const {output}=await run([message('INBOUND','Estoy embarazada',0),message('INBOUND','hola',2)]);
  assert.equal(output.body.next_action,'HUMAN_CLINICAL');assert.equal(output.body.needs_human,true);
});
test('R8 unauthorized requests cannot reach even the deterministic shortcuts',async()=>{
  const {calls,output}=await run([message('INBOUND','hola',0)],false);
  assert.equal(output.status,403);assert.deepEqual(calls,[]);
});
