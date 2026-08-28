'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  buildKnowledgeBundle,
  sanitizeFacts,
  validateGroundedSuggestion
} = require('../../app/wa4-knowledge');

function row(audience, extra) {
  return Object.assign({
    knowledge_id:'zi:APP_SKIN_SIGNATURE:'+audience,
    domain:'ZI_VITAL',
    title:'Skin Signature',
    retrieval_state:'READY',
    conflict_state:'CLEAR',
    authority_tier:15,
    freshness_state:'FRESH',
    facts:{
      entity_key:'APP_SKIN_SIGNATURE',
      entity_type:'APPROACH',
      canonical_name:'Skin Signature',
      aliases:[],
      parent_entity_key:'DOMAIN_FACIAL',
      audience,
      content:'Skin Signature trabaja calidad de piel, hidratación y luminosidad.',
      payload:{summary:'Pink Glow figura entre los tratamientos fuente del enfoque.'},
      risk_level: audience === 'CLINICAL_RESTRICTED' ? 'HIGH' : 'LOW',
      answerable: audience !== 'CLINICAL_RESTRICTED',
      requires_human: audience === 'CLINICAL_RESTRICTED',
      forbidden_secret:'never'
    },
    evidence_ref:{
      relation:'public.aos_zi_knowledge_entities_v1',
      pk:'APP_SKIN_SIGNATURE:'+audience,
      version:'ZI_KNOWLEDGE_V1_20260827',
      source_key:'ZI_DOMAINS_20260827',
      pages:[2,3],
      sha256:'cbb2a3cf2ff0458203004d41522595d5322c30dc1d084eb4e9c4f591b81ad901'
    }
  },extra || {});
}

test('ZI facts are least-data sanitized', () => {
  const facts = sanitizeFacts('ZI_VITAL',row('PUBLIC_CLIENT').facts);
  assert.equal(facts.forbidden_secret,undefined);
  assert.equal(facts.audience,'PUBLIC_CLIENT');
  assert.equal(facts.canonical_name,'Skin Signature');
});

test('Zi Vital rows fail closed without explicit audience', () => {
  const bundle = buildKnowledgeBundle([row('PUBLIC_CLIENT')],12);
  assert.equal(bundle.items.length,0);
});

test('PUBLIC_CLIENT cannot receive ADVISOR_INTERNAL or OWNER_ADMIN blocks', () => {
  const bundle = buildKnowledgeBundle([
    row('PUBLIC_CLIENT'),row('ADVISOR_INTERNAL'),row('OWNER_ADMIN')
  ],12,'PUBLIC_CLIENT');
  assert.equal(bundle.items.length,1);
  assert.equal(bundle.items[0].facts.audience,'PUBLIC_CLIENT');
  assert.equal(bundle.response_policy.max_reply_chars,480);
});

test('advisor receives advisor block and not public/owner by accident', () => {
  const bundle = buildKnowledgeBundle([
    row('PUBLIC_CLIENT'),row('ADVISOR_INTERNAL'),row('OWNER_ADMIN')
  ],12,'ADVISOR_INTERNAL');
  assert.equal(bundle.items.length,1);
  assert.equal(bundle.items[0].facts.audience,'ADVISOR_INTERNAL');
});

test('public responses are intentionally concise', () => {
  const bundle = buildKnowledgeBundle([row('PUBLIC_CLIENT')],12,'PUBLIC_CLIENT');
  const result=validateGroundedSuggestion({
    reply:'x'.repeat(481),
    cited_knowledge_ids:[bundle.items[0].knowledge_id],
    next_action:'REPLY'
  },bundle);
  assert.equal(result.ok,false);
  assert.equal(result.error,'WA4A_INVALID_REPLY');
});

test('short public grounded response passes', () => {
  const bundle = buildKnowledgeBundle([row('PUBLIC_CLIENT')],12,'PUBLIC_CLIENT');
  const result=validateGroundedSuggestion({
    reply:'Pink Glow suele ubicarse dentro de Skin Signature, el enfoque facial orientado a calidad de piel y luminosidad.',
    cited_knowledge_ids:[bundle.items[0].knowledge_id],
    next_action:'REPLY'
  },bundle);
  assert.equal(result.ok,true);
});

test('clinical restricted evidence forces HUMAN_CLINICAL', () => {
  const bundle=buildKnowledgeBundle([row('CLINICAL_RESTRICTED')],12,'CLINICAL_RESTRICTED');
  assert.equal(bundle.items.length,1);
  const result=validateGroundedSuggestion({
    reply:'Este punto requiere validación clínica.',
    cited_knowledge_ids:[bundle.items[0].knowledge_id],
    next_action:'REPLY'
  },bundle);
  assert.equal(result.ok,false);
  assert.equal(result.error,'WA4A1_CLINICAL_HUMAN_REQUIRED');
  const human=validateGroundedSuggestion({
    reply:'Este punto requiere validación clínica.',
    cited_knowledge_ids:[bundle.items[0].knowledge_id],
    next_action:'HUMAN_CLINICAL'
  },bundle);
  assert.equal(human.ok,true);
});

test('source evidence is preserved for traceability', () => {
  const bundle=buildKnowledgeBundle([row('PUBLIC_CLIENT')],12,'PUBLIC_CLIENT');
  assert.deepEqual(bundle.items[0].evidence_ref.pages,[2,3]);
  assert.equal(bundle.items[0].evidence_ref.source_key,'ZI_DOMAINS_20260827');
  assert.equal(bundle.items[0].evidence_ref.sha256.length,64);
});
