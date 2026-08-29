'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const campaign=require('./wa4-campaign-context-adapter');
const identity=require('./wa4-patient-identity-adapter');
const booking=require('./wa4-booking-resolver');

const UUID='11111111-1111-4111-8111-111111111111';

test('campaign adapter preserves explicit provenance without inferring treatment from ad name',async()=>{
  const serviceGet=async path=>{
    if(path.includes('aos_wa4_campaign_context_map_v1'))return {data:[]};
    if(path.includes('aos_meta_campanas'))return {data:[{campaign_id:'c1',campaign_name:'Camp',adset_id:'s1',adset_name:'Set',ad_id:'a1',ad_name:'TOXINA SUPER',status:'ACTIVE',objective:'MESSAGES'}]};
    if(path.includes('aos_promociones'))return {data:[]};
    throw new Error('unexpected '+path);
  };
  const a=campaign.createCampaignContextAdapter({serviceGet});
  const out=await a.resolve({conversation:{campaign_source:'META',ad_id:'a1'},runtime:{state:{campaign_source:'META',treatment:null}},now:new Date('2026-08-29T12:00:00Z')});
  assert.equal(out.ad_matched,true);
  assert.equal(out.treatment_context,null);
  assert.equal(out.treatment_mapping_status,'NO_GOVERNED_AD_MAPPING');
  assert.equal(out.prompt_context.meta_objective,'MESSAGES');
});

test('campaign adapter uses governed ad mapping when the current turn has no treatment',async()=>{
  const serviceGet=async path=>{
    if(path.includes('aos_wa4_campaign_context_map_v1'))return {data:[{ad_id:'a2',campaign_id:'c2',treatment_entity_id:null,treatment_code:'HIFU',promotion_id:null,booking_goal:'BOOKING',active:true,evidence_ref:'META:APPROVED'}]};
    if(path.includes('aos_meta_campanas'))return {data:[{campaign_id:'c2',campaign_name:'Camp 2',ad_id:'a2',ad_name:'Creative 2',status:'ACTIVE',objective:'MESSAGES'}]};
    if(path.includes('aos_promociones'))return {data:[]};
    throw new Error('unexpected '+path);
  };
  const a=campaign.createCampaignContextAdapter({serviceGet});
  const out=await a.resolve({conversation:{campaign_source:'META',ad_id:'a2'},runtime:{state:{campaign_source:'META',treatment:null}}});
  assert.equal(out.governed_ad_mapping,true);
  assert.equal(out.treatment_context,'HIFU');
  assert.equal(out.treatment_context_source,'GOVERNED_AD_MAPPING');
  assert.equal(out.prompt_context.booking_goal,'BOOKING');
});

test('explicit current-turn treatment overrides a different governed campaign treatment',async()=>{
  const serviceGet=async path=>{
    if(path.includes('aos_wa4_campaign_context_map_v1'))return {data:[{ad_id:'a3',treatment_code:'HIFU',booking_goal:'BOOKING',active:true,evidence_ref:'META:APPROVED'}]};
    if(path.includes('aos_meta_campanas'))return {data:[]};
    if(path.includes('aos_promociones'))return {data:[]};
    throw new Error('unexpected '+path);
  };
  const a=campaign.createCampaignContextAdapter({serviceGet});
  const out=await a.resolve({conversation:{campaign_source:'META',ad_id:'a3'},runtime:{state:{campaign_source:'META',treatment:'TOXINA_BOTULINICA'}}});
  assert.equal(out.treatment_context,'TOXINA_BOTULINICA');
  assert.equal(out.treatment_mapping_status,'GOVERNED_MAPPING_OVERRIDDEN_BY_CURRENT_TURN');
  assert.ok(out.limitations.includes('CAMPAIGN_TREATMENT_OVERRIDDEN_BY_CURRENT_TURN'));
});

