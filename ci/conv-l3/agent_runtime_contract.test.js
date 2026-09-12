'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const rt=require('../../app/conversation-agent-runtime');

const CID='11111111-1111-4111-8111-111111111111';
const base={tenantId:'zi-vital',conversationId:CID,semanticTurnId:'turn-1',policy:{},allowedTools:[]};
function m(direction,text,ms){return {direction,message_body:text,created_at:new Date(1789240000000+(ms||0)).toISOString()};}
function gateway(handlers){return rt.createToolGateway({handlers:handlers||{}});}
function runtime(model,opts){return rt.createAgentRuntime(Object.assign({modelAdapter:{run:model},toolGateway:gateway()},opts||{}));}

test('C01 simple greeting responds without tool preload',async()=>{
  let calls=0;
  const a=runtime(async(input)=>{calls++;assert.equal(input.allowedTools.length,0);return {outcome:'RESPOND',response:{text:'¡Hola! ¿En qué te ayudo hoy?'},confidence:.99};});
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','Hola',0)]}));
  assert.equal(out.outcome,'RESPOND');assert.equal(calls,1);assert.equal(out.toolTrace.length,0);assert.equal(out.providerDispatch,false);
});

test('C08 rapid fragments coalesce into one semantic turn and one reasoning cycle',async()=>{
  let calls=0,seen;
  const a=runtime(async(input)=>{calls++;seen=input.semanticTurn;return {outcome:'RESPOND',response:{text:'Te ayudo con eso.'}};});
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','Quiero toxina',0),m('INBOUND','para frente',300),m('INBOUND','y precio',700)]}));
  assert.equal(calls,1);assert.equal(seen.count,3);assert.equal(seen.burst,true);assert.match(seen.text,/Quiero toxina/);assert.equal(out.semanticTurn.count,3);
});

test('bounded memory redacts direct identifiers and caps size',()=>{
  const ms=[];for(let i=0;i<40;i++)ms.push(m('INBOUND','correo fake'+i+'@example.com telefono +51 999 999 999 dni 12345678',i*5000));
  const mem=rt.buildBoundedMemory(ms,{maxMessages:8,maxChars:4000});
  assert.equal(mem.message_count,8);assert.equal(mem.truncated,true);
  const serialized=JSON.stringify(mem);assert(!serialized.includes('999 999 999'));assert(!serialized.includes('12345678'));assert(!serialized.includes('@example.com'));
});

test('F08 STOP fails closed without model or tool execution',async()=>{
  let modelCalls=0,toolCalls=0;
  const a=rt.createAgentRuntime({modelAdapter:{run:async()=>{modelCalls++;return {outcome:'RESPOND',response:{text:'no'}};}},toolGateway:gateway({handoff:async()=>{toolCalls++;}})});
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','Por favor, no me escriban más',0)],allowedTools:['handoff']}));
  assert.equal(out.outcome,'NO_ACTION');assert.equal(out.handoffReason,'STOP_OBSERVED');assert.equal(modelCalls,0);assert.equal(toolCalls,0);
});

test('F07 personalized clinical question routes to human before reasoning',async()=>{
  let modelCalls=0;
  const a=runtime(async()=>{modelCalls++;return {outcome:'RESPOND',response:{text:'unsafe'}};});
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','Estoy embarazada, ¿puedo aplicarme toxina?',0)]}));
  assert.equal(out.outcome,'HANDOFF');assert.equal(out.handoffReason,'PERSONALIZED_CLINICAL');assert.equal(modelCalls,0);assert.match(out.response.text,/equipo/i);
});

test('F09 human ownership prevents AI work',async()=>{
  let modelCalls=0;
  const a=runtime(async()=>{modelCalls++;return {outcome:'RESPOND',response:{text:'x'}};});
  const out=await a.runTurn(Object.assign({},base,{policy:{humanActive:true},inboundMessages:[m('INBOUND','Hola',0)]}));
  assert.equal(out.outcome,'NO_ACTION');assert.equal(out.handoffReason,'HUMAN_OWNS_CONVERSATION');assert.equal(modelCalls,0);
});

test('tool gateway enforces typed allowlist and maximum two calls',async()=>{
  let price=0,promo=0,loc=0;
  const gw=gateway({
    get_prices:async()=>{price++;return {items:[{label:'synthetic',price:1}]};},
    get_promotions:async()=>{promo++;return {items:[]};},
    get_locations_payment_methods:async()=>{loc++;return {items:[]};}
  });
  const a=rt.createAgentRuntime({modelAdapter:{run:async(_,tool)=>{
    const p=await tool({name:'get_prices'});const q=await tool({name:'get_promotions'});const z=await tool({name:'get_locations_payment_methods'});
    assert.equal(p.ok,true);assert.equal(q.ok,true);assert.equal(z.error,'TOOL_BUDGET_EXCEEDED');
    return {outcome:'RESPOND',response:{text:'Tengo la información validada.'},confidence:.9};
  }},toolGateway:gw});
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','Precio y promo',0)],allowedTools:['get_prices','get_promotions','get_locations_payment_methods']}));
  assert.equal(out.toolTrace.length,2);assert.equal(price,1);assert.equal(promo,1);assert.equal(loc,0);
});

