'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const k=require('../../app/wa4-knowledge');

function clinic(audience,answer,extra){return {
  knowledge_id:'clinic:FACIAL_SKIN_SIGNATURE',domain:'CLINIC_KNOWLEDGE',title:'Skin Signature',authority_tier:15,
  freshness_state:'GOVERNED',conflict_state:'CLEAR',retrieval_state:'READY',
  facts:Object.assign({code:'FACIAL_SKIN_SIGNATURE',node_type:'APPROACH',title:'Skin Signature',answer,audience,risk_level:'MEDIUM'},extra||{}),
  evidence_ref:{relation:'public.aos_knowledge_nodes_v1',pk:'FACIAL_SKIN_SIGNATURE',version:'1',source_code:'ZV_DOMAINS_2026',source_locator:'PDF p.2-3',audience}
}}

test('public bundle rejects internal audience row',()=>{
  const b=k.buildKnowledgeBundle([clinic('ADVISOR_INTERNAL','internal only')],12,'PUBLIC_CLIENT');
  assert.equal(b.items.length,0);
  assert.equal(b.audience,'PUBLIC_CLIENT');
});

test('public bundle strips system_reference even if malformed upstream row includes it',()=>{
  const b=k.buildKnowledgeBundle([clinic('PUBLIC_CLIENT','respuesta corta',{system_reference:{secret:'internal'},public_summary:'x'})],12,'PUBLIC_CLIENT');
  assert.equal(b.items.length,1);
  assert.equal(b.items[0].facts.answer,'respuesta corta');
  assert.equal(b.items[0].facts.system_reference,undefined);
  assert.equal(b.items[0].facts.public_summary,undefined);
});

test('advisor bundle accepts only advisor row and preserves public summary',()=>{
  const b=k.buildKnowledgeBundle([clinic('PUBLIC_CLIENT','public'),clinic('ADVISOR_INTERNAL','advisor',{public_summary:'public summary'})],12,'ADVISOR_INTERNAL');
  assert.equal(b.items.length,1);
  assert.equal(b.items[0].facts.answer,'advisor');
  assert.equal(b.items[0].facts.public_summary,'public summary');
});

test('invalid audience fails safely to PUBLIC_CLIENT',()=>{
  assert.equal(k.normalizeAudience('root_superuser'),'PUBLIC_CLIENT');
});

test('clinic knowledge remains evidence-required',()=>{
  const b=k.buildKnowledgeBundle([clinic('PUBLIC_CLIENT','Skin Signature trabaja calidad de piel.')],12,'PUBLIC_CLIENT');
  const bad=k.validateGroundedSuggestion({reply:'Skin Signature trabaja calidad de piel.',next_action:'REPLY',cited_knowledge_ids:[]},b);
  assert.deepEqual(bad,{ok:false,error:'WA4A_EVIDENCE_REQUIRED'});
  const good=k.validateGroundedSuggestion({reply:'Skin Signature trabaja calidad de piel.',next_action:'REPLY',cited_knowledge_ids:['clinic:FACIAL_SKIN_SIGNATURE']},b);
  assert.equal(good.ok,true);
});