test('campaign adapter uses semantic treatment only and checks governed active promotion authority',async()=>{
  const serviceGet=async path=>{
    if(path.includes('aos_meta_campanas'))return {data:[]};
    if(path.includes('aos_promociones'))return {data:[{id:'p1',nombre:'Promo',tratamientos:['TOXINA BOTULINICA'],vigencia_inicio:'2026-08-01',vigencia_fin:'2026-08-31',activa:true}]};
    throw new Error('unexpected');
  };
  const a=campaign.createCampaignContextAdapter({serviceGet});
  const out=await a.resolve({conversation:{campaign_source:'META'},runtime:{state:{campaign_source:'META',treatment:'TOXINA_BOTULINICA'}},now:new Date('2026-08-29T12:00:00Z')});
  assert.equal(out.treatment_context,'TOXINA_BOTULINICA');
  assert.equal(out.promotion_state,'ACTIVE_GOVERNED_PROMOTION_EXISTS');
  assert.equal(out.active_promotion_count,1);
});

test('identity adapter resolves canonical patient by trusted WhatsApp phone and exposes minimum prompt context only',async()=>{
  let patientRead=false;
  const serviceRpc=async(name,args)=>{
    assert.equal(name,'aos_rev_resolve_patient_identity_v2');
    assert.equal(args.p_lookup_type,'PHONE');
    return {data:{status:'MATCH',canonical_patient_id:'P-123',candidate_count:1,confidence_band:'HIGH',evidence_scopes:['PHONE']}};
  };
  const serviceGet=async path=>{
    patientRead=true;
    assert.ok(path.includes('ID_PACIENTE=eq.P-123'));
    return {data:[{ID_PACIENTE:'P-123',Nombres:'ANA',Apellidos:'LOPEZ',Email:'','N° documento':'',SEDE_PRINCIPAL:'SAN ISIDRO',ESTADO_PACIENTE:'ACTIVO',numero_limpio:'51999999999'}]};
  };
  const a=identity.createPatientIdentityAdapter({serviceRpc,serviceGet});
  const out=await a.resolve({conversation:{contact_number:'+51 999 999 999'}});
  assert.equal(patientRead,true);
  assert.equal(out.identity_state,'MATCH');
  assert.equal(out.existing_patient,true);
  assert.deepEqual(out.missing_booking_fields,['DNI','EMAIL']);
  assert.equal(out.prompt_context.preferred_site,'SAN ISIDRO');
  assert.equal(Object.prototype.hasOwnProperty.call(out.prompt_context,'canonical_patient_id'),false);
  assert.equal(out.prompt_context.sensitive_disclosure_allowed,false);
});

test('identity conflict fails closed and never reads patient row',async()=>{
  let reads=0;
  const a=identity.createPatientIdentityAdapter({
    serviceRpc:async()=>({data:{status:'IDENTITY_CONFLICT',candidate_count:2}}),
    serviceGet:async()=>{reads++;return {data:[]};}
  });
  const out=await a.resolve({conversation:{contact_number:'51911111111'}});
  assert.equal(out.identity_state,'IDENTITY_CONFLICT');
  assert.equal(out.requires_human,true);
  assert.equal(reads,0);
});

test('booking resolver blocks future slots when date-specific schedule authority is stale',async()=>{
  let slotCalls=0;
  const a=booking.createBookingResolver({
    serviceGet:async path=>{
      if(path.includes('aos_catalogo_servicios'))return {data:[{id:UUID,nombre:'TOXINA',requiere_doctora:true,requiere_enfermeria:false,estado:'ACTIVO'}]};
      if(path.includes('aos_config_horarios'))return {data:[{sede:'SAN ISIDRO',dia_semana:6,activo:true}]};
      if(path.includes('aos_horarios_personal'))return {data:[{fecha:'2026-06-26'}]};
      throw new Error('unexpected '+path);
    },
    serviceRpc:async()=>{slotCalls++;return {data:{ok:true,slots:[]}};}
  });
  const out=await a.resolve({runtime:{booking_readiness:'HIGH',intents:['BOOKING','SCHEDULE'],state:{requested_day:'SABADO',requested_time:'10:00',site:'SAN_ISIDRO',time_constraint:'HARD'}},processContexts:[{entity_id:UUID}],now:new Date('2026-08-29T12:00:00Z')});
  assert.equal(out.status,'SCHEDULE_SOURCE_STALE');
  assert.equal(out.schedule_source_max_date,'2026-06-26');
  assert.equal(slotCalls,0);
  assert.equal(out.confirmation_allowed,false);
  assert.equal(out.write_boundary,'GOVERNED_HUMAN_BOOKING_WRITE_V1');
});