test('unknown or generic execution tools are rejected',()=>{
  assert.throws(()=>rt.validateToolName('execute_sql'),/CONV_L3_TOOL_NOT_ALLOWED/);
  assert.throws(()=>rt.validateToolName('http_request'),/CONV_L3_TOOL_NOT_ALLOWED/);
  assert.throws(()=>rt.validateToolName('shell'),/CONV_L3_TOOL_NOT_ALLOWED/);
});

test('failed governed tool cannot be followed by fabricated tool-truth answer',async()=>{
  const gw=gateway({get_prices:async()=>{throw Object.assign(new Error('timeout'),{code:'DB_TIMEOUT'});}});
  const a=rt.createAgentRuntime({modelAdapter:{run:async(_,tool)=>{const r=await tool({name:'get_prices'});assert.equal(r.ok,false);return {outcome:'RESPOND',response:{text:'Cuesta S/ 999'},requiresToolTruth:true};}},toolGateway:gw});
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','¿Cuánto cuesta?',0)],allowedTools:['get_prices']}));
  assert.equal(out.outcome,'HANDOFF');assert.equal(out.handoffReason,'GOVERNED_TOOL_UNAVAILABLE');assert.equal(out.response,undefined);assert.equal(out.toolTrace[0].ok,false);
});

test('numeric price without successful price tool fails closed',async()=>{
  const a=runtime(async()=>({outcome:'RESPOND',response:{text:'El tratamiento cuesta S/ 799.'}}));
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','Precio',0)]}));
  assert.equal(out.outcome,'HANDOFF');assert.equal(out.handoffReason,'MISSING_GOVERNED_EVIDENCE');assert.deepEqual(out.missingTools,['get_prices']);
});

test('price fact is eligible only after governed price tool succeeds',async()=>{
  const gw=gateway({get_prices:async()=>({items:[{price:799,currency:'PEN'}]})});
  const a=rt.createAgentRuntime({modelAdapter:{run:async(_,tool)=>{const r=await tool({name:'get_prices'});assert.equal(r.ok,true);return {outcome:'RESPOND',response:{text:'El precio vigente es S/ 799.'}};}},toolGateway:gw});
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','Precio',0)],allowedTools:['get_prices']}));
  assert.equal(out.outcome,'RESPOND');assert.equal(out.toolTrace[0].tool,'get_prices');
});

test('internal runtime markers are never eligible customer output',async()=>{
  const a=runtime(async()=>({outcome:'RESPOND',response:{text:'booking_readiness=HIGH'}}));
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','Quiero reservar',0)]}));
  assert.equal(out.outcome,'HANDOFF');assert.equal(out.handoffReason,'INTERNAL_POLICY_LEAK');
});

test('stale turn is suppressed after reasoning and before outbound eligibility',async()=>{
  const a=runtime(async()=>({outcome:'RESPOND',response:{text:'Respuesta vieja'}}),{recheck:async()=>({newerInbound:true})});
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','Primero',0)]}));
  assert.equal(out.outcome,'NO_ACTION');assert.equal(out.handoffReason,'STALE_TURN');assert.equal(out.providerDispatch,undefined);
});

test('human takeover race wins at post-reasoning recheck',async()=>{
  const a=runtime(async()=>({outcome:'RESPOND',response:{text:'No debe salir'}}),{recheck:async()=>({humanActive:true})});
  const out=await a.runTurn(Object.assign({},base,{inboundMessages:[m('INBOUND','Ayuda',0)]}));
  assert.equal(out.outcome,'NO_ACTION');assert.equal(out.handoffReason,'HUMAN_TAKEOVER_RACE');
});

test('per-conversation single flight prevents competing reasoning cycles',async()=>{
  let release;const gateP=new Promise(r=>{release=r;});let calls=0;
  const a=runtime(async()=>{calls++;await gateP;return {outcome:'RESPOND',response:{text:'ok'}};});
  const p1=a.runTurn(Object.assign({},base,{semanticTurnId:'turn-a',inboundMessages:[m('INBOUND','uno',0)]}));
  await new Promise(r=>setTimeout(r,5));
  const p2=await a.runTurn(Object.assign({},base,{semanticTurnId:'turn-b',inboundMessages:[m('INBOUND','dos',100)]}));
  assert.equal(p2.outcome,'NO_ACTION');assert.equal(p2.handoffReason,'SINGLE_FLIGHT_BUSY');assert.equal(calls,1);release();await p1;
});

test('source contract has no provider dispatch, direct SQL or Meta transport',()=>{
  const src=fs.readFileSync(path.join(__dirname,'../../app/conversation-agent-runtime.js'),'utf8');
  for(const forbidden of ['graph.facebook.com','WHATSAPP_ACCESS_TOKEN','execute_sql','child_process','supabase.co/rest/v1','sendText(','sendTemplate(','sendMedia('])assert(!src.includes(forbidden),forbidden);
  assert(src.includes('providerDispatch:false'));
  assert(src.includes('MAX_TOOL_CALLS=2'));
  assert(src.includes('HUMAN_TAKEOVER_RACE'));
  assert(src.includes('STALE_TURN'));
});
