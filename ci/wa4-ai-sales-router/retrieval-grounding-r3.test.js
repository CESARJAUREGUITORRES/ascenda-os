'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');
const path=require('path');
const knowledge=require('../../app/wa4-knowledge');

function catalog(id,name,price,family='TOXINA BOTULÍNICA',category='TOXINA'){
  return {
    knowledge_id:id,domain:'CATALOG',title:name,authority_tier:10,freshness_state:'FRESH',
    facts:{nombre:name,categoria:category,moneda:'PEN',precio_base:price,precio_oferta:price,catalog_identity:{family_name:family,commercial_variant:name}}
  };
}
function bundle(items){return {version:'TEST',audience:'PUBLIC_CLIENT',authority:'GOVERNED_SOURCE_ONLY',items};}

const hutox=catalog('service:hutox-1','HUTOX 1 ZONA 15U',299);
const nabota=catalog('service:nabota-1','NABOTA 1 ZONA 15U',399);
const nabota3=catalog('service:nabota-3','NABOTA 3 ZONAS 50U',999);

test('R3 missing citation is repaired only by an exact visible governed price',()=>{
  const r=knowledge.validateGroundedSuggestion({
    reply:'Tenemos una opción de toxina a S/ 299.',next_action:'REPLY',cited_knowledge_ids:[]
  },bundle([hutox,nabota,nabota3]));
  assert.equal(r.ok,true);
  assert.equal(r.citationRepaired,true);
  assert.deepEqual(r.citations,['service:hutox-1']);
});

test('R3 price that exists only outside the four visible cards cannot repair a missing citation',()=>{
  const hidden=catalog('service:hidden','TOXINA HIDDEN',777);
  const r=knowledge.validateGroundedSuggestion({
    reply:'El precio es S/ 777.',next_action:'REPLY',cited_knowledge_ids:[]
  },bundle([
    catalog('service:a','A',100,'FAM A','A'),
    catalog('service:b','B',200,'FAM B','B'),
    catalog('service:c','C',300,'FAM C','C'),
    catalog('service:d','D',400,'FAM D','D'),
    hidden
  ]));
  assert.equal(r.ok,false);
  assert.equal(r.error,'WA4A_EVIDENCE_REQUIRED');
});

test('R3 cited evidence cannot borrow a price from another bundle item',()=>{
  const r=knowledge.validateGroundedSuggestion({
    reply:'La opción está en S/ 399.',next_action:'REPLY',cited_knowledge_ids:['service:hutox-1']
  },bundle([hutox,nabota]));
  assert.equal(r.ok,false);
  assert.equal(r.error,'WA4A_UNGROUNDED_PRICE');
});

test('R3 no-money reply can repair citations when all visible catalog cards share one governed family',()=>{
  const r=knowledge.validateGroundedSuggestion({
    reply:'Sí, tenemos opciones de toxina botulínica y puedo explicarte las alternativas.',next_action:'REPLY',cited_knowledge_ids:[]
  },bundle([hutox,nabota,nabota3]));
  assert.equal(r.ok,true);
  assert.equal(r.citationRepaired,true);
  assert.deepEqual(r.citations,['service:hutox-1','service:nabota-1','service:nabota-3']);
});

test('R3 mixed visible catalog families remain fail-closed without a citation',()=>{
  const facial=catalog('service:facial','HIDROFACIAL',129,'FACIALES','FACIALES');
  const r=knowledge.validateGroundedSuggestion({
    reply:'Tenemos varias opciones disponibles.',next_action:'REPLY',cited_knowledge_ids:[]
  },bundle([hutox,facial]));
  assert.equal(r.ok,false);
  assert.equal(r.error,'WA4A_EVIDENCE_REQUIRED');
});

test('R3 invented price remains blocked even when a valid family is visible',()=>{
  const r=knowledge.validateGroundedSuggestion({
    reply:'La toxina está en S/ 250.',next_action:'REPLY',cited_knowledge_ids:[]
  },bundle([hutox,nabota,nabota3]));
  assert.equal(r.ok,false);
  assert.equal(r.error,'WA4A_EVIDENCE_REQUIRED');
});

test('R3 ambiguous equal prices across unrelated families are not auto-cited',()=>{
  const a=catalog('service:a','A',299,'FAMILIA A','A');
  const b=catalog('service:b','B',299,'FAMILIA B','B');
  const r=knowledge.validateGroundedSuggestion({
    reply:'El precio es S/ 299.',next_action:'REPLY',cited_knowledge_ids:[]
  },bundle([a,b]));
  assert.equal(r.ok,false);
  assert.equal(r.error,'WA4A_EVIDENCE_REQUIRED');
});

test('R3 retrieval migration removes commercial filler and weights structured treatment evidence',()=>{
  const sql=fs.readFileSync(path.join(__dirname,'../../supabase/migrations/20260905203000_wa4a_retrieval_relevance_v2.sql'),'utf8');
  assert.ok(sql.includes("'informacion'"));
  assert.ok(sql.includes("'precio'"));
  assert.ok(sql.includes("select 'toxina'"));
  assert.ok(sql.includes("w in ('botox','botulinica')"));
  assert.ok(sql.includes('norm_structured'));
  assert.ok(sql.includes("k.facts->>'categoria'"));
  assert.ok(sql.includes('rank_score >= greatest(8,ceil(s.max_score*0.35)::integer)'));
  assert.ok(!/statement_timeout\s*=|set\s+statement_timeout/i.test(sql));
});
