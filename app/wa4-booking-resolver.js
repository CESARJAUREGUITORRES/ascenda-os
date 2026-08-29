'use strict';

const VERSION='WA4C-BOOKING-RESOLVER-V1';
const DAY_NUM={LUNES:1,MARTES:2,MIERCOLES:3,JUEVES:4,VIERNES:5,SABADO:6,DOMINGO:7};
const SITE_DB={SAN_ISIDRO:'SAN ISIDRO',PUEBLO_LIBRE:'PUEBLO LIBRE'};

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
  if(pair==='DN')return {status:'COMPLEX_ROLE_REQUIRES_HUMAN',roles:['DOCTORA','ENFERMERIA']};
  return {status:'ROLE_UNSPECIFIED',roles:[]};
}
function rankSlots(slots,requestedTime){
  const req=timeMinutes(requestedTime);
  const xs=asArray(slots).filter(x=>x&&x.disponible!==false&&timeMinutes(x.hora)!=null);
  if(req==null)return xs.sort((a,b)=>timeMinutes(a.hora)-timeMinutes(b.hora));
  return xs.sort((a,b)=>Math.abs(timeMinutes(a.hora)-req)-Math.abs(timeMinutes(b.hora)-req)||timeMinutes(a.hora)-timeMinutes(b.hora));
}
function safePrompt(result){
  return {
    version:VERSION,
    status:result.status,
    target_date:result.target_date||null,
    site:result.site||null,
    required_roles:result.required_roles||[],
    schedule_source_fresh:result.schedule_source_fresh===true,
    requested_time:result.requested_time||null,
    time_constraint:result.time_constraint||null,
    exact_requested_time_available:result.exact_requested_time_available===true,
    candidate_slot_count:Number(result.candidate_slot_count||0),
    confirmation_allowed:false,
    slot_must_be_revalidated:true,
    limitations:result.limitations||[]
  };
}

