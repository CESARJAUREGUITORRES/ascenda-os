'use strict';

const assert=require('assert');
const {createAgentRuntime}=require('../../app/conversation-agent-runtime');

const cases=[
  {name:'simple_price',messages:[['INBOUND','¿Cuánto cuesta la toxina botulínica?']],expect:'PLAN_READY',tool:'get_prices'},
  {name:'promotion',messages:[['INBOUND','¿Hay alguna promoción vigente?']],expect:'PLAN_READY',tool:'get_promotions'},
  {name:'locations',messages:[['INBOUND','¿Dónde están ubicados?']],expect:'PLAN_READY',tool:'get_locations'},
  {name:'payment_methods',messages:[['INBOUND','¿Puedo pagar con tarjeta?']],expect:'PLAN_READY',tool:'get_payment_methods'},
  {name:'objection_price',messages:[['INBOUND','Me parece caro, ¿qué opción tengo?']],expect:'PLAN_READY',tool:'get_promotions'},
  {name:'context_switch',messages:[['INBOUND','Quiero toxina'],['OUTBOUND','Claro, te ayudo.'],['INBOUND','Antes dime la sede de San Isidro']],expect:'PLAN_READY',tool:'get_locations'},
  {name:'burst_semantics',messages:[['INBOUND','hola'],['INBOUND','quiero saber precio'],['INBOUND','de toxina']],expect:'PLAN_READY',tool:'get_prices'},
  {name:'stop',messages:[['INBOUND','No quiero recibir mensajes, STOP']],expect:'STOP'},
  {name:'clinical_sensitive',messages:[['INBOUND','Estoy embarazada, ¿qué dosis me recomiendan?']],expect:'HANDOFF'},
  {name:'human_takeover',state:'HUMAN_ACTIVE',messages:[['INBOUND','hola']],expect:'HUMAN_CONTROL'},
  {name:'stale_turn',version:9,expectedVersion:8,messages:[['INBOUND','hola']],expect:'STALE_TURN'},
  {name:'unknown_tool_filtered',messages:[['INBOUND','Quiero información general']],expect:'PLAN_READY',tool:null}
];

function classify(text){
  const t=String(text||'').toLowerCase();
  if(/precio|cuesta|toxina/.test(t))return 'get_prices';
  if(/promo|caro|opci[oó]n/.test(t))return 'get_promotions';
  if(/d[oó]nde|ubic|sede/.test(t))return 'get_locations';
  if(/pagar|tarjeta|pago/.test(t))return 'get_payment_methods';
  return 'raw_sql';
}

(async()=>{
  let passed=0;
  for(const c of cases){
    const runtime=createAgentRuntime({
      toolRegistry:['get_prices','get_promotions','get_locations','get_payment_methods'],
      modelAdapter:{async decide(input){
        const inbound=input.memory.filter(x=>x.direction==='INBOUND');
        const last=inbound.length?inbound[inbound.length-1].body:'';
        const tool=classify(last);
        return {
          tool_calls:[{name:tool,args:{}}],
          draft_reply:'Respuesta de benchmark en modo shadow.',
          next_best_action:'benchmark'
        };
      }}
    });
    const version=c.version||8;
    const result=await runtime.shadowTurn({
      conversation:{id:'benchmark-'+c.name,state:c.state||'BOT_ACTIVE',version},
      expected_version:c.expectedVersion==null?version:c.expectedVersion,
      messages:c.messages.map((m,i)=>({direction:m[0],message_body:m[1],created_at:new Date(1700000000000+i*1000).toISOString()}))
    });
    assert.strictEqual(result.decision,c.expect,c.name+' decision');
    assert.strictEqual(result.provider_send_eligible,false,c.name+' send safety');
    if(c.expect==='PLAN_READY'){
      if(c.tool)assert.strictEqual(result.tool_calls[0]&&result.tool_calls[0].name,c.tool,c.name+' tool');
      else assert.strictEqual(result.tool_calls.length,0,c.name+' unknown tool must be filtered');
    }else{
      assert.strictEqual(result.tool_calls.length,0,c.name+' boundary must not call tools');
    }
    passed++;
  }
  assert.strictEqual(passed,cases.length);
  console.log(JSON.stringify({status:'PASS',suite:'CONV-L3 deterministic shadow orchestration',passed,total:cases.length,provider_send_eligible:false}));
})().catch(err=>{console.error(err);process.exit(1)});
