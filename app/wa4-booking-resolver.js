'use strict';

const VERSION='WA4C-BOOKING-RESOLVER-V3';
const DAY_NUM={LUNES:1,MARTES:2,MIERCOLES:3,JUEVES:4,VIERNES:5,SABADO:6,DOMINGO:7};
const SITE_DB={SAN_ISIDRO:'SAN ISIDRO',PUEBLO_LIBRE:'PUEBLO LIBRE'};
const WRITE_BOUNDARY='GOVERNED_HUMAN_BOOKING_WRITE_V1';

function clean(v){return String(v==null?'':v).trim();}
function norm(v){return clean(v).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[_-]+/g,' ').replace(/\s+/g,' ').trim();}
function rpcData(out){return out&&Object.prototype.hasOwnProperty.call(out,'data')?out.data:out;}
function firstRow(out){return out&&Array.isArray(out.data)?out.data[0]||null:null;}
function asArray(v){return Array.isArray(v)?v:[];}
function isUuid(v){return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(clean(v));}
function limaDate(now){
  const d=now instanceof Date?now:new Date(now||Date.now());
  try{return new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).format(d);}
  catch(_){return d.toISOString().slice(0,10);}
}
function addDays(iso,n){const [y,m,d]=iso.split('-').map(Number);const x=new Date(Date.UTC(y,m-1,d+n));return x.toISOString().slice(0,10);}
function dbDayForIso(iso){const [y,m,d]=iso.split('-').map(Number);const js=new Date(Date.UTC(y,m-1,d)).getUTCDay();return js===0?7:js;}
function resolveRequestedDate(requestedDay,now){
  const day=clean(requestedDay).toUpperCase();
  const today=limaDate(now);
  if(!day)return null;
  if(day==='TOMORROW')return addDays(today,1);
  const desired=DAY_NUM[day];
  if(!desired)return null;
  const current=dbDayForIso(today);
  const delta=(desired-current+7)%7;
  return addDays(today,delta);
}
function siteDb(v){const k=clean(v).toUpperCase();return SITE_DB[k]||clean(v).replace(/_/g,' ').toUpperCase()||null;}
function timeMinutes(v){const m=clean(v).match(/^(\d{1,2}):(\d{2})/);if(!m)return null;const h=Number(m[1]),mm=Number(m[2]);return h>=0&&h<24&&mm>=0&&mm<60?h*60+mm:null;}
function roleFromRows(rows){
  const pairs=new Set(asArray(rows).map(r=>(r.requiere_doctora===true?'D':'-')+(r.requiere_enfermeria===true?'N':'-')));
  if(!pairs.size)return {status:'TREATMENT_AUTHORITY_REQUIRED',roles:[]};
  if(pairs.size>1)return {status:'ROLE_AUTHORITY_CONFLICT',roles:[]};
  const pair=[...pairs][0];
  if(pair==='D-')return {status:'READY',roles:['DOCTORA']};
  if(pair==='-N')return {status:'READY',roles:['ENFERMERIA']};
  if(pair==='DN')return {status:'READY',roles:['DOCTORA','ENFERMERIA']};
  return {status:'ROLE_UNSPECIFIED',roles:[]};
}
function rankSlots(slots,requestedTime){
  const req=timeMinutes(requestedTime);
  const xs=asArray(slots).filter(x=>x&&x.disponible!==false&&timeMinutes(x.hora)!=null);
  if(req==null)return xs.sort((a,b)=>timeMinutes(a.hora)-timeMinutes(b.hora)||clean(a.role).localeCompare(clean(b.role)));
  return xs.sort((a,b)=>Math.abs(timeMinutes(a.hora)-req)-Math.abs(timeMinutes(b.hora)-req)||timeMinutes(a.hora)-timeMinutes(b.hora)||clean(a.role).localeCompare(clean(b.role)));
}
function publicSlot(s,date,site){
  return {
    date:date||null,
    time:clean(s&&s.hora).slice(0,5)||null,
    site:site||clean(s&&s.sede)||null,
    role:clean(s&&s.role)||null,
    professional_id:clean(s&&s.professional_id)||null,
    professional_name:clean(s&&s.professional_name)||null,
    booking_mode:clean(s&&s.mode)||null
  };
}
function safePrompt(result){
  return {
    version:VERSION,
    status:result.status,
    treatment_id:result.treatment_id||null,
    target_date:result.target_date||null,
    site:result.site||null,
    required_roles:result.required_roles||[],
    booking_mode:result.booking_mode||null,
    capability:result.capability||null,
    schedule_source_fresh:result.schedule_source_fresh===true,
    schedule_sources:result.schedule_sources||{},
    requested_time:result.requested_time||null,
    time_constraint:result.time_constraint||null,
    exact_requested_time_available:result.exact_requested_time_available===true,
    candidate_slot_count:Number(result.candidate_slot_count||0),
    candidate_slots:asArray(result.candidate_slots).slice(0,5).map(s=>publicSlot(s,result.target_date,result.site)),
    free_text_allowed:true,
    confirmation_allowed:false,
    explicit_confirmation_required:true,
    human_commit_required:true,
    write_boundary:WRITE_BOUNDARY,
    l5_autonomous_commit_boundary:'L4_EFFECTIVE_AUTHORITY_REQUIRED',
    slot_must_be_revalidated:true,
    limitations:result.limitations||[]
  };
}

