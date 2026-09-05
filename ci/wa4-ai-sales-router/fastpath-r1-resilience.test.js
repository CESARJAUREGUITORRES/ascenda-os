'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const resilience=require('../../app/wa4-ai-resilience');
const cards=require('../../app/wa4-answer-cards');

test('provider fallback only classifies provider failures, not business/request 400s',()=>{
  assert.equal(resilience.retryableGroq(Object.assign(new Error('GROQ_TIMEOUT'),{status:504})),true);
  assert.equal(resilience.retryableGroq(Object.assign(new Error('GROQ_REJECTED'),{upstreamStatus:429})),true);
  assert.equal(resilience.retryableGroq(Object.assign(new Error('GROQ_REJECTED'),{upstreamStatus:503})),true);
  assert.equal(resilience.retryableGroq(Object.assign(new Error('GROQ_REJECTED'),{upstreamStatus:400})),false);
});

test('Gemini interaction parser reads current model_output steps shape',()=>{
  const out={status:'completed',steps:[{type:'model_output',content:[{type:'text',text:'{"reply":"ok"}'}]}],usage:{total_input_tokens:12,total_output_tokens:5,total_tokens:17}};
  assert.equal(resilience.textFromInteraction(out),'{"reply":"ok"}');
  assert.deepEqual(resilience.usageFromInteraction(out),{prompt_tokens:12,completion_tokens:5,total_tokens:17});
});

test('Answer Cards keep governed identity and money while bounding prompt material',()=>{
  cards.clear();
  const source={version:'WA4A1-KNOWLEDGE-V2',price_authority:'WA4A1C_ONLY',price_stage:true,items:Array.from({length:12},(_,i)=>({
    knowledge_id:`catalog-${i}`,domain:'CATALOG',title:`Toxina ${i}`,authority_tier:1,freshness_state:'CURRENT',
    evidence_ref:{version:'v1',source_code:'CATALOG'},
    facts:{nombre:`Toxina ${i}`,categoria:'Toxina',precio_base:500+i,precio_oferta:450+i,moneda:'PEN',descripcion_comercial:'Descripción '.repeat(100),beneficios:Array.from({length:20},(_,n)=>`Beneficio ${n} `.repeat(10)),faqs:Array.from({length:80},(_,n)=>({q:`Pregunta ${n} `.repeat(20),a:`Respuesta ${n} `.repeat(80)}))}
  }))};
  const card=cards.build(source,{maxItems:4});
  assert.equal(card.items.length,4);
  assert.equal(card.items[0].knowledge_id,'catalog-0');
  assert.equal(card.items[0].facts.precio_oferta,450);
  assert.equal(card.items[0].facts.moneda,'PEN');
  assert.ok(card.items[0].facts.faqs.length<=3);
  assert.ok(JSON.stringify(card).length<20000);
  const again=cards.build(source,{maxItems:4});
  assert.equal(again,card);
  assert.equal(cards.stats().size,1);
});

test('Answer Card fingerprint changes when governed facts change',()=>{
  cards.clear();
  const base={version:'v1',items:[{knowledge_id:'x',domain:'CATALOG',title:'X',authority_tier:1,freshness_state:'CURRENT',evidence_ref:{version:'1'},facts:{nombre:'X',precio_oferta:100,moneda:'PEN'}}]};
  const a=cards.build(base,{maxItems:1});
  const b=cards.build({...base,items:[{...base.items[0],facts:{...base.items[0].facts,precio_oferta:110}}]},{maxItems:1});
  assert.notEqual(a.fingerprint,b.fingerprint);
  assert.equal(cards.stats().size,2);
});
