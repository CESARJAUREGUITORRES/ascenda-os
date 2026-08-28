'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const c=require('../../app/wa4-copilot');
const k=require('../../app/wa4-knowledge');

const ID='33333333-3333-4333-8333-333333333333';
function bundle(){return {version:'T',audience:'PUBLIC_CLIENT',authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false,items:[{knowledge_id:'service:'+ID,domain:'CATALOG',title:'Servicio',facts:{tipo:'SERVICIO',nombre:'Servicio',precio_base:500,precio_oferta:450,descripcion_comercial:'Aprobada'},authority_tier:10,freshness_state:'FRESH',conflict_state:'CLEAR',retrieval_state:'READY',evidence_ref:{relation:'public.aos_catalogo_servicios',pk:ID,version:'v1'}}]};}
function ctx(ready,moneda='PEN',base=500,offer=450){return [{entity_id:ID,precio_base:base,precio_oferta:offer,moneda,quote_price:offer,ready_for_quote:ready,price_state:ready?'READY':'REVIEW_REQUIRED_OFFER_ABOVE_BASE',freshness_state:'FRESH'}];}

test('non-price stage strips catalog money and currency before model and validator',()=>{
  const b=c.gatePublicCatalogMoney(bundle(),ctx(true),'INFO');
  assert.equal(b.items[0].facts.precio_base,undefined);
  assert.equal(b.items[0].facts.precio_oferta,undefined);
  assert.equal(b.items[0].facts.moneda,undefined);
  assert.equal(b.items[0].facts.currency,undefined);
  const v=k.validateGroundedSuggestion({reply:'El precio es S/ 450.',next_action:'REPLY',cited_knowledge_ids:['service:'+ID]},b);
  assert.deepEqual(v,{ok:false,error:'WA4A_UNGROUNDED_PRICE'});
});

test('PEN price stage exposes amount and currency atomically',()=>{
  const b=c.gatePublicCatalogMoney(bundle(),ctx(true,'PEN'),'PRICE_QUOTE');
  assert.equal(b.items[0].facts.precio_base,500);
  assert.equal(b.items[0].facts.precio_oferta,450);
  assert.equal(b.items[0].facts.moneda,'PEN');
  assert.equal(b.items[0].facts.currency,'PEN');
  const v=k.validateGroundedSuggestion({reply:'El precio vigente es S/ 450.',next_action:'REPLY',cited_knowledge_ids:['service:'+ID]},b);
  assert.equal(v.ok,true);
  assert.deepEqual(k.validateGroundedSuggestion({reply:'El precio vigente es $450.',next_action:'REPLY',cited_knowledge_ids:['service:'+ID]},b),{ok:false,error:'WA4A_UNGROUNDED_PRICE'});
});

test('USD price stage exposes amount and validates only USD representation',()=>{
  const b=c.gatePublicCatalogMoney(bundle(),ctx(true,'USD',1699,1699),'PRICE_QUOTE');
  assert.equal(b.items[0].facts.precio_base,1699);
  assert.equal(b.items[0].facts.precio_oferta,1699);
  assert.equal(b.items[0].facts.moneda,'USD');
  assert.equal(k.validateGroundedSuggestion({reply:'El precio vigente es USD 1699.',next_action:'REPLY',cited_knowledge_ids:['service:'+ID]},b).ok,true);
  assert.equal(k.validateGroundedSuggestion({reply:'El precio vigente es $1699.',next_action:'REPLY',cited_knowledge_ids:['service:'+ID]},b).ok,true);
  assert.deepEqual(k.validateGroundedSuggestion({reply:'El precio vigente es S/ 1699.',next_action:'REPLY',cited_knowledge_ids:['service:'+ID]},b),{ok:false,error:'WA4A_UNGROUNDED_PRICE'});
});

test('blocked 1C price remains unavailable even on price intent',()=>{
  const b=c.gatePublicCatalogMoney(bundle(),ctx(false),'PRICE_QUOTE');
  assert.equal(b.items[0].facts.precio_base,undefined);
  assert.equal(b.items[0].facts.precio_oferta,undefined);
  assert.equal(b.items[0].facts.moneda,undefined);
});

test('missing or invalid 1C currency fails closed instead of assuming PEN',()=>{
  const missing=c.gatePublicCatalogMoney(bundle(),ctx(true,''),'PRICE_QUOTE');
  const invalid=c.gatePublicCatalogMoney(bundle(),ctx(true,'EUR'),'PRICE_QUOTE');
  assert.equal(missing.items[0].facts.precio_oferta,undefined);
  assert.equal(invalid.items[0].facts.precio_oferta,undefined);
});

test('missing 1C context strips prices instead of falling back to raw catalog',()=>{
  const b=c.gatePublicCatalogMoney(bundle(),[],'PRICE_QUOTE');
  assert.equal(b.items[0].facts.precio_base,undefined);
  assert.equal(b.items[0].facts.precio_oferta,undefined);
});
