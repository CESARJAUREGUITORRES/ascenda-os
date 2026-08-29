'use strict';

const VERSION='WA4C-PATIENT-IDENTITY-ADAPTER-V1';

function clean(v){return String(v==null?'':v).trim();}
function digits(v){return clean(v).replace(/[^0-9]/g,'');}
function rpcData(out){return out&&Object.prototype.hasOwnProperty.call(out,'data')?out.data:out;}
function firstRow(out){return out&&Array.isArray(out.data)?out.data[0]||null:null;}
function missing(value){return !clean(value);}
function bookingMissingFields(row){
  if(!row)return ['NAME','LAST_NAME','DNI','EMAIL'];
  const fields=[];
  if(missing(row.Nombres))fields.push('NAME');
  if(missing(row.Apellidos))fields.push('LAST_NAME');
  if(missing(row['N° documento']))fields.push('DNI');
  if(missing(row.Email))fields.push('EMAIL');
  return fields;
}
function safePrompt(result){
  return {
    version:VERSION,
    identity_state:result.identity_state,
    existing_patient:result.existing_patient,
    confidence_band:result.confidence_band||null,
    preferred_site:result.preferred_site||null,
    missing_booking_fields:result.missing_booking_fields||[],
    can_reuse_whatsapp_phone:result.can_reuse_whatsapp_phone===true,
    sensitive_disclosure_allowed:false,
    requires_human:result.requires_human===true
  };
}

function createPatientIdentityAdapter(deps){
  deps=deps||{};
  const serviceRpc=deps.serviceRpc,serviceGet=deps.serviceGet;
  if(typeof serviceRpc!=='function')throw new Error('WA4_IDENTITY_SERVICE_RPC_REQUIRED');
  if(typeof serviceGet!=='function')throw new Error('WA4_IDENTITY_SERVICE_GET_REQUIRED');

  async function resolve(input){
    input=input||{};
    const conv=input.conversation||{};
    const phone=digits(conv.contact_number);
    const base={
      version:VERSION,
      identity_state:'UNRESOLVED',
      existing_patient:false,
      canonical_patient_id:null,
      candidate_count:0,
      confidence_band:null,
      preferred_site:null,
      missing_booking_fields:['NAME','LAST_NAME','DNI','EMAIL'],
      can_reuse_whatsapp_phone:phone.length>=8,
      requires_human:false,
      patient_minimum:null,
      limitations:[]
    };
    if(phone.length<8){
      base.identity_state='PHONE_UNAVAILABLE';
      base.limitations.push('TRUSTED_WHATSAPP_PHONE_REQUIRED');
      base.prompt_context=safePrompt(base);
      return base;
    }

    let resolved;
    try{
      resolved=rpcData(await serviceRpc('aos_rev_resolve_patient_identity_v2',{p_lookup_type:'PHONE',p_lookup_value:phone}))||{};
    }catch(_){
      base.identity_state='IDENTITY_AUTHORITY_UNAVAILABLE';
      base.requires_human=true;
      base.limitations.push('CANONICAL_IDENTITY_RPC_UNAVAILABLE');
      base.prompt_context=safePrompt(base);
      return base;
    }

    const status=clean(resolved.status).toUpperCase();
    base.candidate_count=Number(resolved.candidate_count||0);
    base.confidence_band=clean(resolved.confidence_band)||null;
    if(status==='IDENTITY_CONFLICT'){
      base.identity_state='IDENTITY_CONFLICT';
      base.requires_human=true;
      base.limitations.push('MULTIPLE_CANONICAL_CANDIDATES');
      base.prompt_context=safePrompt(base);
      return base;
    }
    if(status!=='MATCH'||!clean(resolved.canonical_patient_id)){
      base.identity_state=status==='UNRESOLVED'?'NEW_OR_UNRESOLVED':(status||'UNRESOLVED');
      base.prompt_context=safePrompt(base);
      return base;
    }

    base.canonical_patient_id=clean(resolved.canonical_patient_id);
    base.identity_state='MATCH';
    base.existing_patient=true;
    try{
      const select='ID_PACIENTE,Nombres,Apellidos,Email,"N° documento",SEDE_PRINCIPAL,ESTADO_PACIENTE,numero_limpio';
      const out=await serviceGet('/rest/v1/aos_pacientes?ID_PACIENTE=eq.'+encodeURIComponent(base.canonical_patient_id)+'&select='+encodeURIComponent(select)+'&limit=1');
      const row=firstRow(out);
      if(!row){
        base.identity_state='CANONICAL_TARGET_MISSING';
        base.existing_patient=false;
        base.requires_human=true;
        base.limitations.push('CANONICAL_PATIENT_ROW_MISSING');
      }else{
        base.preferred_site=clean(row.SEDE_PRINCIPAL)||null;
        base.missing_booking_fields=bookingMissingFields(row);
        base.patient_minimum={
          canonical_patient_id:base.canonical_patient_id,
          has_name:!missing(row.Nombres),
          has_last_name:!missing(row.Apellidos),
          has_dni:!missing(row['N° documento']),
          has_email:!missing(row.Email),
          preferred_site:base.preferred_site,
          patient_state:clean(row.ESTADO_PACIENTE)||null
        };
      }
    }catch(_){
      base.identity_state='MATCH_MINIMUM_PROFILE_UNAVAILABLE';
      base.requires_human=false;
      base.limitations.push('MINIMUM_PATIENT_PROFILE_UNAVAILABLE');
    }
    base.prompt_context=safePrompt(base);
    return base;
  }

  return {resolve,version:VERSION};
}

module.exports={VERSION,createPatientIdentityAdapter,digits,bookingMissingFields,safePrompt};
