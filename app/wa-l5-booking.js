'use strict';

const VERSION='WA-L5-RUNTIME-V1';
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function clean(v){return String(v==null?'':v).trim();}
function rpcData(out){return out&&Object.prototype.hasOwnProperty.call(out,'data')?out.data:out;}
function validDate(v){return /^\d{4}-\d{2}-\d{2}$/.test(clean(v));}
function validTime(v){return /^([01]\d|2[0-3]):[0-5]\d$/.test(clean(v).slice(0,5));}
function bool(v){return v===true;}

function bookingToolPlan(runtime,booking){
  runtime=runtime||{};booking=booking||{};
  const intents=Array.isArray(runtime.intents)?runtime.intents:[];
  if(intents.includes('RESCHEDULE_INTENT'))return {action:'START_REBOOK_VERIFICATION',write:false,requires_strong_verification:true};
  if(intents.includes('CONFIRM_BOOKING'))return {action:'MARK_EXPLICIT_CONFIRMATION',write:false,requires_pending_confirmation:true};
  if(runtime.booking_readiness!=='HIGH')return {action:'NONE',write:false};
  if(booking.requires_human===true||String(booking.status||'').includes('CONFLICT'))return {action:'HUMAN_HANDOFF',write:false};
  if(booking.status==='SITE_REQUIRED')return {action:'COLLECT_SITE',write:false};
  if(booking.status==='DATE_REQUIRED')return {action:'COLLECT_DATE',write:false};
  if(booking.status==='CLOSED_DAY')return {action:'COLLECT_ALTERNATIVE_DATE',write:false};
  if(booking.status==='NO_REAL_SLOTS')return {action:'OFFER_ALTERNATIVE_DATE',write:false};
  if(booking.status!=='REAL_SLOTS_READY')return {action:'WAIT_FOR_GOVERNED_BOOKING_CONTEXT',write:false,status:booking.status||null};
  const slots=Array.isArray(booking.candidate_slots)?booking.candidate_slots.slice(0,5):[];
  const requested=clean(runtime.state&&runtime.state.requested_time).slice(0,5);
  const exact=requested?slots.find(s=>clean(s&&s.time||s&&s.hora).slice(0,5)===requested):null;
  if(exact&&booking.treatment_id&&booking.target_date&&booking.site){
    return {
      action:'PREPARE_EXPLICIT_CONFIRMATION',write:false,
      payload:{
        flow:'BOOK',treatment_id:booking.treatment_id,site:booking.site,date:booking.target_date,time:requested,
        professional_id:clean(exact.professional_id)||null,slot_role:clean(exact.role)||null
      },
      explicit_confirmation_required:true,
      autonomous_commit_requires_l4:true
    };
  }
  return {action:'OFFER_REAL_SLOTS',write:false,options:slots,free_text_allowed:true,max_options:5};
}

function createL5Booking(deps){
  deps=deps||{};
  const serviceRpc=deps.serviceRpc;
  if(typeof serviceRpc!=='function')throw new Error('WA_L5_SERVICE_RPC_REQUIRED');

  async function call(name,payload){
    const out=rpcData(await serviceRpc(name,payload));
    return out&&typeof out==='object'?out:{ok:false,error:'WA_L5_EMPTY_RESPONSE'};
  }

  async function status(conversationId){
    if(!UUID_RE.test(clean(conversationId)))return {ok:false,error:'WA_L5_CONVERSATION_INVALID'};
    return call('aos_wa_l5_status_v1',{p_conversation_id:conversationId});
  }

  async function availability(conversationId,body){
    body=body||{};
    const treatment=clean(body.treatment_id),site=clean(body.site).toUpperCase().replace(/_/g,' '),date=clean(body.start_date||body.date);
    if(!UUID_RE.test(clean(conversationId))||!UUID_RE.test(treatment)||!['SAN ISIDRO','PUEBLO LIBRE'].includes(site))return {ok:false,error:'WA_L5_AVAILABILITY_REQUEST_INVALID'};
    if(date&&!validDate(date))return {ok:false,error:'WA_L5_DATE_INVALID'};
    return call('aos_wa_l5_availability_v1',{
      p_conversation_id:conversationId,p_treatment_id:treatment,p_site:site,p_start_date:date||null,
      p_professional_id:clean(body.professional_id)||null,p_slot_role:clean(body.slot_role).toUpperCase()||null,
      p_search_days:date?1:Math.max(1,Math.min(Number(body.search_days||14),21))
    });
  }

  async function verify(conversationId,body){
    body=body||{};
    const document=clean(body.document);
    if(!UUID_RE.test(clean(conversationId))||document.length<6||document.length>32)return {ok:false,error:'WA_L5_VERIFICATION_REQUEST_INVALID'};
    return call('aos_wa_l5_verify_patient_v1',{p_conversation_id:conversationId,p_document:document});
  }

  async function appointments(conversationId){
    if(!UUID_RE.test(clean(conversationId)))return {ok:false,error:'WA_L5_CONVERSATION_INVALID'};
    return call('aos_wa_l5_active_appointments_v1',{p_conversation_id:conversationId});
  }

  async function prepare(conversationId,body){
    body=body||{};
    const flow=clean(body.flow||'BOOK').toUpperCase(),treatment=clean(body.treatment_id),site=clean(body.site).toUpperCase().replace(/_/g,' '),date=clean(body.date),time=clean(body.time).slice(0,5);
    if(!UUID_RE.test(clean(conversationId))||!['BOOK','REBOOK'].includes(flow)||!['SAN ISIDRO','PUEBLO LIBRE'].includes(site)||!validDate(date)||!validTime(time))return {ok:false,error:'WA_L5_PREPARE_REQUEST_INVALID'};
    if(flow==='BOOK'&&!UUID_RE.test(treatment))return {ok:false,error:'WA_L5_TREATMENT_REQUIRED'};
    if(flow==='REBOOK'&&!clean(body.appointment_id))return {ok:false,error:'WA_L5_APPOINTMENT_REQUIRED'};
    if(body.treatment_id&&!UUID_RE.test(treatment))return {ok:false,error:'WA_L5_TREATMENT_INVALID'};
    return call('aos_wa_l5_prepare_confirmation_v1',{
      p_conversation_id:conversationId,p_flow:flow,p_treatment_id:treatment||null,p_site:site,p_date:date,p_time:time,
      p_professional_id:clean(body.professional_id)||null,p_slot_role:clean(body.slot_role).toUpperCase()||null,
      p_appointment_id:clean(body.appointment_id)||null,p_given_name:clean(body.given_name)||null,p_family_name:clean(body.family_name)||null,
      p_confirmation_ttl_seconds:Math.max(60,Math.min(Number(body.confirmation_ttl_seconds||600),1800))
    });
  }

  async function confirm(conversationId,body){
    body=body||{};
    const nonce=clean(body.confirmation_nonce),providerMessageId=clean(body.provider_message_id);
    if(!UUID_RE.test(clean(conversationId))||!UUID_RE.test(nonce)||providerMessageId.length<3||providerMessageId.length>256)return {ok:false,error:'WA_L5_CONFIRMATION_REQUEST_INVALID'};
    return call('aos_wa_l5_mark_explicit_confirmation_v1',{p_conversation_id:conversationId,p_confirmation_nonce:nonce,p_provider_message_id:providerMessageId});
  }

  return {version:VERSION,status,availability,verify,appointments,prepare,confirm,bookingToolPlan};
}

module.exports={VERSION,UUID_RE,createL5Booking,bookingToolPlan,validDate,validTime};
