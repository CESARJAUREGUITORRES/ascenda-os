'use strict';

// WA-4C Conversation Runtime V2
// Pure decision support only. No DB writes, no Meta sends, no clinical diagnosis.
// Converts real WhatsApp behavior into a governed semantic turn for Copilot/booking.

const VERSION='WA4C-CONVERSATION-RUNTIME-V2';
const BURST_WINDOW_MS=4500;

function normalize(v){
  return String(v==null?'':v).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();
}
function inbound(m){return String(m&&m.direction||'').toUpperCase().includes('IN');}
function asTime(m){const n=Date.parse(String(m&&m.created_at||''));return Number.isFinite(n)?n:null;}
function textOf(m){return String(m&&m.message_body||'').trim();}
function uniq(xs){return [...new Set(xs.filter(Boolean))];}

function aggregateLatestInboundBurst(messages,windowMs){
  const ms=Array.isArray(messages)?messages:[];
  const w=Math.max(500,Math.min(Number(windowMs||BURST_WINDOW_MS),12000));
  let end=-1;
  for(let i=ms.length-1;i>=0;i--){if(inbound(ms[i])){end=i;break;}}
  if(end<0)return {text:'',latest_text:'',parts:[],count:0,burst:false,window_ms:w};
  const out=[ms[end]];
  let cursor=end;
  while(cursor>0){
    const prev=ms[cursor-1];
    if(!inbound(prev))break;
    const a=asTime(prev),b=asTime(ms[cursor]);
    if(a!=null&&b!=null&&b-a>w)break;
    out.unshift(prev);cursor--;
  }
  const parts=out.map(textOf).filter(Boolean);
  return {text:parts.join('\n'),latest_text:parts.length?parts[parts.length-1]:'',parts,count:parts.length,burst:parts.length>1,window_ms:w};
}

function treatmentHint(text,campaign){
  const t=normalize(text+' '+String(campaign||''));
  if(/toxina|botox|nabota|hutox/.test(t))return 'TOXINA_BOTULINICA';
  if(/armonizacion facial|perfil facial/.test(t))return 'ARMONIZACION_FACIAL';
  if(/bioestimulador|colageno/.test(t))return 'BIOESTIMULADOR_COLAGENO';
  if(/hifu/.test(t))return 'HIFU';
  if(/capilar|cabello|alopecia|caida/.test(t))return 'CAPILAR';
  if(/hidrofacial|hydrafacial/.test(t))return 'HIDROFACIAL';
  return null;
}

function detectIntents(text){
  const t=normalize(text), intents=[];
  const add=x=>{if(!intents.includes(x))intents.push(x);};
  if(/donde queda|direccion|ubicacion|sede|otra sede/.test(t))add('LOCATION');
  if(/vivo en|me queda cerca|estare cerca|quedaria mas cerca/.test(t))add('PROXIMITY_CONSTRAINT');
  if(/precio de la consulta|consulta.*cuesta|consulta.*costo|consulta tiene costo|evaluacion.*cuesta|evaluacion.*costo/.test(t))add('CONSULTATION_PRICE');
  if(/precio de la sesion|cuanto cuesta la sesion|valor de la sesion/.test(t))add('PRICE_PER_SESSION');
  if(/precio|cuanto cuesta|cuanto sale|costo|valor/.test(t))add('TREATMENT_PRICE');
  if(/promo|promocion|oferta|descuento|rebaja/.test(t))add('PROMOTION_REQUEST');
  if(/cuantas sesiones|numero de sesiones|sesiones necesito|una sola sesion/.test(t))add('SESSION_COUNT');
  if(/una sola sesion.*mejor|se consigue mejorar|voy a mejorar|resultado/.test(t))add('EXPECTED_RESULT');
  if(/cuanto dura|duracion|cuanto tiempo dura/.test(t)){
    if(/aplicacion|procedimiento|sesion|cita/.test(t))add('PROCEDURE_DURATION');
    else add('EFFECT_DURATION');
  }
  if(/cuando se ve|cuando veo|empieza a hacer efecto|resultados.*dias/.test(t))add('RESULT_ONSET');
  if(/cada cuanto|mantenimiento|cuando repetir/.test(t))add('MAINTENANCE_INTERVAL');
  if(/doctora.*atiende|quien atiende|quien lo hace|quien realiza|profesional/.test(t))add('WHO_PERFORMS');
  if(/que productos|con que productos|que marcas|cuales marcas|marca usan/.test(t))add('PRODUCT_OR_BRAND_OPTIONS');
  if(/forma de pago|como pago|tarjeta|yape|plin|efectivo|cuotas|adelanto/.test(t))add('PAYMENT');
  if(/agendar|agenda|reservar|reserva|una cita|quiero cita|cita por favor|separar cita/.test(t))add('BOOKING');
  if(/horario|disponibilidad|puedo ir|mañana|manana|lunes|martes|miercoles|jueves|viernes|sabado|domingo|\b\d{1,2}(:\d{2})?\s*(am|pm)\b/.test(t))add('SCHEDULE');
  if(/solo puedo|unicamente puedo|únicamente puedo|solo tengo disponibilidad|esa hora nada mas/.test(t))add('HARD_TIME_CONSTRAINT');
  if(/llamare.*proxima semana|llamaré.*próxima semana|despues coordino|después coordino|mas adelante|más adelante/.test(t))add('DEFER_OR_FOLLOW_UP_LATER');
  if(/foto|imagen|antes y despues|antes y después|video|resultados reales/.test(t))add('MEDIA_REQUEST');
  if(/informacion|información|quiero saber|como funciona|cómo funciona|que es|qué es/.test(t))add('INFO');
  return intents;
}

