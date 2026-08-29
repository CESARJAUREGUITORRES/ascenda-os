'use strict';

const VERSION='WA4C-CAMPAIGN-CONTEXT-ADAPTER-V1';

function clean(v){return String(v==null?'':v).trim();}
function norm(v){return clean(v).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[_-]+/g,' ').replace(/\s+/g,' ').trim();}
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
    meta_status:result.meta&&result.meta.status||null,
    meta_objective:result.meta&&result.meta.objective||null,
    treatment_context:result.treatment_context||null,
    treatment_context_source:result.treatment_context_source||null,
    treatment_mapping_status:result.treatment_mapping_status,
    promotion_state:result.promotion_state,
    active_promotion_count:result.active_promotion_count
  };
}

function createCampaignContextAdapter(deps){
  deps=deps||{};
  const serviceGet=deps.serviceGet;
  if(typeof serviceGet!=='function')throw new Error('WA4_CAMPAIGN_SERVICE_GET_REQUIRED');

  async function resolve(input){
    input=input||{};
    const conv=input.conversation||{};
    const runtime=input.runtime||{};
    const state=runtime.state||{};
    const source=clean(conv.campaign_source)||clean(state.campaign_source)||null;
    const adId=clean(conv.ad_id)||null;
    const leadId=clean(conv.lead_id)||null;
    const treatment=clean(state.treatment)||null;
    const result={
      version:VERSION,
      status:'READY',
      source,
      ad_id:adId,
      lead_id:leadId,
      explicit_provenance:Boolean(source||adId||leadId),
      ad_matched:false,
      meta:null,
      treatment_context:treatment,
      treatment_context_source:treatment?'SEMANTIC_OR_EXPLICIT_CONVERSATION':null,
      treatment_mapping_status:treatment?'KNOWN_FROM_CONVERSATION':'UNAVAILABLE_NO_GOVERNED_AD_TREATMENT_JOIN',
      promotion_state:'UNVERIFIED',
      active_promotion_count:0,
      limitations:[]
    };

    if(adId){
      try{
        const select='campaign_id,campaign_name,adset_id,adset_name,ad_id,ad_name,status,objective';
        const out=await serviceGet('/rest/v1/aos_meta_campanas?ad_id=eq.'+encodeURIComponent(adId)+'&select='+encodeURIComponent(select)+'&limit=2');
        const row=firstRow(out);
        if(row){
          result.ad_matched=true;
          result.meta={
            campaign_id:clean(row.campaign_id)||null,
            campaign_name:clean(row.campaign_name)||null,
            adset_id:clean(row.adset_id)||null,
            adset_name:clean(row.adset_name)||null,
            ad_id:clean(row.ad_id)||adId,
            ad_name:clean(row.ad_name)||null,
            status:clean(row.status)||null,
            objective:clean(row.objective)||null
          };
        }else result.limitations.push('AD_ID_NOT_FOUND_IN_META_AUTHORITY');
      }catch(_){
        result.status='DEGRADED';
        result.limitations.push('META_CAMPAIGN_LOOKUP_UNAVAILABLE');
      }
    }

    if(treatment){
      try{
        const select='id,nombre,tratamientos,vigencia_inicio,vigencia_fin,activa';
        const out=await serviceGet('/rest/v1/aos_promociones?activa=eq.true&select='+encodeURIComponent(select)+'&limit=50');
        const today=limaDate(input.now);
        const active=asArray(out&&out.data).filter(row=>dateActive(row,today)&&asArray(row.tratamientos).some(x=>treatmentMatches(x,treatment)));
        result.active_promotion_count=active.length;
        result.promotion_state=active.length?'ACTIVE_GOVERNED_PROMOTION_EXISTS':'NO_ACTIVE_GOVERNED_PROMOTION';
      }catch(_){
        result.status=result.status==='READY'?'DEGRADED':result.status;
        result.limitations.push('PROMOTION_AUTHORITY_UNAVAILABLE');
      }
    }else{
      result.promotion_state='UNVERIFIED_TREATMENT_REQUIRED';
    }

    result.prompt_context=safeCampaignPrompt(result);
    return result;
  }

  return {resolve,version:VERSION};
}

module.exports={VERSION,createCampaignContextAdapter,norm,limaDate,treatmentMatches,safeCampaignPrompt};
