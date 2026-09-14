'use strict'

const VERSION='CONV-L4-BUSINESS-TOOLS-V1'

function text(v){return String(v==null?'':v).trim()}
function upper(v){return text(v).toUpperCase()}
function digits(v){return text(v).replace(/\D/g,'')}
function rows(v){return Array.isArray(v)?v:[]}
function object(v){return v&&typeof v==='object'&&!Array.isArray(v)?v:{}}
function encode(v){return encodeURIComponent(text(v))}
function site(v){return upper(v).replace(/_/g,' ').replace(/\s+/g,' ')}
function fail(error){return {ok:false,error}}

function limaDate(){
  try{
    return new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date())
  }catch(_){return new Date().toISOString().slice(0,10)}
}

function promotionIsCurrent(row,date){
  if(row.activa===false)return false
  const start=text(row.vigencia_inicio)
  const end=text(row.vigencia_fin)
  if(start&&start>date)return false
  if(end&&end<date)return false
  if(Number.isFinite(Number(row.max_usos))&&Number(row.max_usos)>0&&Number(row.usos_actuales||0)>=Number(row.max_usos))return false
  return true
}

function safePayment(row){
  return {
    name:text(row.nombre),
    currency:text(row.moneda)||null,
    type:text(row.tipo)||null,
    bank:text(row.banco)||null,
    account_type:text(row.tipo_cuenta)||null,
    site:text(row.sede)||null,
    sites:Array.isArray(row.sedes_aplica)?row.sedes_aplica.slice(0,8):[]
  }
}

function safePrice(row){
  return {
    entity_id:text(row.entity_id),
    entity_type:text(row.entity_type),
    name:text(row.entity_name),
    category:text(row.categoria)||null,
    base_price:row.precio_base==null?null:Number(row.precio_base),
    offer_price:row.precio_oferta==null?null:Number(row.precio_oferta),
    quote_price:row.quote_price==null?null:Number(row.quote_price),
    currency:text(row.moneda)||'PEN',
    price_state:text(row.price_state),
    freshness_state:text(row.freshness_state),
    evidence_ref:text(row.evidence_ref)||null
  }
}

