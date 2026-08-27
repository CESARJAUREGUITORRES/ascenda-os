'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const k = require('../../app/wa4-knowledge');

const readyCatalog = {
  knowledge_id:'service:1',domain:'CATALOG',title:'Botox Test',authority_tier:10,
  freshness_state:'FRESH',conflict_state:'CLEAR',retrieval_state:'READY',
  facts:{nombre:'Botox Test',precio_base:500,precio_oferta:450,descripcion_comercial:'Aprobada',beneficios:'Aprobados',faqs:[],descripcion_clinica:'SECRETO CLINICO',contraindicaciones:'NO ENVIAR'},
  evidence_ref:{relation:'public.aos_catalogo_servicios',pk:'1',version:'v1'}
};
const readyBranch = {
  knowledge_id:'branch:1',domain:'BRANCH',title:'San Isidro',authority_tier:10,
  freshness_state:'UNKNOWN',conflict_state:'CLEAR',retrieval_state:'READY_WITH_WARNING',
  facts:{nombre:'SAN ISIDRO',direccion:'Av. Test 100',telefono:'999111222',maps_link:'https://maps.example/test',horario_lv:'NO DEBE PASAR'},
  evidence_ref:{relation:'public.aos_sedes_geo',pk:'1',version:'NO_UPDATED_AT',warning:'FRESHNESS_UNKNOWN'}
};
const readyHours = {
  knowledge_id:'hours:1',domain:'HOURS',title:'Miraflores día 1',authority_tier:10,
  freshness_state:'FRESH',conflict_state:'CLEAR',retrieval_state:'READY',
  facts:{sede:'MIRAFLORES TEST',dia_semana:1,hora_apertura:'09:00:00',hora_cierre:'18:00:00',activo:true},
  evidence_ref:{relation:'public.aos_config_horarios',pk:'1',version:'v1'}
};
const blocked = {
  knowledge_id:'service:blocked',domain:'CATALOG',title:'Conflict',authority_tier:10,
  freshness_state:'FRESH',conflict_state:'CONFLICT',retrieval_state:'BLOCKED_CONFLICT',
  facts:{nombre:'Conflict',precio_base:999},evidence_ref:{relation:'public.aos_catalogo_servicios',pk:'x',version:'v1'}
};

test('bundle keeps only ready evidence and strips clinical/non-allowlisted fields',()=>{
  const b=k.buildKnowledgeBundle([readyCatalog,readyBranch,blocked],12);
  assert.equal(b.items.length,2);
  assert.equal(b.generic_llm_authority,false);
  assert.equal(b.items[0].facts.descripcion_clinica,undefined);
  assert.equal(b.items[0].facts.contraindicaciones,undefined);
  assert.equal(b.items[1].facts.horario_lv,undefined);
});

test('valid cited governed price passes',()=>{
  const b=k.buildKnowledgeBundle([readyCatalog],12);
  const out=k.validateGroundedSuggestion({reply:'El precio aprobado es S/ 450.',next_action:'REPLY',cited_knowledge_ids:['service:1']},b);
  assert.equal(out.ok,true);
});

test('invented price fails closed',()=>{
  const b=k.buildKnowledgeBundle([readyCatalog],12);
  const out=k.validateGroundedSuggestion({reply:'El precio es S/ 499.',next_action:'REPLY',cited_knowledge_ids:['service:1']},b);
  assert.deepEqual(out,{ok:false,error:'WA4A_UNGROUNDED_PRICE'});
});

test('unknown citation fails closed',()=>{
  const b=k.buildKnowledgeBundle([readyCatalog],12);
  const out=k.validateGroundedSuggestion({reply:'Información aprobada.',next_action:'REPLY',cited_knowledge_ids:['service:999']},b);
  assert.deepEqual(out,{ok:false,error:'WA4A_UNGROUNDED_CITATION'});
});

test('non-human suggestion requires evidence citation',()=>{
  const b=k.buildKnowledgeBundle([readyCatalog],12);
  const out=k.validateGroundedSuggestion({reply:'Información genérica inventada.',next_action:'REPLY',cited_knowledge_ids:[]},b);
  assert.deepEqual(out,{ok:false,error:'WA4A_EVIDENCE_REQUIRED'});
});

test('hours cannot be invented when HOURS knowledge is absent',()=>{
  const b=k.buildKnowledgeBundle([readyCatalog],12);
  const out=k.validateGroundedSuggestion({reply:'Atendemos de 09:00 a 18:00.',next_action:'REPLY',cited_knowledge_ids:['service:1']},b);
  assert.deepEqual(out,{ok:false,error:'WA4A_UNGROUNDED_HOURS'});
});

test('hours pass only when exact ready HOURS evidence exists',()=>{
  const b=k.buildKnowledgeBundle([readyHours],12);
  const out=k.validateGroundedSuggestion({reply:'Atendemos de 09:00 a 18:00.',next_action:'REPLY',cited_knowledge_ids:['hours:1']},b);
  assert.equal(out.ok,true);
});

test('branch/location statement requires cited branch evidence',()=>{
  const b=k.buildKnowledgeBundle([readyCatalog,readyBranch],12);
  const bad=k.validateGroundedSuggestion({reply:'Nuestra sede está ubicada en Av. Test 100.',next_action:'REPLY',cited_knowledge_ids:['service:1']},b);
  assert.deepEqual(bad,{ok:false,error:'WA4A_BRANCH_EVIDENCE_REQUIRED'});
  const good=k.validateGroundedSuggestion({reply:'Nuestra sede está ubicada en Av. Test 100.',next_action:'REPLY',cited_knowledge_ids:['branch:1']},b);
  assert.equal(good.ok,true);
});

test('human clinical escalation may proceed without commercial knowledge',()=>{
  const b=k.buildKnowledgeBundle([],12);
  const out=k.validateGroundedSuggestion({reply:'Derivo tu caso con el equipo clínico.',next_action:'HUMAN_CLINICAL',cited_knowledge_ids:[]},b);
  assert.equal(out.ok,true);
});