function createBookingResolver(deps){
  deps=deps||{};
  const serviceGet=deps.serviceGet,serviceRpc=deps.serviceRpc;
  if(typeof serviceGet!=='function')throw new Error('WA4_BOOKING_SERVICE_GET_REQUIRED');
  if(typeof serviceRpc!=='function')throw new Error('WA4_BOOKING_SERVICE_RPC_REQUIRED');

  async function latestScheduleDate(role){
    const roleFilter=role?'&rol=eq.'+encodeURIComponent(role):'';
    const out=await serviceGet('/rest/v1/aos_horarios_personal?activo=eq.true'+roleFilter+'&select=fecha&order=fecha.desc&limit=1');
    const row=firstRow(out);return clean(row&&row.fecha)||null;
  }

  async function catalogRole(processContexts){
    const ids=[...new Set(asArray(processContexts).map(x=>clean(x&&x.entity_id)).filter(isUuid))].slice(0,24);
    if(!ids.length)return {status:'TREATMENT_AUTHORITY_REQUIRED',roles:[],rows:[],treatment_id:null};
    if(ids.length>1)return {status:'TREATMENT_SELECTION_REQUIRED',roles:[],rows:[],treatment_id:null};
    const select='id,nombre,categoria,requiere_doctora,requiere_enfermeria,estado';
    const out=await serviceGet('/rest/v1/aos_catalogo_servicios?id=eq.'+encodeURIComponent(ids[0])+'&select='+encodeURIComponent(select)+'&limit=1');
    const rows=asArray(out&&out.data);
    return Object.assign(roleFromRows(rows),{rows,treatment_id:rows[0]&&clean(rows[0].id)||ids[0]});
  }

  async function resolve(input){
    input=input||{};
    const runtime=input.runtime||{},state=runtime.state||{};
    const result={version:VERSION,status:'NOT_REQUESTED',target_date:null,site:null,treatment_id:null,required_roles:[],booking_mode:null,capability:null,schedule_source_fresh:false,schedule_source_max_date:null,schedule_sources:{},requested_time:clean(state.requested_time)||null,time_constraint:clean(state.time_constraint)||null,candidate_slots:[],candidate_slot_count:0,exact_requested_time_available:false,confirmation_allowed:false,human_commit_required:true,write_boundary:WRITE_BOUNDARY,limitations:[]};
    const wantsBooking=runtime.booking_readiness==='HIGH'||asArray(runtime.intents).some(x=>['BOOKING','SCHEDULE','HARD_TIME_CONSTRAINT','RESCHEDULE_INTENT','CONFIRM_BOOKING'].includes(String(x)));
    if(!wantsBooking){result.prompt_context=safePrompt(result);return result;}
    if(clean(state.requested_day).toUpperCase()==='DOMINGO'){
      result.status='CLOSED_DAY';result.limitations.push('SUNDAY_CLOSED');result.prompt_context=safePrompt(result);return result;
    }
    result.target_date=resolveRequestedDate(state.requested_day,input.now);
    if(!result.target_date){result.status='DATE_REQUIRED';result.prompt_context=safePrompt(result);return result;}
    result.site=siteDb(state.site||input.preferred_site);
    if(!result.site){result.status='SITE_REQUIRED';result.prompt_context=safePrompt(result);return result;}

    let role;
    try{role=await catalogRole(input.processContexts);}catch(_){role={status:'TREATMENT_AUTHORITY_UNAVAILABLE',roles:[],treatment_id:null};}
    result.required_roles=role.roles||[];
    result.treatment_id=role.treatment_id||null;
    if(role.status!=='READY'){
      result.status=role.status;result.limitations.push(role.status);result.prompt_context=safePrompt(result);return result;
    }

    const dayNum=dbDayForIso(result.target_date);
    try{
      const hours=await serviceGet('/rest/v1/aos_config_horarios?sede=eq.'+encodeURIComponent(result.site)+'&dia_semana=eq.'+dayNum+'&select='+encodeURIComponent('sede,dia_semana,hora_apertura,hora_cierre,activo')+'&limit=2');
      const row=firstRow(hours);
      if(!row||row.activo!==true){result.status='CLOSED_DAY';result.limitations.push('SITE_CLOSED_FOR_REQUESTED_DATE');result.prompt_context=safePrompt(result);return result;}
    }catch(_){result.status='PUBLIC_HOURS_AUTHORITY_UNAVAILABLE';result.limitations.push('PUBLIC_HOURS_AUTHORITY_UNAVAILABLE');result.prompt_context=safePrompt(result);return result;}

    try{
      const entries=await Promise.all(result.required_roles.map(async r=>[r,await latestScheduleDate(r)]));
      entries.forEach(([r,d])=>{result.schedule_sources[r]=d||null;});
      const dates=entries.map(x=>x[1]).filter(Boolean).sort();
      result.schedule_source_max_date=dates.length?dates[dates.length-1]:null;
      const fresh=entries.filter(x=>x[1]&&x[1]>=result.target_date).map(x=>x[0]);
      const stale=entries.filter(x=>!x[1]||x[1]<result.target_date).map(x=>x[0]);
      stale.forEach(r=>result.limitations.push('DATE_SPECIFIC_SCHEDULE_STALE_'+r));
      if(!fresh.length){result.status='SCHEDULE_SOURCE_STALE';result.limitations.push('DATE_SPECIFIC_SCHEDULE_STALE');result.prompt_context=safePrompt(result);return result;}
      result.schedule_source_fresh=true;
    }catch(_){result.status='SCHEDULE_SOURCE_UNAVAILABLE';result.limitations.push('DATE_SPECIFIC_SCHEDULE_UNAVAILABLE');result.prompt_context=safePrompt(result);return result;}

    let auth;
    try{
      auth=rpcData(await serviceRpc('aos_booking_availability_v2',{
        p_treatment_id:result.treatment_id,
        p_fecha:result.target_date,
        p_sede:result.site,
        p_profesional_id:clean(input.preferred_professional_id)||null
      }))||{};
    }catch(_){
      result.status='BOOKING_AUTHORITY_UNAVAILABLE';result.limitations.push('BOOKING_AUTHORITY_UNAVAILABLE');result.prompt_context=safePrompt(result);return result;
    }
    if(auth.ok!==true){
      result.status=clean(auth.status)||'BOOKING_AUTHORITY_BLOCKED';
      result.booking_mode=clean(auth.mode)||null;
      result.capability=clean(auth.capability)||null;
      result.limitations.push(result.status);result.prompt_context=safePrompt(result);return result;
    }

    result.booking_mode=clean(auth.mode)||null;
    result.capability=clean(auth.capability)||null;
    if(auth.schedule_sources&&typeof auth.schedule_sources==='object')result.schedule_sources=auth.schedule_sources;
    const candidates=asArray(auth.slots).map(s=>({
      professional_id:clean(s.professional_id)||null,
      professional_name:clean(s.professional_name)||(clean(s.mode)==='SITE_POOL'?'Enfermería':null),
      role:clean(s.role)||result.required_roles[0],
      mode:clean(s.mode)||result.booking_mode,
      hora:clean(s.hora),
      sede:clean(s.sede)||result.site,
      libres:Number(s.libres||0),
      capacidad:Number(s.capacidad||0),
      member_count:Number(s.member_count||0),
      disponible:s.disponible!==false
    }));
    result.candidate_slots=rankSlots(candidates,result.requested_time).slice(0,12);
    result.candidate_slot_count=result.candidate_slots.length;
    result.exact_requested_time_available=Boolean(result.requested_time&&result.candidate_slots.some(x=>clean(x.hora).slice(0,5)===result.requested_time.slice(0,5)));
    result.status=result.candidate_slot_count?'REAL_SLOTS_READY':'NO_REAL_SLOTS';
    result.prompt_context=safePrompt(result);
    return result;
  }

  async function revalidateSlot(input){
    input=input||{};
    const targetDate=clean(input.target_date),treatmentId=clean(input.treatment_id),professionalId=clean(input.professional_id)||null,time=clean(input.time).slice(0,5),site=siteDb(input.site),requestedRole=clean(input.role||input.professional_role).toUpperCase();
    if(!targetDate||!isUuid(treatmentId)||!time||!site)return {ok:false,status:'INVALID_REVALIDATION_INPUT',version:VERSION,confirmation_allowed:false,human_commit_required:true,write_boundary:WRITE_BOUNDARY};
    try{
      const data=rpcData(await serviceRpc('aos_booking_availability_v2',{p_treatment_id:treatmentId,p_fecha:targetDate,p_sede:site,p_profesional_id:professionalId}))||{};
      if(data.ok!==true)return {ok:false,status:clean(data.status)||'BOOKING_AUTHORITY_BLOCKED',version:VERSION,confirmation_allowed:false,human_commit_required:true,write_boundary:WRITE_BOUNDARY};
      if(clean(data.mode)==='MULTI_ROLE'&&!professionalId&&!requestedRole)return {ok:false,status:'ROLE_SELECTION_REQUIRED',version:VERSION,confirmation_allowed:false,human_commit_required:true,write_boundary:WRITE_BOUNDARY};
      const slot=asArray(data.slots).find(x=>clean(x&&x.hora).slice(0,5)===time&&x.disponible!==false&&(!professionalId||clean(x.professional_id)===professionalId)&&(!requestedRole||clean(x.role).toUpperCase()===requestedRole));
      return {ok:Boolean(slot),status:slot?'REVALIDATED_AVAILABLE':'NO_LONGER_AVAILABLE',slot:slot||null,booking_mode:slot?clean(slot.mode):clean(data.mode)||null,version:VERSION,confirmation_allowed:false,human_commit_required:true,write_boundary:WRITE_BOUNDARY};
    }catch(_){return {ok:false,status:'SLOT_REVALIDATION_UNAVAILABLE',version:VERSION,confirmation_allowed:false,human_commit_required:true,write_boundary:WRITE_BOUNDARY};}
  }

  return {resolve,revalidateSlot,version:VERSION};
}

module.exports={VERSION,WRITE_BOUNDARY,DAY_NUM,SITE_DB,createBookingResolver,limaDate,resolveRequestedDate,dbDayForIso,siteDb,roleFromRows,rankSlots,safePrompt,publicSlot};
