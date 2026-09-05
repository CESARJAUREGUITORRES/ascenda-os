'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const knowledge=require('../../app/wa4-knowledge');

function faq(i){
  return {q:('Pregunta '+i+' '+ 'q'.repeat(260)),a:('Respuesta '+i+' '+ 'a'.repeat(900))};
}
function row(i){
  return {
    knowledge_id:'catalog-'+String(i).padStart(2,'0'),
    domain:'CATALOG',
    subject_type:'service',
    subject_id:String(i),
    title:'Toxina '+i,
    facts:{
      tipo:'SERVICIO',nombre:'Toxina '+i,nombre_corto:'Toxina '+i,categoria:'Toxina',
      precio_base:500+i,precio_oferta:450+i,moneda:'PEN',
      descripcion_comercial:'Descripción gobernada '+i,
      beneficios:['Beneficio A','Beneficio B'],
      faqs:Array.from({length:80},(_,n)=>faq(n)),
      requiere_doctora:true,
      catalog_identity:{family_name:'Toxina',commercial_variant:'Variante '+i,unit_cap:50},
      catalog_identity_source:knowledge.SEP26_CURRENT_SKU
    },
    authority_tier:1,
    freshness_state:'CURRENT',
    conflict_state:'CLEAR',
    retrieval_state:'READY',
    evidence_ref:{relation:'aos_catalogo',pk:String(i),version:'v1'}
  };
}

test('production-scale catalog FAQ payload stays bounded without weakening authority',()=>{
  const rows=Array.from({length:12},(_,i)=>row(i+1));
  const bundle=knowledge.buildKnowledgeBundle(rows,12,'PUBLIC_CLIENT');
  assert.equal(bundle.items.length,12);
  assert.equal(bundle.authority,'GOVERNED_SOURCE_ONLY');
  assert.equal(bundle.generic_llm_authority,false);

  for(const item of bundle.items){
    assert.equal(item.domain,'CATALOG');
    assert.equal(item.authority_tier,1);
    assert.ok(Array.isArray(item.facts.faqs));
    assert.ok(item.facts.faqs.length<=knowledge.FAQ_BOUNDS.maxItems);
    for(const f of item.facts.faqs){
      assert.ok(f.q.length<=knowledge.FAQ_BOUNDS.questionChars);
      assert.ok(f.a.length<=knowledge.FAQ_BOUNDS.answerChars);
    }
    assert.ok(Number.isFinite(Number(item.facts.precio_base)));
    assert.ok(Number.isFinite(Number(item.facts.precio_oferta)));
    assert.equal(item.facts.moneda,'PEN');
    assert.match(item.facts.descripcion_comercial,/Descripción gobernada/);
  }

  const chars=JSON.stringify(bundle).length;
  assert.ok(chars<100000,`bounded bundle too large: ${chars}`);

  const cited=bundle.items[0];
  const valid=knowledge.validateGroundedSuggestion({
    reply:`El precio aprobado es S/ ${cited.facts.precio_oferta}.`,
    next_action:'REPLY',
    cited_knowledge_ids:[cited.knowledge_id]
  },bundle);
  assert.equal(valid.ok,true);
});

test('non-array FAQ values fail closed to no FAQ prompt payload',()=>{
  const facts=knowledge.sanitizeFacts('CATALOG',{nombre:'X',faqs:'unbounded text'});
  assert.equal(facts.nombre,'X');
  assert.equal(Object.hasOwn(facts,'faqs'),false);
});