function createBookingResolver(deps){
  deps=deps||{};
  const serviceGet=deps.serviceGet,serviceRpc=deps.serviceRpc;
  if(typeof serviceGet!=='function')throw new Error('WA4_BOOKING_SERVICE_GET_REQUIRED');
  if(typeof serviceRpc!=='function')throw new Error('WA4_BOOKING_SERVICE_RPC_REQUIRED');

  async function latestScheduleDate(){
    const out=await serviceGet('/rest/v1/aos_horarios_personal?activo=eq.true&select=fecha&order=fecha.desc&limit=1');
    const row=firstRow(out);return clean(row&&row.fecha)||null;
  }

  async function catalogRole(processContexts){
    const ids=[...new Set(asArray(processContexts).map(x=>clean(x&&x.entity_id)).filter(isUuid))].slice(0,24);
    if(!ids.length)return {status:'TREATMENT_AUTHORITY_REQUIRED',roles:[],rows:[]};
    const select='id,nombre,requiere_doctora,requiere_enfermeria,estado';
    const out=await serviceGet('/rest/v1/aos_catalogo_servicios?id=in.('+ids.map(encodeURIComponent).join(',')+')&select='+encodeURIComponent(select));
    const rows=asArray(out&&out.data);
    return Object.assign(roleFromRows(rows),{rows});
  }

  async function resolve(input){
    input=input||{};
    const runtime=input.runtime||{},state=runtime.state||{};
    const result={version:VERSION,status:'NOT_REQUESTED',target_date:null,site:null,required_roles:[],schedule_source_fresh:false,schedule_source_max_date:null,requested_time:clean(state.requested_time)||null,time_constraint:clean(state.time_constraint)||null,candidate_slots:[],candidate_slot_count:0,exact_requested_time_available:false,confirmation_allowed:false,write_boundary:'NO_GOVERNED_CANONICAL_BOOKING_WRITE',limitations:[]};
    const wantsBooking=runtime.booking_readiness==='HIGH'||asArray(runtime.intents).some(x=>['BOOKING','SCHEDULE','HARD_TIME_CONSTRAINT'].includes(String(x)));
    if(!wantsBooking){result.prompt_context=safePrompt(result);return result;}
    if(clean(state.requested_day).toUpperCase()==='DOMINGO'){
      result.status='CLOSED_DAY';result.limitations.push('SUNDAY_CLOSED');result.prompt_context=safePrompt(result);return result;
    }
    result.target_date=resolveRequestedDate(state.requested_day,input.now);
    if(!result.target_date){result.status='DATE_REQUIRED';result.prompt_context=safePrompt(result);return result;}
    result.site=siteDb(state.site||input.preferred_site);
    if(!result.site){result.status='SITE_REQUIRED';result.prompt_context=safePrompt(result);return result;}

    let role;
    try{role=await catalogRole(input.processContexts);}catch(_){role={status:'TREATMENT_AUTHORITY_UNAVAILABLE',roles:[]};}
    result.required_roles=role.roles||[];
    if(role.status!=='READY'){
      result.status=role.status;result.limitations.push(role.status);result.prompt_context=safePrompt(result);return result;
    }

    const dayNum=dbDayForIso(result.target_date);
    try{
      const hours=await serviceGet('/rest/v1/aos_config_horarios?sede=eq.'+encodeURIComponent(result.site)+'&dia_semana=eq.'+dayNum+'&select='+encodeURIComponent('sede,dia_semana,hora_apertura,hora_cierre,activo')+'&limit=2');
      const row=firstRow(hours);
      if(!row||row.activo!==true){result.status='CLOSED_DAY';result.limitations.push('SITE_CLOSED_FOR_REQUESTED_DATE');result.prompt_context=safePrompt(result);return result;}
    }catch(_){result.status='PUBLIC_HOURS_AUTHORITY_UNAVAILABLE';result.limitations.push('PUBLIC_HOURS_AUTHORITY_UNAVAILABLE');result.prompt_context=safePrompt(result);return result;}

    try{result.schedule_source_max_date=await latestScheduleDate();}
    catch(_){result.status='SCHEDULE_SOURCE_UNAVAILABLE';result.limitations.push('DATE_SPECIFIC_SCHEDULE_UNAVAILABLE');result.prompt_context=safePrompt(result);return result;}
    if(!result.schedule_source_max_date||result.schedule_source_max_date<result.target_date){
      result.status='SCHEDULE_SOURCE_STALE';
      result.limitations.push('DATE_SPECIFIC_SCHEDULE_STALE');
      result.prompt_context=safePrompt(result);return result;
    }
    result.schedule_source_fresh=true;

    let professionals=[];
    for(const roleName of result.required_roles){
      try{
        const select='id,nombre_publico,tipo,sede,visible';
        const out=await serviceGet('/rest/v1/aos_perfiles_profesional?visible=eq.true&tipo=eq.'+encodeURIComponent(roleName)+'&select='+encodeURIComponent(select));
        professionals=professionals.concat(asArray(out&&out.data));
      }catch(_){result.status='PROFESSIONAL_AUTHORITY_UNAVAILABLE';result.limitations.push('PROFESSIONAL_AUTHORITY_UNAVAILABLE');result.prompt_context=safePrompt(result);return result;}
    }
    professionals=professionals.filter(p=>{const s=norm(p&&p.sede);return !s||s==='TODAS'||s===norm(result.site);});
    if(!professionals.length){result.status='NO_ELIGIBLE_PROFESSIONAL';result.prompt_context=safePrompt(result);return result;}

    const candidates=[];
    for(const p of professionals.slice(0,8)){
      try{
        const data=rpcData(await serviceRpc('aos_slots_disponibles',{p_profesional_id:clean(p.id),p_fecha:result.target_date,p_sede:result.site}))||{};
        if(data.ok===true){for(const s of asArray(data.slots))candidates.push({professional_id:clean(p.id),professional_name:clean(p.nombre_publico),role:clean(p.tipo),hora:clean(s.hora),sede:clean(s.sede)||result.site,libres:Number(s.libres||0),capacidad:Number(s.capacidad||0),disponible:s.disponible!==false});}
      }catch(_){result.limitations.push('SLOT_RPC_PARTIAL_FAILURE');}
    }
    result.candidate_slots=rankSlots(candidates,result.requested_time).slice(0,12);
    result.candidate_slot_count=result.candidate_slots.length;
    result.exact_requested_time_available=Boolean(result.requested_time&&result.candidate_slots.some(x=>clean(x.hora).slice(0,5)===result.requested_time.slice(0,5)));
    result.status=result.candidate_slot_count?'REAL_SLOTS_READY':'NO_REAL_SLOTS';
    result.prompt_context=safePrompt(result);
    return result;
  }

  async function revalidateSlot(input){
    input=input||{};
    const targetDate=clean(input.target_date),professionalId=clean(input.professional_id),time=clean(input.time).slice(0,5),site=siteDb(input.site);
    if(!targetDate||!professionalId||!time)return {ok:false,status:'INVALID_REVALIDATION_INPUT',version:VERSION};
    let maxDate;
    try{maxDate=await latestScheduleDate();}catch(_){return {ok:false,status:'SCHEDULE_SOURCE_UNAVAILABLE',version:VERSION};}
    if(!maxDate||maxDate<targetDate)return {ok:false,status:'SCHEDULE_SOURCE_STALE',schedule_source_max_date:maxDate||null,version:VERSION};
    try{
      const data=rpcData(await serviceRpc('aos_slots_disponibles',{p_profesional_id:professionalId,p_fecha:targetDate,p_sede:site}))||{};
      const slot=asArray(data.slots).find(x=>clean(x&&x.hora).slice(0,5)===time&&x.disponible!==false);
      return {ok:Boolean(slot),status:slot?'REVALIDATED_AVAILABLE':'NO_LONGER_AVAILABLE',slot:slot||null,version:VERSION,confirmation_allowed:false,write_boundary:'NO_GOVERNED_CANONICAL_BOOKING_WRITE'};
    }catch(_){return {ok:false,status:'SLOT_REVALIDATION_UNAVAILABLE',version:VERSION};}
  }

  return {resolve,revalidateSlot,version:VERSION};
}

module.exports={VERSION,DAY_NUM,SITE_DB,createBookingResolver,limaDate,resolveRequestedDate,dbDayForIso,siteDb,roleFromRows,rankSlots,safePrompt};
