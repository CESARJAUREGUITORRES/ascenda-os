'use strict';

const assert=require('assert');
const {
  AGENT_RUNTIME_VERSION,
  clipMemory,
  semanticTurn,
  detectBoundary,
  validateToolCalls,
  createAgentRuntime
}=require('../../app/conversation-agent-runtime');

(async()=>{
  assert.strictEqual(AGENT_RUNTIME_VERSION,'CONV-L3-SHADOW-V2');

  const memory=clipMemory([
    {direction:'INBOUND',message_body:'hola'},
    {direction:'OUTBOUND',message_body:'hola, ¿en qué te ayudo?'},
    {direction:'INBOUND',message_body:'quiero precio'}
  ],2,1000);
  assert.strictEqual(memory.length,2);
  assert.strictEqual(memory[1].body,'quiero precio');
  assert.strictEqual(semanticTurn([
    {direction:'INBOUND',body:'quiero precio de toxina'},
    {direction:'OUTBOUND',body:'te ayudo'},
    {direction:'INBOUND',body:'antes dime dónde queda San Isidro'}
  ]),'antes dime dónde queda San Isidro');
  assert.strictEqual(semanticTurn([
    {direction:'INBOUND',body:'hola'},
    {direction:'INBOUND',body:'quiero saber precio'},
    {direction:'INBOUND',body:'de toxina'}
  ]),'hola\nquiero saber precio\nde toxina');

  assert.deepStrictEqual(detectBoundary([{direction:'INBOUND',body:'STOP'}]),{kind:'STOP',reason:'customer_stop_or_suppression'});
  assert.deepStrictEqual(detectBoundary([{direction:'INBOUND',body:'¿qué dosis me recomiendas?'}]),{kind:'HANDOFF',reason:'clinical_sensitive'});

  const calls=validateToolCalls([
    {name:'get_prices',args:{q:'toxina'}},
    {name:'raw_sql',args:{sql:'select 1'}},
    {name:'get_locations',args:{}},
    {name:'get_promotions',args:{}}
  ],['get_prices','get_locations','get_promotions']);
  assert.deepStrictEqual(calls.map(x=>x.name),['get_prices','get_locations']);

  let seenInput=null;
  const runtime=createAgentRuntime({
    toolRegistry:['get_prices','get_locations'],
    modelAdapter:{
      async decide(input){
        seenInput=input;
        return {
          tool_calls:[{name:'get_prices',args:{service:'toxina'}},{name:'raw_sql',args:{sql:'select *'}}],
          draft_reply:'Te ayudo con el precio vigente.',
          next_best_action:'consult_price'
        };
      }
    }
  });

  const human=await runtime.shadowTurn({
    conversation:{id:'c1',state:'HUMAN_ACTIVE',version:7},expected_version:7,
    messages:[{direction:'INBOUND',message_body:'hola'}]
  });
  assert.strictEqual(human.decision,'HUMAN_CONTROL');
  assert.strictEqual(human.provider_send_eligible,false);

  const stale=await runtime.shadowTurn({
    conversation:{id:'c1',state:'BOT_ACTIVE',version:8},expected_version:7,
    messages:[{direction:'INBOUND',message_body:'hola'}]
  });
  assert.strictEqual(stale.decision,'STALE_TURN');
  assert.strictEqual(stale.provider_send_eligible,false);

  const stopped=await runtime.shadowTurn({
    conversation:{id:'c1',state:'BOT_ACTIVE',version:8},expected_version:8,
    messages:[{direction:'INBOUND',message_body:'No quiero recibir mensajes, STOP'}]
  });
  assert.strictEqual(stopped.decision,'STOP');
  assert.strictEqual(stopped.provider_send_eligible,false);

  const planned=await runtime.shadowTurn({
    conversation:{id:'c1',state:'BOT_ACTIVE',version:8},expected_version:8,
    messages:[{direction:'INBOUND',message_body:'¿Cuánto cuesta la toxina botulínica?'}]
  });
  assert.strictEqual(planned.decision,'PLAN_READY');
  assert.strictEqual(planned.tool_calls.length,1);
  assert.strictEqual(planned.tool_calls[0].name,'get_prices');
  assert.strictEqual(planned.provider_send_eligible,false);
  assert.strictEqual(seenInput.current_turn,'¿Cuánto cuesta la toxina botulínica?');
  assert.strictEqual(seenInput.constraints.provider_send,false);
  assert.strictEqual(seenInput.constraints.direct_sql,false);
  assert.strictEqual(seenInput.constraints.direct_meta,false);

  console.log('CONV_L3_SHADOW_RUNTIME_CONTRACT_PASS');
})().catch(err=>{console.error(err);process.exit(1)});
