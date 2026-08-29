'use strict';

const VERSION='WA4C-CAMPAIGN-CONTEXT-ADAPTER-V2';

function clean(v){return String(v==null?'':v).trim();}
function norm(v){return clean(v).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[_-]+/g,' ').replace(/\s+/g,' ').trim();}
function safeToken(v){const s=clean(v).toUpperCase();return /^[A-Z0-9_]{1,40}$/.test(s)?s:null;}
function asArray(v){return Array.isArray(v)?v:[];}
function firstRow(out){return out&&Array.isArray(out.data)?out.data[0]||null:null;}
function limaDate(now){
  const d=now instanceof Date?now:new Date(now||Date.now());
  try{return new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).format(d);}
  catch(_){return d.toISOString().slice(0,10);}
}
function dateActive(row,today){
  const from=clean(row&&row.vigencia_inicio),to=clean(row&&row.vigencia_fin);
  return (!from||from<=today)&&(!to||to>=today);
}
function treatmentMatches(promoTreatment,treatment){
  const a=norm(promoTreatment),b=norm(treatment);
  return Boolean(a&&b&&(a===b));
}
function safeCampaignPrompt(result){
  return {
    version:VERSION,
    source:result.source,
    explicit_provenance:result.explicit_provenance,
    ad_matched:result.ad_matched,
    governed_ad_mapping:result.governed_ad_mapping===true,
    meta_status:result.meta&&result.meta.status||null,
    meta_objective:result.meta&&result.meta.objective||null,
    treatment_context:result.treatment_context||null,
    treatment_context_source:result.treatment_context_source||null,
    treatment_mapping_status:result.treatment_mapping_status,
    booking_goal:safeToken(result.booking_goal),
    promotion_binding_present:Boolean(result.promotion_id),
    promotion_state:result.promotion_state,
    active_promotion_count:result.active_promotion_count
  };
}