function createBusinessToolHandlers(options){
  options=options||{}
  const rpc=options.rpc
  const rest=options.rest
  if(typeof rpc!=='function'||typeof rest!=='function')throw new Error('CONV_L4_BUSINESS_ADAPTERS_REQUIRED')

  return {
    async get_customer_context(input){
      const phone=digits(input.phone)
      if(phone.length<8)return fail('PHONE_REQUIRED')
      let r
      try{
        r=object(await rpc('aos_rev_resolve_patient_identity_v2',{p_lookup_type:'PHONE',p_lookup_value:phone}))
      }catch(_){
        return {
          identity_status:'IDENTITY_AUTHORITY_UNAVAILABLE',
          known_customer:false,
          candidate_count:0,
          requires_human:true,
          authority_available:false
        }
      }
      const status=upper(r.status||r.resolution_status||'UNRESOLVED')
      return {
        identity_status:status,
        known_customer:status==='MATCH'||status.includes('RESOLVED'),
        candidate_count:Number(r.candidate_count||0)||0,
        requires_human:/CONFLICT|REVIEW|AMBIG/.test(status),
        authority_available:true
      }
    },

    async get_prices(input){
      const query=text(input.query)
      if(query.length<2)return fail('PRICE_QUERY_REQUIRED')
      const path='/rest/v1/aos_wa4_price_authority_v1?select=entity_id,entity_type,entity_name,categoria,precio_base,precio_oferta,quote_price,price_state,freshness_state,ready_for_quote,evidence_ref,moneda&ready_for_quote=eq.true&entity_name=ilike.*'+encode(query)+'*&limit=5'
      const items=rows(await rest(path)).slice(0,5).map(safePrice)
      return {query,match_count:items.length,items,authoritative_empty:items.length===0}
    },

    async get_promotions(input){
      const date=limaDate()
      const query=upper(input.query)
      const items=rows(await rest('/rest/v1/aos_promociones?select=id,nombre,descripcion,tipo_descuento,valor_descuento,tratamientos,vigencia_inicio,vigencia_fin,codigo,max_usos,usos_actuales,activa&activa=eq.true&limit=25'))
        .filter(row=>promotionIsCurrent(row,date))
        .filter(row=>!query||upper([row.nombre,row.descripcion].concat(row.tratamientos||[]).join(' ')).includes(query))
        .slice(0,10)
        .map(row=>({
          name:text(row.nombre),
          description:text(row.descripcion)||null,
          discount_type:text(row.tipo_descuento)||null,
          discount_value:row.valor_descuento==null?null:Number(row.valor_descuento),
          treatments:Array.isArray(row.tratamientos)?row.tratamientos.slice(0,12):[],
          code:text(row.codigo)||null,
          valid_from:text(row.vigencia_inicio)||null,
          valid_to:text(row.vigencia_fin)||null
        }))
      return {as_of:date,match_count:items.length,items,authoritative_empty:items.length===0}
    },

    async get_locations_payment_methods(){
      const [locations,payments]=await Promise.all([
        rest('/rest/v1/aos_sedes_geo?select=nombre,direccion,telefono,maps_link,horario_lv,horario_finde,activa&activa=eq.true&order=nombre&limit=10'),
        rest('/rest/v1/aos_metodos_pago?select=nombre,moneda,activo,orden,sede,tipo,sedes_aplica,tipo_cuenta,banco&activo=eq.true&order=orden,nombre&limit=30')
      ])
      return {
        locations:rows(locations).slice(0,10).map(row=>({
          name:text(row.nombre),
          address:text(row.direccion)||null,
          phone:text(row.telefono)||null,
          maps_link:/^https:\/\//i.test(text(row.maps_link))?text(row.maps_link):null,
          weekday_hours:text(row.horario_lv)||null,
          weekend_hours:text(row.horario_finde)||null
        })),
        payment_methods:rows(payments).slice(0,30).map(safePayment)
      }
    },

    async get_availability(input){
      const treatment=text(input.treatment_id)
      const date=text(input.date)
      const location=site(input.site)
      if(!/^[0-9a-f-]{36}$/i.test(treatment))return fail('TREATMENT_ID_REQUIRED')
      if(!/^\d{4}-\d{2}-\d{2}$/.test(date))return fail('DATE_REQUIRED')
      if(!location)return fail('SITE_REQUIRED')
      return object(await rpc('aos_booking_availability_v2',{
        p_treatment_id:treatment,
        p_fecha:date,
        p_sede:location,
        p_profesional_id:text(input.professional_id)||null
      }))
    },

    async prepare_booking(input){
      const treatment=text(input.treatment_id)
      const date=text(input.date)
      const time=text(input.time).slice(0,5)
      const location=site(input.site)
      if(!/^[0-9a-f-]{36}$/i.test(treatment)||!/^\d{4}-\d{2}-\d{2}$/.test(date)||!/^\d{2}:\d{2}$/.test(time)||!location)return fail('BOOKING_FIELDS_REQUIRED')
      const slot=object(await rpc('aos_booking_resolve_selected_slot_v2',{
        p_treatment_id:treatment,
        p_date:date,
        p_site:location,
        p_time:time,
        p_professional_id:text(input.professional_id)||null,
        p_slot_role:text(input.slot_role)||null
      }))
      return {ready:slot.ok===true,requires_explicit_confirmation:slot.ok===true,slot}
    },

    async confirm_booking(){
      return {prepared:false,executed:false,error:'DEFERRED_TO_CONV_L5',requires_explicit_confirmation:true}
    },

    async get_media(){
      return {ok:false,error:'COMMERCIAL_MEDIA_ELIGIBILITY_NOT_CONFIGURED',items:[]}
    },

    async handoff(input){
      return {prepared:true,executed:false,reason:text(input.reason)||'customer_or_policy_handoff',deferred_to:'CONV-L5'}
    },

    async create_hot_lead_signal(input){
      const score=Math.max(1,Math.min(100,Number(input.score||80)))
      return {prepared:true,executed:false,reason:text(input.reason)||'buying_intent',score,deferred_to:'CONV-L6'}
    }
  }
}

async function searchKnowledge(rpc,query){
  query=text(query)
  if(query.length<3)return {ok:false,error:'KNOWLEDGE_QUERY_REQUIRED',items:[]}
  const raw=object(await rpc('aos_wa4a_knowledge_search_v3',{p_query:query,p_audience:'PUBLIC_CLIENT',p_limit:6,p_domains:null}))
  const source=Array.isArray(raw.items)?raw.items:Array.isArray(raw.results)?raw.results:[]
  return {
    ok:raw.ok!==false,
    items:source.slice(0,6).map(row=>({
      entity_type:text(row.entity_type||row.type)||null,
      entity_name:text(row.entity_name||row.name)||null,
      title:text(row.title)||null,
      text:text(row.text||row.content||row.answer).slice(0,900),
      evidence_ref:text(row.evidence_ref)||null
    }))
  }
}

module.exports={VERSION,createBusinessToolHandlers,searchKnowledge,promotionIsCurrent,safePayment,safePrice}