function extractSlots(text,campaign){
  const t=normalize(text), slots={};
  const tr=treatmentHint(text,campaign); if(tr)slots.treatment=tr;
  if(/san isidro/.test(t))slots.site='SAN_ISIDRO';
  else if(/pueblo libre/.test(t))slots.site='PUEBLO_LIBRE';
  const zones=[];
  if(/frente/.test(t))zones.push('FRENTE');
  if(/entrecejo/.test(t))zones.push('ENTRECEJO');
  if(/patitas|patas de gallo/.test(t))zones.push('PATAS_DE_GALLO');
  if(zones.length)slots.zones=uniq(zones);
  if(/nabota/.test(t))slots.brand='NABOTA'; else if(/hutox/.test(t))slots.brand='HUTOX';
  if(/domingo/.test(t))slots.requested_day='DOMINGO';
  else if(/sabado/.test(t))slots.requested_day='SABADO';
  else if(/viernes/.test(t))slots.requested_day='VIERNES';
  else if(/jueves/.test(t))slots.requested_day='JUEVES';
  else if(/miercoles/.test(t))slots.requested_day='MIERCOLES';
  else if(/martes/.test(t))slots.requested_day='MARTES';
  else if(/lunes/.test(t))slots.requested_day='LUNES';
  else if(/mañana|manana/.test(t))slots.requested_day='TOMORROW';
  const tm=t.match(/\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b/);
  if(tm){let h=Number(tm[1]),m=Number(tm[2]||0);if(tm[3]==='pm'&&h<12)h+=12;if(tm[3]==='am'&&h===12)h=0;slots.requested_time=String(h).padStart(2,'0')+':'+String(m).padStart(2,'0');}
  if(/solo puedo|unicamente puedo|solo tengo disponibilidad|esa hora nada mas/.test(t))slots.time_constraint='HARD';
  if(/vivo en|estare cerca|quedaria mas cerca|me queda cerca/.test(t))slots.proximity_constraint=true;
  return slots;
}

function mergeState(messages,conversation){
  const state={campaign_source:conversation&&conversation.campaign_source||null,treatment:null,site:null,zones:[],brand:null,requested_day:null,requested_time:null,time_constraint:null,proximity_constraint:false};
  for(const m of Array.isArray(messages)?messages:[]){
    if(!inbound(m))continue;
    const s=extractSlots(textOf(m),state.campaign_source);
    if(s.treatment)state.treatment=s.treatment;
    if(s.site)state.site=s.site;
    if(s.brand)state.brand=s.brand;
    if(s.zones)state.zones=uniq(state.zones.concat(s.zones));
    if(s.requested_day)state.requested_day=s.requested_day;
    if(s.requested_time)state.requested_time=s.requested_time;
    if(s.time_constraint)state.time_constraint=s.time_constraint;
    if(s.proximity_constraint)state.proximity_constraint=true;
  }
  if(!state.treatment)state.treatment=treatmentHint('',state.campaign_source);
  return state;
}

function bookingReadiness(intents,state){
  if(intents.includes('DEFER_OR_FOLLOW_UP_LATER'))return 'PAUSED';
  if(intents.includes('BOOKING')||intents.includes('SCHEDULE')||state.requested_day||state.requested_time)return 'HIGH';
  if(intents.some(x=>['TREATMENT_PRICE','CONSULTATION_PRICE','PRICE_PER_SESSION','PROMOTION_REQUEST','MEDIA_REQUEST'].includes(x)))return 'MEDIUM';
  return 'LOW';
}

