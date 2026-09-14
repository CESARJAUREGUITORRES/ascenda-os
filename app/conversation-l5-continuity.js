'use strict'

const VERSION='CONV-L5-CONTINUITY-V1'
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
function text(v){return String(v==null?'':v).trim()}
function rows(v){return Array.isArray(v)?v:[]}
function safeUrl(v){v=text(v);return /^https:\/\//i.test(v)?v:null}
function site(v){return text(v).toUpperCase().replace(/_/g,' ').replace(/\s+/g,' ')}

function createL5Continuity(deps){
  deps=deps||{}
  const rpc=deps.rpc,rest=deps.rest,listTemplates=deps.listTemplates
  if(typeof rpc!=='function'||typeof rest!=='function'||typeof listTemplates!=='function')throw new Error('CONV_L5_ADAPTERS_REQUIRED')

  async function media(input){
    input=input||{}
    const treatment=text(input.treatment_id),query=text(input.query).toLowerCase()
    if(treatment&&!UUID_RE.test(treatment))return {ok:false,error:'MEDIA_TREATMENT_INVALID',items:[]}
    let path='/rest/v1/aos_conv_l5_media_catalog_v1?select=id,media_type,title,description,public_url,treatment_id,tags,sort_order&active=eq.true&approved_for_whatsapp=eq.true&order=sort_order,title&limit=20'
    if(treatment)path+='&treatment_id=eq.'+encodeURIComponent(treatment)
    const items=rows(await rest(path)).filter(r=>{
      if(!query)return true
      return [r.title,r.description].concat(r.tags||[]).join(' ').toLowerCase().includes(query)
    }).slice(0,6).map(r=>({id:text(r.id),type:text(r.media_type),title:text(r.title),description:text(r.description)||null,url:safeUrl(r.public_url)})).filter(r=>r.url)
    return {ok:true,items,match_count:items.length,authoritative_empty:items.length===0,send_eligible:false,requires_human_send:true}
  }

  async function templates(){
    const out=await listTemplates()
    const source=rows(out&&out.templates)
    const approved=source.filter(t=>text(t.status).toUpperCase()==='APPROVED').map(t=>({id:text(t.id)||null,name:text(t.name),language:text(t.language),category:text(t.category)}))
    return {ok:true,items:approved,count:approved.length,provider_count:source.length,send_eligible:false,requires_human_send:true}
  }

  async function prepareBooking(input,ctx){
    input=input||{};ctx=ctx||{}
    const cid=text(ctx.conversation_id||input.conversation_id),flow=text(input.flow||'BOOK').toUpperCase()
    if(!UUID_RE.test(cid))return {ok:false,error:'CONVERSATION_ID_REQUIRED'}
    if(!['BOOK','REBOOK'].includes(flow))return {ok:false,error:'BOOKING_FLOW_INVALID'}
    const treatment=text(input.treatment_id),location=site(input.site),date=text(input.date),time=text(input.time).slice(0,5)
    if(flow==='BOOK'&&!UUID_RE.test(treatment))return {ok:false,error:'TREATMENT_ID_REQUIRED'}
    if(!['SAN ISIDRO','PUEBLO LIBRE'].includes(location)||!/^\d{4}-\d{2}-\d{2}$/.test(date)||!/^\d{2}:\d{2}$/.test(time))return {ok:false,error:'BOOKING_FIELDS_REQUIRED'}
    const out=await rpc('aos_wa_l5_prepare_confirmation_v1',{
      p_conversation_id:cid,p_flow:flow,p_treatment_id:treatment||null,p_site:location,p_date:date,p_time:time,
      p_professional_id:text(input.professional_id)||null,p_slot_role:text(input.slot_role).toUpperCase()||null,
      p_appointment_id:text(input.appointment_id)||null,p_given_name:text(input.given_name)||null,p_family_name:text(input.family_name)||null,
      p_confirmation_ttl_seconds:Math.max(60,Math.min(Number(input.confirmation_ttl_seconds||600),1800))
    })
    return Object.assign({requires_explicit_confirmation:true,executed:false},out&&typeof out==='object'?out:{ok:false,error:'BOOKING_PREPARE_EMPTY'})
  }

  async function confirmBooking(input,ctx){
    input=input||{};ctx=ctx||{}
    const cid=text(ctx.conversation_id||input.conversation_id),nonce=text(input.confirmation_nonce),providerMessageId=text(input.provider_message_id)
    if(!UUID_RE.test(cid)||!UUID_RE.test(nonce)||providerMessageId.length<3)return {ok:false,error:'EXPLICIT_CONFIRMATION_PROOF_REQUIRED',executed:false}
    const marked=await rpc('aos_wa_l5_mark_explicit_confirmation_v1',{p_conversation_id:cid,p_confirmation_nonce:nonce,p_provider_message_id:providerMessageId})
    if(!marked||marked.ok!==true)return Object.assign({executed:false},marked||{ok:false,error:'CONFIRMATION_REJECTED'})
    return {ok:true,status:'CONFIRMED',executed:false,commit_deferred:true,commit_authority:'AOS_WA_L5_COMMIT_CONFIRMED_V1',requires_l4_authority:true}
  }

  async function handoff(input,ctx){
    const cid=text((ctx||{}).conversation_id||(input||{}).conversation_id)
    if(!UUID_RE.test(cid))return {ok:false,error:'CONVERSATION_ID_REQUIRED',executed:false}
    const out=await rpc('aos_wa3_handoff_request_v1',{p_conversation_id:cid,p_box_id:null,p_actor_id:null,p_reason:text((input||{}).reason).slice(0,160)||'conv_l5_handoff'})
    return Object.assign({executed:!!(out&&out.ok===true)},out||{ok:false,error:'HANDOFF_EMPTY'})
  }

  return {version:VERSION,media,templates,prepareBooking,confirmBooking,handoff}
}

module.exports={VERSION,createL5Continuity,UUID_RE}
