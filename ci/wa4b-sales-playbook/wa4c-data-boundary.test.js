'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const p=require('../../app/wa4-playbook');
const k=require('../../app/wa4-knowledge');

const ID='44444444-4444-4444-8444-444444444444';
function row(facts){return {
  knowledge_id:'service:'+ID,domain:'CATALOG',title:'HIFUTOX',authority_tier:10,
  freshness_state:'FRESH',conflict_state:'CLEAR',retrieval_state:'READY',facts,
  evidence_ref:{relation:'public.aos_catalogo_servicios',pk:ID,version:'v1'}
};}
function bundle(items){return {version:'T',audience:'PUBLIC_CLIENT',items,authority:'GOVERNED_SOURCE_ONLY',generic_llm_authority:false};}

test('thin INFO stays fail-closed even when canonical SKU identity and included benefit are available',()=>{
  const item=row({tipo:'SERVICIO',nombre:'HIFUTOX',descripcion_comercial:'',beneficios:'',faqs:[],
    included_benefit:'1 sesión LED',included_benefit_source:'CATALOG_SEP2026_CURRENT_SKU',
    catalog_identity:{family_name:'HIFU',commercial_variant:'HIFUTOX',clinical_sessions:1,zones:3},catalog_identity_source:'CATALOG_SEP2026_CURRENT_SKU'});
  const out=p.buildPlaybook({inbound:'¿Qué es HIFUTOX?',publicBundle:bundle([item]),advisorBundle:{...bundle([item]),audience:'ADVISOR_INTERNAL'},processContexts:[]});
  assert.equal(out.status,'FAIL_CLOSED');
  assert.equal(out.recommended_next_action,'HUMAN_COMMERCIAL');
  assert.equal(out.policy_escalation.reason,'PUBLIC_INFO_EVIDENCE_INSUFFICIENT');
  assert.equal(out.send_authority,'HUMAN_ONLY');
  assert.equal(out.auto_send,false);
});

test('adapter delivers canonical benefit and only allowlisted SKU identity to model bundle',()=>{
  const upstream=row({tipo:'SERVICIO',nombre:'HIFUTOX',descripcion_comercial:'Descripción aprobada',
    included_benefit:'1 sesión LED',included_benefit_source:'CATALOG_SEP2026_CURRENT_SKU',
    catalog_identity_source:'CATALOG_SEP2026_CURRENT_SKU',catalog_identity:{family_name:'HIFU',commercial_variant:'HIFUTOX',clinical_sessions:1,zones:3,body_area:'NO',indication:'NO',aliases:['NO'],active_or_technology:'NO'}});
  const facts=k.buildKnowledgeBundle([upstream],12,'PUBLIC_CLIENT').items[0].facts;
  assert.equal(facts.included_benefit,'1 sesión LED');
  assert.deepEqual(facts.catalog_identity,{family_name:'HIFU',commercial_variant:'HIFUTOX',clinical_sessions:1,zones:3});
});

test('v3 SQL derives only CURRENT public SEP26 SKU facts and never infers promotions',()=>{
  const sql=fs.readFileSync(path.join(__dirname,'../../supabase/migrations/20260828235500_wa4c_included_benefit_knowledge_v3.sql'),'utf8');
  for(const required of [
    'aos_wa4a_knowledge_search_v2','catalog_sep2026,gift_raw','treatment_identity,source','SEP2026_PRICE_LIST',
    'treatment_identity,current_status','CURRENT','treatment_identity,public_catalog','included_benefit','catalog_identity',
    'family_name','commercial_variant','clinical_sessions','brand','zones','unit_cap','syringes','volume_ml',
    'grant execute on function public.aos_wa4a_knowledge_search_v3','to service_role'
  ]) assert.equal(sql.includes(required),true,'missing '+required);
  for(const forbidden of ['body_area','indication','aliases','active_or_technology','aos_promociones'])
    assert.equal(sql.includes(forbidden),false,'forbidden '+forbidden);
});
