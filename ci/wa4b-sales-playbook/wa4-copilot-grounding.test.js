'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const c=require('../../app/wa4-copilot');
const k=require('../../app/wa4-knowledge');

const ID='33333333-3333-4333-8333-333333333333';
function bundle(){return {version:'T',audience:'PUBLIC_CLIENT',authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false,items:[{knowledge_id:'service:'+ID,domain:'CATALOG',title:'Servicio',facts:{tipo:'SERVICIO',nombre:'Servicio',precio_base:500,precio_oferta:450,descripcion_comercial:'Aprobada'},authority_tier:10,freshness_state:'FRESH',conflict_state:'CLEAR',retrieval_state:'READY',evidence_ref:{relation:'public.aos_catalogo_servicios',pk:ID,version:'v1'}}]};}
function ctx(ready){return [{entity_id:ID,precio_base:500,precio_oferta:450,quote_price:450,ready_for_quote:ready,price_state:ready?'READY':'REVIEW_REQUIRED_OFFER_ABOVE_BASE',freshness_state:'FRESH'}];}

test('non-price stage strips catalog money before model and validator',()=>{
  const b=c.gatePublicCatalogMoney(bundle(),ctx(true),'INFO');
  assert.equal(b.items[0].facts.precio_base,undefined);
  assert.equal(b.items[0].facts.precio_oferta,undefined);
  const v=k.validateGroundedSuggestion({reply:'El precio es S/ 450.',next_action:'REPLY',cited_knowledge_ids:['service:'+ID]},b);
  assert.deepEqual(v,{ok:false,error:'WA4A_UNGROUNDED_PRICE'});
});

test('price stage exposes only 1C-ready catalog money',()=>{
  const b=c.gatePublicCatalogMoney(bundle(),ctx(true),'PRICE_QUOTE');
  assert.equal(b.items[0].facts.precio_base,500);
  assert.equal(b.items[0].facts.precio_oferta,450);
  const v=k.validateGroundedSuggestion({reply:'El precio vigente es S/ 450.',next_action:'REPLY',cited_knowledge_ids:['service:'+ID]},b);
  assert.equal(v.ok,true);
});

test('blocked 1C price remains unavailable even on price intent',()=>{
  const b=c.gatePublicCatalogMoney(bundle(),ctx(false),'PRICE_QUOTE');
  assert.equal(b.items[0].facts.precio_base,undefined);
  assert.equal(b.items[0].facts.precio_oferta,undefined);
});

test('missing 1C context strips prices instead of falling back to raw catalog',()=>{
  const b=c.gatePublicCatalogMoney(bundle(),[],'PRICE_QUOTE');
  assert.equal(b.items[0].facts.precio_base,undefined);
  assert.equal(b.items[0].facts.precio_oferta,undefined);
});
