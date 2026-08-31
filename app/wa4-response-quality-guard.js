'use strict';

const VERSION='WA4C-RESPONSE-QUALITY-GUARD-V1';
const MAX_REPLY_CHARS=900;

function clean(v){return String(v==null?'':v).trim();}
function norm(v){return clean(v).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/\s+/g,' ').trim();}
function asArray(v){return Array.isArray(v)?v:[];}
function addViolation(list,code){if(code&&!list.includes(code))list.push(code);}
function questionCount(reply){return (clean(reply).match(/\?/g)||[]).length;}
function humanValidation(text){return /\b(validar|validamos|validacion|verificar|verificamos|revisar|revisamos|confirmar manualmente|asesor|asesora|equipo)\b/.test(text);}
function bookingContext(input){return input&&input.contexts&&input.contexts.booking||{};}
function runtimeState(input){return input&&input.runtime&&input.runtime.state||{};}
function runtimeIntents(input){return asArray(input&&input.runtime&&input.runtime.intents).map(String);}
function hasMoneyAnswer(text){return /(?:s\/?\.?\s*\d|usd\s*\d|\$\s*\d|\b\d+(?:[.,]\d+)?\s*(?:soles?|dolares?|usd)\b|\bcuesta\s+\d)/.test(text)||humanValidation(text);}
function hasPromoAnswer(text){return /\b(?:promo|promocion|oferta|descuento|vigencia)\b|\bno (?:tenemos|hay) (?:una )?(?:promo|promocion|oferta|descuento)\b/.test(text)||humanValidation(text);}
function hasLocationAnswer(text){return /\b(?:san isidro|pueblo libre|direccion|maps|mapa)\b/.test(text)||humanValidation(text);}
function hasWhoAnswer(text){return /\b(?:doctora|doctor|enfermera|enfermeria|equipo clinico|personal clinico)\b/.test(text)||humanValidation(text);}
function hasSessionAnswer(text){return /\b\d+\s+sesiones?\b|\buna sola sesion\b|\bdepende\b|\bevaluacion\b/.test(text)||humanValidation(text);}
function availabilityAssertion(text){
  return /\b(hay|tenemos|tengo|queda|quedan)\s+(?:un\s+)?(?:cupo|cupos|disponibilidad|horario disponible)|\b(?:esta|estan)\s+disponible|\bpuedo\s+(?:confirmarte|separarte|reservarte)\s+(?:ese|el)?\s*horario/.test(text);
}
function bookingConfirmation(text){
  return /\b(?:tu|la)\s+cita\s+(?:esta|quedo)\s+(?:confirmada|agendada|reservada)|\b(?:cita|reserva)\s+confirmada|\bte\s+(?:agende|reserve)\b/.test(text);
}
function leaksInternalState(text){
  return /canonical_patient_id|identity_state|booking_readiness|next_best_action|evidence_ref|runtime_policy|adapter_contexts|wa4c-|aos_wa4|aos_rev_/.test(text);
}
function repeatedKnownQuestion(text,state){
  const violations=[];
  if(clean(state.treatment)&&/(que|cual)\s+(?:tratamiento|servicio).*(interesa|buscas|quieres)|en que (?:tratamiento|servicio)/.test(text))violations.push('REPEATED_TREATMENT_QUESTION');
  if(clean(state.site)&&/(que|cual)\s+sede|san isidro\s+o\s+pueblo libre|pueblo libre\s+o\s+san isidro/.test(text))violations.push('REPEATED_SITE_QUESTION');
  if(clean(state.requested_day)&&/(que|cual)\s+(?:dia|fecha)|que dia te/.test(text))violations.push('REPEATED_DATE_QUESTION');
  if(clean(state.requested_time)&&/(que|cual)\s+(?:hora|horario)|a que hora/.test(text))violations.push('REPEATED_TIME_QUESTION');
  return violations;
}
function availabilityBacked(booking){
  if(!booking||booking.schedule_source_fresh!==true)return false;
  return booking.exact_requested_time_available===true||Number(booking.candidate_slot_count||0)>0;
}
function explicitIntentCoverage(intents,text,violations){
  const needsPrice=intents.some(x=>['CONSULTATION_PRICE','PRICE_PER_SESSION','TREATMENT_PRICE'].includes(x));
  if(needsPrice&&!hasMoneyAnswer(text))addViolation(violations,'EXPLICIT_PRICE_UNANSWERED');
  if(intents.includes('PROMOTION_REQUEST')&&!hasPromoAnswer(text))addViolation(violations,'EXPLICIT_PROMOTION_UNANSWERED');
  if(intents.includes('LOCATION')&&!hasLocationAnswer(text))addViolation(violations,'EXPLICIT_LOCATION_UNANSWERED');
  if(intents.includes('WHO_PERFORMS')&&!hasWhoAnswer(text))addViolation(violations,'EXPLICIT_PROVIDER_ROLE_UNANSWERED');
  if(intents.includes('SESSION_COUNT')&&!hasSessionAnswer(text))addViolation(violations,'EXPLICIT_SESSION_COUNT_UNANSWERED');
}

function validate(input){
  input=input||{};
  const reply=clean(input.reply),text=norm(reply),violations=[];
  const state=runtimeState(input),intents=runtimeIntents(input),booking=bookingContext(input);
  const questions=questionCount(reply);

  if(!reply)addViolation(violations,'EMPTY_REPLY');
  if(reply.length>MAX_REPLY_CHARS)addViolation(violations,'REPLY_TOO_LONG');
  if(questions>1)addViolation(violations,'EXCESSIVE_QUESTIONS');
  if(leaksInternalState(text))addViolation(violations,'INTERNAL_STATE_LEAK');
  for(const code of repeatedKnownQuestion(text,state))addViolation(violations,code);
  if(bookingConfirmation(text)&&booking.confirmation_allowed!==true)addViolation(violations,'UNAUTHORIZED_BOOKING_CONFIRMATION');
  if(availabilityAssertion(text)&&!availabilityBacked(booking))addViolation(violations,'UNSUPPORTED_AVAILABILITY_ASSERTION');
  explicitIntentCoverage(intents,text,violations);

  return {
    version:VERSION,
    ok:violations.length===0,
    violations,
    metrics:{reply_chars:reply.length,question_count:questions,max_reply_chars:MAX_REPLY_CHARS},
    fail_closed:true
  };
}

module.exports={VERSION,MAX_REPLY_CHARS,validate,norm,questionCount,availabilityAssertion,bookingConfirmation,repeatedKnownQuestion,explicitIntentCoverage};
