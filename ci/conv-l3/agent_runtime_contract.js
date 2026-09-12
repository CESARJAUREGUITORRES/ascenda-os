'use strict';

const assert=require('assert');
const {
  AGENT_RUNTIME_VERSION,
  clipMemory,
  semanticTurn,
  detectBoundary,
  validateToolCalls,
  validateToolObservations,
  createAgentRuntime
}=require('../../app/conversation-agent-runtime');

(async()=>{
  assert.strictEqual(AGENT_RUNTIME_VERSION,'CONV-L3-SHADOW-V3');

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

  const observations=validateToolObservations([
    {name:'raw_sql',data:{secret:true}},
    {name:'get_prices',data:{amount:420,currency:'PEN'}},
    {name:'get_locations',data:{address:'should-not-pass'}}
  ],['get_prices','get_locations'],['get_prices']);
  assert.deepStrictEqual(observations,[{name:'get_prices',data:{amount:420,currency:'PEN'}}]);

  let seenPlan=null,seenCompose=null,composeCalls=0;
  const runtime=createAgentRuntime({
    toolRegistry:['get_prices','get_locations'],
    modelAdapter:{
      async decide(input){
        seenPlan=input;
        return {
          tool_calls:[{name:'get_prices',args:{service:'toxina'}},{name:'raw_sql',args:{sql:'select *'}}],
          draft_reply:'Este borrador factual debe descartarse antes de observar la herramienta.',
          next_best_action:'consult_price'
        };
      },
      async compose(input){
        composeCalls++;
        seenCompose=input;
        return {
          draft_reply:'El precio oficial observado es S/ 420.',
          next_best_action:'offer_booking',
          cited_tools:['get_prices','raw_sql']
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

  const stopped=await runtime.shadowTurn({
    conversation:{id:'c1',state:'BOT_ACTIVE',version:8},expected_version:8,
    messages:[{direction:'INBOUND',message_body:'No quiero recibir mensajes, STOP'}]
  });
  assert.strictEqual(stopped.decision,'STOP');

  const planned=await runtime.shadowTurn({
    conversation:{id:'c1',state:'BOT_ACTIVE',version:8},expected_version:8,
    messages:[{direction:'INBOUND',message_body:'¿Cuánto cuesta la toxina botulínica?'}]
  });
  assert.strictEqual(planned.decision,'PLAN_READY');
  assert.strictEqual(planned.response_state,'AWAITING_TOOL_OBSERVATION');
  assert.strictEqual(planned.tool_calls.length,1);
  assert.strictEqual(planned.tool_calls[0].name,'get_prices');
  assert.strictEqual(planned.draft_reply,'');
  assert.strictEqual(planned.provider_send_eligible,false);
  assert.strictEqual(seenPlan.current_turn,'¿Cuánto cuesta la toxina botulínica?');
  assert.strictEqual(seenPlan.constraints.direct_sql,false);

  const missing=await runtime.shadowCompose({
    conversation:{id:'c1',state:'BOT_ACTIVE',version:8},expected_version:8,
    messages:[{direction:'INBOUND',message_body:'¿Cuánto cuesta la toxina botulínica?'}],
    planned_tool_names:['get_prices'],tool_observations:[]
  });
  assert.strictEqual(missing.decision,'OBSERVATION_REQUIRED');
  assert.strictEqual(composeCalls,0);
  assert.strictEqual(missing.provider_send_eligible,false);

  const composed=await runtime.shadowCompose({
    conversation:{id:'c1',state:'BOT_ACTIVE',version:8},expected_version:8,
    messages:[{direction:'INBOUND',message_body:'¿Cuánto cuesta la toxina botulínica?'}],
    planned_tool_names:['get_prices'],
    tool_observations:[
      {name:'get_prices',data:{amount:420,currency:'PEN'}},
      {name:'raw_sql',data:{sql:'select 1'}}
    ]
  });
  assert.strictEqual(composed.decision,'RESPONSE_READY');
  assert.strictEqual(composed.response_state,'READY');
  assert.strictEqual(composed.draft_reply,'El precio oficial observado es S/ 420.');
  assert.deepStrictEqual(composed.cited_tools,['get_prices']);
  assert.strictEqual(composeCalls,1);
  assert.strictEqual(seenCompose.tool_observations.length,1);
  assert.strictEqual(seenCompose.tool_observations[0].data.amount,420);
  assert.strictEqual(seenCompose.constraints.observed_tools_only,true);
  assert.strictEqual(composed.provider_send_eligible,false);

  console.log('CONV_L3_SHADOW_RUNTIME_V3_CONTRACT_PASS');
})().catch(err=>{console.error(err);process.exit(1)});