function nextBestAction(intents,state){
  if(intents.includes('DEFER_OR_FOLLOW_UP_LATER'))return 'ACKNOWLEDGE_DEFER';
  const explicitPriority=['CONSULTATION_PRICE','PRICE_PER_SESSION','TREATMENT_PRICE','PROMOTION_REQUEST','LOCATION','WHO_PERFORMS','PRODUCT_OR_BRAND_OPTIONS','SESSION_COUNT','EXPECTED_RESULT','EFFECT_DURATION','PROCEDURE_DURATION','RESULT_ONSET','MAINTENANCE_INTERVAL','PAYMENT','MEDIA_REQUEST'];
  const explicit=explicitPriority.filter(x=>intents.includes(x));
  if(explicit.length)return 'ANSWER_EXPLICIT_QUESTIONS';
  if(intents.includes('BOOKING')||intents.includes('SCHEDULE')){
    if(state.requested_day==='DOMINGO')return 'REJECT_CLOSED_DAY_AND_REQUEST_ALTERNATIVE';
    if(state.requested_day&&state.requested_time)return state.time_constraint==='HARD'?'CHECK_EXACT_SLOT_FIRST':'CHECK_REQUESTED_SLOT';
    if(!state.site)return 'COLLECT_SITE';
    if(!state.requested_day)return 'COLLECT_DATE';
    return 'CHECK_REAL_AVAILABILITY';
  }
  if(!state.treatment)return 'CLARIFY_TREATMENT_OR_GOAL';
  return 'RESPOND_AND_ADVANCE_ONE_STEP';
}

function questionMode(intents,state,readiness){
  if(readiness==='PAUSED')return 'NONE';
  if(nextBestAction(intents,state)==='ANSWER_EXPLICIT_QUESTIONS')return 'GUIDED_CHOICE';
  if(readiness==='HIGH')return 'DIRECT_CONFIRMATION';
  if(state.treatment)return 'GUIDED_CHOICE';
  return 'OPEN_DISCOVERY';
}

function promptPolicy(runtime){
  return {
    version:VERSION,
    instructions:[
      'Answer every material explicit customer question before advancing sales or booking.',
      'Use known campaign/treatment/site/zone/time context; never ask again for a resolved slot.',
      'Within a burst, preserve all intents but treat the latest explicit message as authoritative for the current product/service/entity.',
      'One outbound message per semantic customer turn by default; a second outbound requires a real transport/media reason.',
      'Write concise professional WhatsApp Spanish with low emoji density and natural line breaks.',
      'Free text is the default. Use interactive buttons only when they reduce friction for a concrete decision.',
      'If booking readiness is HIGH, stop generic selling and execute the next booking step.',
      'If the customer provides a hard time constraint, check that exact slot first and only then nearest alternatives.',
      'If the customer defers, acknowledge without pressure and do not pretend a follow-up was scheduled.',
      'Never invent prices, promotions, treatment facts, professional roles, addresses or availability; use governed authorities.',
      'Never diagnose from text, audio, image or video. Personalized clinical risk requires human clinical escalation.'
    ],
    semantic_turn:runtime.semantic_turn,
    intents:runtime.intents,
    conversation_state:runtime.state,
    booking_readiness:runtime.booking_readiness,
    question_mode:runtime.question_mode,
    next_best_action:runtime.next_best_action,
    guards:runtime.guards
  };
}

function buildRuntimeContext(input){
  input=input||{};
  const messages=Array.isArray(input.messages)?input.messages:[];
  const conversation=input.conversation||{};
  const semantic=aggregateLatestInboundBurst(messages,input.burst_window_ms);
  const intents=detectIntents(semantic.text);
  const state=mergeState(messages,conversation);
  const current=extractSlots(semantic.latest_text||semantic.text,state.campaign_source);
  Object.assign(state,current,{zones:uniq((state.zones||[]).concat(current.zones||[]))});
  const readiness=bookingReadiness(intents,state);
  const nba=nextBestAction(intents,state);
  const runtime={
    version:VERSION,
    semantic_turn:semantic,
    intents,
    state,
    booking_readiness:readiness,
    question_mode:questionMode(intents,state,readiness),
    next_best_action:nba,
    guards:{
      explicit_question_first:true,
      latest_explicit_entity_wins:true,
      anti_repeat:true,
      one_outbound_default:true,
      max_outbound_without_transport_exception:1,
      free_text_default:true,
      auto_send:false,
      human_only:true,
      slot_must_be_revalidated_before_confirmation:true,
      sunday_closed:true,
      multimodal_diagnosis_forbidden:true
    }
  };
  runtime.prompt_policy=promptPolicy(runtime);
  return runtime;
}

module.exports={VERSION,BURST_WINDOW_MS,normalize,aggregateLatestInboundBurst,detectIntents,extractSlots,mergeState,buildRuntimeContext,promptPolicy};