test('booking resolver returns governed real slots only after current schedule authority is fresh',async()=>{
  const a=booking.createBookingResolver({
    serviceGet:async path=>{
      if(path.includes('aos_catalogo_servicios'))return {data:[{id:UUID,nombre:'TOXINA',requiere_doctora:true,requiere_enfermeria:false,estado:'ACTIVO'}]};
      if(path.includes('aos_config_horarios'))return {data:[{sede:'SAN ISIDRO',dia_semana:6,activo:true,hora_apertura:'09:00:00',hora_cierre:'19:00:00'}]};
      if(path.includes('aos_horarios_personal'))return {data:[{fecha:'2026-08-29'}]};
      if(path.includes('aos_perfiles_profesional'))return {data:[{id:'doc1',nombre_publico:'Dra. Test',tipo:'DOCTORA',sede:'TODAS',visible:true}]};
      throw new Error('unexpected '+path);
    },
    serviceRpc:async(name,args)=>{
      assert.equal(name,'aos_slots_disponibles');
      assert.equal(args.p_fecha,'2026-08-29');
      return {data:{ok:true,slots:[{hora:'09:30',sede:'SAN ISIDRO',disponible:true,libres:1,capacidad:5},{hora:'10:00',sede:'SAN ISIDRO',disponible:true,libres:2,capacidad:5}]}};
    }
  });
  const runtime={booking_readiness:'HIGH',intents:['BOOKING','SCHEDULE','HARD_TIME_CONSTRAINT'],state:{requested_day:'SABADO',requested_time:'10:00',site:'SAN_ISIDRO',time_constraint:'HARD'}};
  const out=await a.resolve({runtime,processContexts:[{entity_id:UUID}],now:new Date('2026-08-29T12:00:00Z')});
  assert.equal(out.status,'REAL_SLOTS_READY');
  assert.equal(out.exact_requested_time_available,true);
  assert.equal(out.candidate_slots[0].hora,'10:00');
  assert.equal(out.confirmation_allowed,false);
  assert.equal(out.human_commit_required,true);
  assert.equal(out.write_boundary,'GOVERNED_HUMAN_BOOKING_WRITE_V1');
});

test('booking role authority conflicts fail closed',async()=>{
  const a=booking.createBookingResolver({
    serviceGet:async path=>{
      if(path.includes('aos_catalogo_servicios'))return {data:[
        {id:UUID,nombre:'A',requiere_doctora:true,requiere_enfermeria:false},
        {id:'22222222-2222-4222-8222-222222222222',nombre:'B',requiere_doctora:false,requiere_enfermeria:true}
      ]};
      throw new Error('unexpected '+path);
    },
    serviceRpc:async()=>({data:{}})
  });
  const out=await a.resolve({runtime:{booking_readiness:'HIGH',intents:['BOOKING'],state:{requested_day:'SABADO',site:'SAN_ISIDRO'}},processContexts:[{entity_id:UUID},{entity_id:'22222222-2222-4222-8222-222222222222'}],now:new Date('2026-08-29T12:00:00Z')});
  assert.equal(out.status,'ROLE_AUTHORITY_CONFLICT');
});