function createCampaignContextAdapter(deps){
  deps=deps||{};
  const serviceGet=deps.serviceGet;
  if(typeof serviceGet!=='function')throw new Error('WA4_CAMPAIGN_SERVICE_GET_REQUIRED');

  async function mappedTreatmentFromRow(row){
    let mapped=clean(row&&row.treatment_code);
    if(mapped||!clean(row&&row.treatment_entity_id))return mapped||null;
    try{
      const select='id,nombre,nombre_corto,estado';
      const out=await serviceGet('/rest/v1/aos_catalogo_servicios?id=eq.'+encodeURIComponent(clean(row.treatment_entity_id))+'&select='+encodeURIComponent(select)+'&limit=1');
      const c=firstRow(out);
      return clean(c&&c.nombre_corto)||clean(c&&c.nombre)||null;
    }catch(_){return null;}
  }

  async function resolve(input){
    input=input||{};
    const conv=input.conversation||{};
    const runtime=input.runtime||{};
    const state=runtime.state||{};
    const source=clean(conv.campaign_source)||clean(state.campaign_source)||null;
    const adId=clean(conv.ad_id)||null;
    const leadId=clean(conv.lead_id)||null;
    const currentTreatment=clean(state.treatment)||null;
    const result={
      version:VERSION,status:'READY',source,ad_id:adId,lead_id:leadId,
      explicit_provenance:Boolean(source||adId||leadId),ad_matched:false,meta:null,
      governed_ad_mapping:false,campaign_treatment:null,
      treatment_context:currentTreatment,
      treatment_context_source:currentTreatment?'SEMANTIC_OR_EXPLICIT_CONVERSATION':null,
      treatment_mapping_status:currentTreatment?'KNOWN_FROM_CONVERSATION':'UNAVAILABLE_NO_GOVERNED_AD_TREATMENT_JOIN',
      promotion_id:null,booking_goal:null,promotion_state:'UNVERIFIED',active_promotion_count:0,limitations:[]
    };

    if(adId){
      try{
        const select='ad_id,campaign_id,treatment_entity_id,treatment_code,promotion_id,booking_goal,active,evidence_ref';
        const out=await serviceGet('/rest/v1/aos_wa4_campaign_context_map_v1?ad_id=eq.'+encodeURIComponent(adId)+'&active=eq.true&select='+encodeURIComponent(select)+'&limit=2');
        const row=firstRow(out);
        if(row){
          const mapped=await mappedTreatmentFromRow(row);
          result.governed_ad_mapping=true;
          result.campaign_treatment=mapped;
          result.promotion_id=clean(row.promotion_id)||null;
          result.booking_goal=safeToken(row.booking_goal);
          if(mapped){
            if(currentTreatment&&norm(currentTreatment)!==norm(mapped)){
              result.treatment_context=currentTreatment;
              result.treatment_context_source='CURRENT_TURN_OVERRIDES_GOVERNED_CAMPAIGN';
              result.treatment_mapping_status='GOVERNED_MAPPING_OVERRIDDEN_BY_CURRENT_TURN';
              result.limitations.push('CAMPAIGN_TREATMENT_OVERRIDDEN_BY_CURRENT_TURN');
            }else{
              result.treatment_context=currentTreatment||mapped;
              result.treatment_context_source=currentTreatment?'SEMANTIC_AND_GOVERNED_AD_MAPPING':'GOVERNED_AD_MAPPING';
              result.treatment_mapping_status='GOVERNED_AD_MAPPING';
            }
          }else{
            result.treatment_mapping_status=currentTreatment?'KNOWN_FROM_CONVERSATION':'GOVERNED_MAP_MISSING_TREATMENT_VALUE';
            result.limitations.push('GOVERNED_MAP_TREATMENT_UNRESOLVED');
          }
        }else if(!currentTreatment){
          result.treatment_mapping_status='NO_GOVERNED_AD_MAPPING';
        }
      }catch(_){
        result.status='DEGRADED';
        result.limitations.push('GOVERNED_AD_MAPPING_UNAVAILABLE');
      }

      try{
        const select='campaign_id,campaign_name,adset_id,adset_name,ad_id,ad_name,status,objective';
        const out=await serviceGet('/rest/v1/aos_meta_campanas?ad_id=eq.'+encodeURIComponent(adId)+'&select='+encodeURIComponent(select)+'&limit=2');
        const row=firstRow(out);
        if(row){
          result.ad_matched=true;
          result.meta={campaign_id:clean(row.campaign_id)||null,campaign_name:clean(row.campaign_name)||null,adset_id:clean(row.adset_id)||null,adset_name:clean(row.adset_name)||null,ad_id:clean(row.ad_id)||adId,ad_name:clean(row.ad_name)||null,status:clean(row.status)||null,objective:clean(row.objective)||null};
        }else result.limitations.push('AD_ID_NOT_FOUND_IN_META_AUTHORITY');
      }catch(_){
        result.status='DEGRADED';
        result.limitations.push('META_CAMPAIGN_LOOKUP_UNAVAILABLE');
      }
    }

    const promoTreatment=result.treatment_context;
    if(promoTreatment){
      try{
        const select='id,nombre,tratamientos,vigencia_inicio,vigencia_fin,activa';
        const out=await serviceGet('/rest/v1/aos_promociones?activa=eq.true&select='+encodeURIComponent(select)+'&limit=50');
        const today=limaDate(input.now);
        const active=asArray(out&&out.data).filter(row=>dateActive(row,today)&&asArray(row.tratamientos).some(x=>treatmentMatches(x,promoTreatment)));
        result.active_promotion_count=active.length;
        result.promotion_state=active.length?'ACTIVE_GOVERNED_PROMOTION_EXISTS':'NO_ACTIVE_GOVERNED_PROMOTION';
      }catch(_){
        result.status=result.status==='READY'?'DEGRADED':result.status;
        result.limitations.push('PROMOTION_AUTHORITY_UNAVAILABLE');
      }
    }else result.promotion_state='UNVERIFIED_TREATMENT_REQUIRED';

    result.prompt_context=safeCampaignPrompt(result);
    return result;
  }

  return {resolve,version:VERSION};
}

module.exports={VERSION,createCampaignContextAdapter,norm,safeToken,limaDate,treatmentMatches,safeCampaignPrompt};
