'use strict'

const https = require('https')
const crypto = require('crypto')

const VERSION = 'INT-GOOGLE-001-V1'
const OAUTH_SCOPES = [
  'openid',
  'email',
  'profile',
  'https://www.googleapis.com/auth/calendar.events',
  'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
  'https://www.googleapis.com/auth/contacts'
]

function clean(v){ return String(v == null ? '' : v).trim() }
function boolEnv(v){ return /^(1|true|yes|on)$/i.test(clean(v)) }
function validEmail(v){ return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(clean(v)) }
function digits(v){ return clean(v).replace(/\D/g,'') }
function sha(v){ return crypto.createHash('sha256').update(String(v)).digest('hex') }
function b64url(buf){ return Buffer.from(buf).toString('base64').replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_') }

function requestRaw(opts, body){
  return new Promise(function(resolve,reject){
    const req=https.request(opts,function(res){
      const chunks=[]
      res.on('data',function(c){chunks.push(Buffer.from(c))})
      res.on('end',function(){
        const raw=Buffer.concat(chunks).toString('utf8')
        resolve({status:res.statusCode||500,headers:res.headers,raw:raw})
      })
    })
    req.on('timeout',function(){req.destroy(new Error('UPSTREAM_TIMEOUT'))})
    req.on('error',reject)
    if(body)req.write(body)
    req.end()
  })
}
function parse(raw){ try{return raw?JSON.parse(raw):null}catch(_){return null} }

function createGoogleIntegration(config){
  config=config||{}
  const verifyConfig=config.verifyConfig
  const serviceRpc=config.serviceRpc
  const readRaw=config.readRaw
  const writeJson=config.writeJson
  const supabaseUrl=clean(config.supabaseUrl).replace(/\/$/,'')
  const serviceKey=clean(config.serviceRoleKey)
  const env=config.env||process.env
  const clientId=clean(env.GOOGLE_CLIENT_ID)
  const clientSecret=clean(env.GOOGLE_CLIENT_SECRET)
  const redirectUri=clean(env.GOOGLE_REDIRECT_URI)
  const encryptionSecret=clean(env.GOOGLE_TOKEN_ENCRYPTION_KEY)
  const contactTag=clean(env.GOOGLE_CONTACT_TAG)||'ZIVITAL'
  const timezone=clean(env.GOOGLE_TIMEZONE)||'America/Lima'
  let timer=null,busy=false
  const accessCache=new Map()

  function configured(){
    return !!(clientId&&clientSecret&&redirectUri&&encryptionSecret&&supabaseUrl&&serviceKey&&verifyConfig&&serviceRpc)
  }
  function flags(){
    return {
      integration:boolEnv(env.GOOGLE_INTEGRATION_ENABLED),
      calendar:boolEnv(env.GOOGLE_CALENDAR_SYNC_ENABLED),
      contacts:boolEnv(env.GOOGLE_CONTACT_SYNC_ENABLED)
    }
  }
  function key(){
    if(!encryptionSecret)throw new Error('GOOGLE_TOKEN_ENCRYPTION_KEY_REQUIRED')
    return crypto.createHash('sha256').update(encryptionSecret).digest()
  }
  function encryptToken(token){
    const iv=crypto.randomBytes(12)
    const cipher=crypto.createCipheriv('aes-256-gcm',key(),iv)
    const ciphertext=Buffer.concat([cipher.update(clean(token),'utf8'),cipher.final()])
    return {ciphertext:ciphertext.toString('base64'),iv:iv.toString('base64'),tag:cipher.getAuthTag().toString('base64')}
  }
  function decryptToken(row){
    const decipher=crypto.createDecipheriv('aes-256-gcm',key(),Buffer.from(row.token_iv,'base64'))
    decipher.setAuthTag(Buffer.from(row.token_tag,'base64'))
    return Buffer.concat([decipher.update(Buffer.from(row.refresh_token_ciphertext,'base64')),decipher.final()]).toString('utf8')
  }

  async function sb(method,path,body,prefer){
    if(!serviceKey)throw Object.assign(new Error('SUPABASE_SERVICE_ROLE_NOT_CONFIGURED'),{code:'SUPABASE_SERVICE_ROLE_NOT_CONFIGURED'})
    const u=new URL(supabaseUrl)
    let raw=null
    const headers={
      apikey:serviceKey,
      Authorization:'Bearer '+serviceKey,
      Accept:'application/json',
      'User-Agent':'AscendaOS-GoogleIntegration/1.0'
    }
    if(body!==undefined&&body!==null){
      raw=JSON.stringify(body)
      headers['Content-Type']='application/json'
      headers['Content-Length']=Buffer.byteLength(raw)
    }
    if(prefer)headers.Prefer=prefer
    const r=await requestRaw({hostname:u.hostname,port:u.port||443,path:path,method:method,headers:headers,timeout:7000},raw)
    if(r.status<200||r.status>=300){
      const e=new Error('SUPABASE_GOOGLE_STATE_UNAVAILABLE');e.status=503;e.upstreamStatus=r.status;throw e
    }
    return parse(r.raw)
  }

  async function tokenRequest(params){
    const body=new URLSearchParams(params).toString()
    const r=await requestRaw({
      hostname:'oauth2.googleapis.com',port:443,path:'/token',method:'POST',
      headers:{'Content-Type':'application/x-www-form-urlencoded','Content-Length':Buffer.byteLength(body),'User-Agent':'AscendaOS-GoogleIntegration/1.0'},
      timeout:8000
    },body)
    const data=parse(r.raw)||{}
    if(r.status<200||r.status>=300||!data.access_token){
      const e=new Error('GOOGLE_TOKEN_EXCHANGE_FAILED');e.code='GOOGLE_TOKEN_EXCHANGE_FAILED';e.upstreamStatus=r.status;throw e
    }
    return data
  }

  async function googleJson(method,url,accessToken,body){
    const u=new URL(url)
    let raw=null
    const headers={Authorization:'Bearer '+accessToken,Accept:'application/json','User-Agent':'AscendaOS-GoogleIntegration/1.0'}
    if(body!==undefined&&body!==null){
      raw=JSON.stringify(body);headers['Content-Type']='application/json';headers['Content-Length']=Buffer.byteLength(raw)
    }
    const r=await requestRaw({hostname:u.hostname,port:u.port||443,path:u.pathname+u.search,method:method,headers:headers,timeout:9000},raw)
    const data=parse(r.raw)
    if(r.status<200||r.status>=300){
      const e=new Error('GOOGLE_API_UNAVAILABLE');e.code='GOOGLE_API_UNAVAILABLE';e.upstreamStatus=r.status;e.googleCode=data&&data.error&&data.error.code;throw e
    }
    return data
  }

  async function activeConnection(){
    const rows=await sb('GET','/rest/v1/aos_google_connections_v1?status=eq.CONNECTED&select=*&order=connected_at.desc&limit=1')
    return Array.isArray(rows)&&rows[0]?rows[0]:null
  }
  async function connectionAccess(row){
    const cached=accessCache.get(row.id)
    if(cached&&cached.expiresAt>Date.now()+60000)return cached.token
    const refresh=decryptToken(row)
    const t=await tokenRequest({client_id:clientId,client_secret:clientSecret,refresh_token:refresh,grant_type:'refresh_token'})
    accessCache.set(row.id,{token:t.access_token,expiresAt:Date.now()+Math.max(60,Number(t.expires_in||3600))*1000})
    return t.access_token
  }
  async function configActor(req,strong){
    const token=clean(req.headers['x-aos-app-token']||req.headers['x-ascenda-session'])
    const a=await verifyConfig(token,strong===true)
    if(!a||!a.ok)throw Object.assign(new Error('GOOGLE_CONFIG_AUTH_REQUIRED'),{status:a&&a.status||403,code:'GOOGLE_CONFIG_AUTH_REQUIRED'})
    return a
  }
  async function rawBody(req,max){
    const raw=await readRaw(req,max||32768)
    const body=parse(raw.toString('utf8'))
    if(!body)throw Object.assign(new Error('INVALID_JSON'),{status:400,code:'INVALID_JSON'})
    return body
  }
  function safeError(e){
    return {ok:false,error:e&&e.code||e&&e.message||'GOOGLE_INTEGRATION_ERROR',upstream_status:e&&e.upstreamStatus||undefined}
  }

  async function oauthStart(req,res){
    if(!configured())return writeJson(res,503,{ok:false,error:'GOOGLE_INTEGRATION_NOT_CONFIGURED'})
    let actor;try{actor=await configActor(req,true)}catch(e){return writeJson(res,e.status||403,safeError(e))}
    const state=b64url(crypto.randomBytes(32))
    const stateHash=sha(state)
    const expires=new Date(Date.now()+10*60*1000).toISOString()
    try{
      await sb('POST','/rest/v1/aos_google_oauth_states_v1',{state_hash:stateHash,actor_id:actor.actor_id,expires_at:expires},'return=minimal')
      const u=new URL('https://accounts.google.com/o/oauth2/v2/auth')
      u.searchParams.set('client_id',clientId)
      u.searchParams.set('redirect_uri',redirectUri)
      u.searchParams.set('response_type','code')
      u.searchParams.set('access_type','offline')
      u.searchParams.set('prompt','consent')
      u.searchParams.set('include_granted_scopes','true')
      u.searchParams.set('scope',OAUTH_SCOPES.join(' '))
      u.searchParams.set('state',state)
      return writeJson(res,200,{ok:true,version:VERSION,auth_url:u.toString(),expires_in:600})
    }catch(e){return writeJson(res,e.status||503,safeError(e))}
  }

  function callbackHtml(res,ok,code){
    const msg=ok?'Google conectado correctamente. Puedes cerrar esta ventana.':'No se pudo completar la conexión de Google.'
    const safeCode=clean(code).replace(/[^A-Z0-9_\-]/gi,'').slice(0,80)
    res.writeHead(ok?200:400,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'"})
    res.end('<!doctype html><meta charset="utf-8"><title>ASCENDA Google</title><body style="font-family:system-ui;padding:40px;background:#f8fafc;color:#0f172a"><h2>'+msg+'</h2><p>'+safeCode+'</p><script>try{window.opener&&window.opener.postMessage({type:"ASCENDA_GOOGLE_OAUTH",ok:'+String(ok)+',code:"'+safeCode+'"},location.origin)}catch(e){}</script></body>')
  }

  async function oauthCallback(req,res,url){
    if(!configured())return callbackHtml(res,false,'GOOGLE_INTEGRATION_NOT_CONFIGURED')
    const state=clean(url.searchParams.get('state')),code=clean(url.searchParams.get('code'))
    if(!state||!code)return callbackHtml(res,false,'GOOGLE_OAUTH_CODE_STATE_REQUIRED')
    try{
      const stateHash=sha(state)
      const rows=await sb('GET','/rest/v1/aos_google_oauth_states_v1?state_hash=eq.'+encodeURIComponent(stateHash)+'&used_at=is.null&select=*&limit=1')
      const row=Array.isArray(rows)&&rows[0]?rows[0]:null
      if(!row||new Date(row.expires_at).getTime()<Date.now())return callbackHtml(res,false,'GOOGLE_OAUTH_STATE_EXPIRED')
      const consumed=await sb('PATCH','/rest/v1/aos_google_oauth_states_v1?state_hash=eq.'+encodeURIComponent(stateHash)+'&used_at=is.null',{used_at:new Date().toISOString()},'return=representation')
      if(!Array.isArray(consumed)||consumed.length!==1)return callbackHtml(res,false,'GOOGLE_OAUTH_STATE_REPLAY')

      const t=await tokenRequest({client_id:clientId,client_secret:clientSecret,code:code,redirect_uri:redirectUri,grant_type:'authorization_code'})
      if(!t.refresh_token)return callbackHtml(res,false,'GOOGLE_REFRESH_TOKEN_REQUIRED')
      const info=await googleJson('GET','https://openidconnect.googleapis.com/v1/userinfo',t.access_token)
      if(!info||!info.sub||!validEmail(info.email))return callbackHtml(res,false,'GOOGLE_ACCOUNT_IDENTITY_INVALID')
      const enc=encryptToken(t.refresh_token)
      await sb('PATCH','/rest/v1/aos_google_connections_v1?status=eq.CONNECTED',{status:'DISCONNECTED',disconnected_at:new Date().toISOString(),updated_at:new Date().toISOString()},'return=minimal')
      const inserted=await sb('POST','/rest/v1/aos_google_connections_v1',{
        tenant_key:'ZIVITAL',owner_actor_id:row.actor_id,provider_account_id:String(info.sub),
        account_email:String(info.email).toLowerCase(),refresh_token_ciphertext:enc.ciphertext,token_iv:enc.iv,token_tag:enc.tag,
        token_expires_at:t.expires_in?new Date(Date.now()+Number(t.expires_in)*1000).toISOString():null,
        granted_scopes:clean(t.scope).split(/\s+/).filter(Boolean),calendar_id:'primary',calendar_summary:'Principal',
        status:'CONNECTED',last_verified_at:new Date().toISOString()
      },'return=representation')
      const conn=Array.isArray(inserted)&&inserted[0]?inserted[0]:null
      if(conn)accessCache.set(conn.id,{token:t.access_token,expiresAt:Date.now()+Math.max(60,Number(t.expires_in||3600))*1000})
      await sb('PATCH','/rest/v1/aos_integraciones?tipo=eq.google',{estado:'conectado',cuenta:String(info.email).toLowerCase()},'return=minimal')
      return callbackHtml(res,true,'CONNECTED')
    }catch(e){return callbackHtml(res,false,e.code||'GOOGLE_OAUTH_FAILED')}
  }

  async function status(req,res){
    try{
      await configActor(req,false)
      const conn=await activeConnection()
      let audit=null
      try{audit=await serviceRpc('aos_google_integration_audit_v1',{})}catch(_){}
      return writeJson(res,200,{
        ok:true,version:VERSION,configured:configured(),flags:flags(),
        connection:conn?{
          connected:true,account_email:conn.account_email,calendar_id:conn.calendar_id,
          calendar_summary:conn.calendar_summary,status:conn.status,connected_at:conn.connected_at,last_verified_at:conn.last_verified_at
        }:{connected:false,status:'DISCONNECTED'},
        audit:audit||null
      })
    }catch(e){return writeJson(res,e.status||503,safeError(e))}
  }

  async function calendars(req,res){
    try{
      await configActor(req,true)
      const conn=await activeConnection()
      if(!conn)return writeJson(res,409,{ok:false,error:'GOOGLE_NOT_CONNECTED'})
      const access=await connectionAccess(conn)
      const data=await googleJson('GET','https://www.googleapis.com/calendar/v3/users/me/calendarList?minAccessRole=writer&showHidden=false&maxResults=100',access)
      const items=(data&&data.items||[]).map(function(x){return {id:x.id,summary:x.summary||'',primary:x.primary===true,access_role:x.accessRole||''}})
      return writeJson(res,200,{ok:true,items:items,selected:conn.calendar_id})
    }catch(e){return writeJson(res,e.status||503,safeError(e))}
  }

  async function selectCalendar(req,res){
    try{
      await configActor(req,true)
      const body=await rawBody(req,16384)
      const calendarId=clean(body.calendar_id)
      if(!calendarId||calendarId.length>500)return writeJson(res,400,{ok:false,error:'GOOGLE_CALENDAR_ID_REQUIRED'})
      const conn=await activeConnection()
      if(!conn)return writeJson(res,409,{ok:false,error:'GOOGLE_NOT_CONNECTED'})
      const access=await connectionAccess(conn)
      const cal=await googleJson('GET','https://www.googleapis.com/calendar/v3/calendars/'+encodeURIComponent(calendarId),access)
      await sb('PATCH','/rest/v1/aos_google_connections_v1?id=eq.'+encodeURIComponent(conn.id),{
        calendar_id:calendarId,calendar_summary:clean(cal&&cal.summary)||calendarId,last_verified_at:new Date().toISOString(),updated_at:new Date().toISOString(),last_error_code:null
      },'return=minimal')
      return writeJson(res,200,{ok:true,calendar_id:calendarId,calendar_summary:clean(cal&&cal.summary)||calendarId})
    }catch(e){return writeJson(res,e.status||503,safeError(e))}
  }

  async function disconnect(req,res){
    try{
      await configActor(req,true)
      const conn=await activeConnection()
      if(!conn)return writeJson(res,200,{ok:true,already_disconnected:true})
      try{
        const token=decryptToken(conn)
        const body='token='+encodeURIComponent(token)
        await requestRaw({hostname:'oauth2.googleapis.com',port:443,path:'/revoke',method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','Content-Length':Buffer.byteLength(body)},timeout:6000},body)
      }catch(_){}
      await sb('PATCH','/rest/v1/aos_google_connections_v1?id=eq.'+encodeURIComponent(conn.id),{
        status:'DISCONNECTED',disconnected_at:new Date().toISOString(),updated_at:new Date().toISOString()
      },'return=minimal')
      await sb('PATCH','/rest/v1/aos_integraciones?tipo=eq.google',{estado:'pendiente',cuenta:''},'return=minimal')
      accessCache.delete(conn.id)
      return writeJson(res,200,{ok:true,status:'DISCONNECTED'})
    }catch(e){return writeJson(res,e.status||503,safeError(e))}
  }

  async function appointment(id){
    const rows=await sb('GET','/rest/v1/aos_agenda_citas?id=eq.'+encodeURIComponent(id)+'&select=*&limit=1')
    return Array.isArray(rows)&&rows[0]?rows[0]:null
  }
  async function agendaEvent(id){
    const rows=await sb('GET','/rest/v1/aos_agenda_events_v2?appointment_id=eq.'+encodeURIComponent(id)+'&select=id,after_snapshot,created_at&order=created_at.desc&limit=1')
    return Array.isArray(rows)&&rows[0]?rows[0]:null
  }
  async function durationMinutes(appt){
    const e=await agendaEvent(appt.id)
    let treatmentId=e&&e.after_snapshot&&e.after_snapshot.treatment_id
    if(!treatmentId&&appt.tratamiento){
      const rows=await sb('GET','/rest/v1/aos_catalogo_servicios?nombre=eq.'+encodeURIComponent(appt.tratamiento)+'&estado=eq.ACTIVO&select=id&limit=2')
      if(Array.isArray(rows)&&rows.length===1)treatmentId=rows[0].id
    }
    if(!treatmentId)throw Object.assign(new Error('GOOGLE_TREATMENT_AUTHORITY_UNRESOLVED'),{code:'GOOGLE_TREATMENT_AUTHORITY_UNRESOLVED'})
    const t=await serviceRpc('aos_booking_timing_for_service_v2',{p_treatment_id:treatmentId})
    const n=Number(t&&t.execution_default_min)
    if(!Number.isFinite(n)||n<15||n>240)throw Object.assign(new Error('GOOGLE_DURATION_AUTHORITY_UNRESOLVED'),{code:'GOOGLE_DURATION_AUTHORITY_UNRESOLVED'})
    return n
  }
  function localIso(date,time){
    const d=clean(date),t=(clean(time)||'09:00').slice(0,5)
    if(!/^\d{4}-\d{2}-\d{2}$/.test(d)||!/^\d{2}:\d{2}$/.test(t))throw Object.assign(new Error('GOOGLE_APPOINTMENT_DATE_TIME_INVALID'),{code:'GOOGLE_APPOINTMENT_DATE_TIME_INVALID'})
    return d+'T'+t+':00'
  }
  function plusMinutes(local,minutes){
    const m=/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):00$/.exec(local)
    if(!m)return local
    const d=new Date(Date.UTC(+m[1],+m[2]-1,+m[3],+m[4],+m[5]+minutes,0))
    return d.toISOString().slice(0,19)
  }

  async function calendarLink(id){
    const rows=await sb('GET','/rest/v1/aos_google_calendar_links_v1?appointment_id=eq.'+encodeURIComponent(id)+'&select=*&limit=1')
    return Array.isArray(rows)&&rows[0]?rows[0]:null
  }
  async function upsertCalendar(conn,appointmentId,revision){
    const appt=await appointment(appointmentId)
    if(!appt)throw Object.assign(new Error('GOOGLE_APPOINTMENT_NOT_FOUND'),{code:'GOOGLE_APPOINTMENT_NOT_FOUND'})
    if(upperStatus(appt.estado_cita)==='CANCELADA')return deleteCalendar(conn,appointmentId)
    const access=await connectionAccess(conn)
    const calendarId=clean(conn.calendar_id)||'primary'
    const start=localIso(appt.fecha_cita,appt.hora_cita)
    const mins=await durationMinutes(appt)
    const body={
      summary:'Cita ASCENDA',
      location:clean(appt.sede),
      start:{dateTime:start,timeZone:timezone},
      end:{dateTime:plusMinutes(start,mins),timeZone:timezone},
      extendedProperties:{private:{ascenda_appointment_id:String(appt.id),ascenda_revision:clean(revision)||clean(appt.ts_actualizado)||'current',ascenda_tenant:'ZIVITAL'}},
      reminders:{useDefault:true}
    }
    if(validEmail(appt.correo))body.attendees=[{email:clean(appt.correo).toLowerCase()}]
    const link=await calendarLink(appointmentId)
    let event
    if(link&&link.google_event_id&&link.state!=='DELETED'){
      event=await googleJson('PATCH','https://www.googleapis.com/calendar/v3/calendars/'+encodeURIComponent(calendarId)+'/events/'+encodeURIComponent(link.google_event_id)+'?sendUpdates=none',access,body)
    }else{
      event=await googleJson('POST','https://www.googleapis.com/calendar/v3/calendars/'+encodeURIComponent(calendarId)+'/events?sendUpdates=none',access,body)
    }
    if(!event||!event.id)throw Object.assign(new Error('GOOGLE_CALENDAR_EVENT_ID_MISSING'),{code:'GOOGLE_CALENDAR_EVENT_ID_MISSING'})
    await sb('POST','/rest/v1/aos_google_calendar_links_v1',{
      appointment_id:String(appt.id),connection_id:conn.id,calendar_id:calendarId,google_event_id:event.id,html_link:clean(event.htmlLink)||null,
      schedule_revision:clean(revision)||clean(appt.ts_actualizado)||'current',etag:clean(event.etag)||null,state:'ACTIVE',
      last_synced_at:new Date().toISOString(),updated_at:new Date().toISOString()
    },'resolution=merge-duplicates,return=minimal')
    await sb('PATCH','/rest/v1/aos_agenda_citas?id=eq.'+encodeURIComponent(appt.id),{gcal_event_id:event.id},'return=minimal')
    return {ok:true,operation:'CALENDAR_UPSERT',appointment_id:String(appt.id),google_event_id:event.id,html_link:clean(event.htmlLink)||null}
  }
  function upperStatus(v){return clean(v).toUpperCase()}

  async function deleteCalendar(conn,appointmentId){
    const link=await calendarLink(appointmentId)
    if(!link||!link.google_event_id)return {ok:true,operation:'CALENDAR_DELETE',appointment_id:String(appointmentId),already_absent:true}
    const access=await connectionAccess(conn)
    const u=new URL('https://www.googleapis.com/calendar/v3/calendars/'+encodeURIComponent(link.calendar_id||conn.calendar_id||'primary')+'/events/'+encodeURIComponent(link.google_event_id))
    u.searchParams.set('sendUpdates','none')
    const r=await requestRaw({hostname:u.hostname,port:443,path:u.pathname+u.search,method:'DELETE',headers:{Authorization:'Bearer '+access,'User-Agent':'AscendaOS-GoogleIntegration/1.0'},timeout:8000})
    if(r.status!==404&&(r.status<200||r.status>=300)){const e=new Error('GOOGLE_CALENDAR_DELETE_FAILED');e.code='GOOGLE_CALENDAR_DELETE_FAILED';e.upstreamStatus=r.status;throw e}
    await sb('PATCH','/rest/v1/aos_google_calendar_links_v1?appointment_id=eq.'+encodeURIComponent(appointmentId),{state:'DELETED',last_synced_at:new Date().toISOString(),updated_at:new Date().toISOString()},'return=minimal')
    await sb('PATCH','/rest/v1/aos_agenda_citas?id=eq.'+encodeURIComponent(appointmentId),{gcal_event_id:null},'return=minimal')
    return {ok:true,operation:'CALENDAR_DELETE',appointment_id:String(appointmentId),google_event_id:link.google_event_id}
  }

  function patientFields(p){
    return {
      id:clean(p.ID_PACIENTE),
      first:clean(p.Nombres),
      last:clean(p.Apellidos),
      phone:digits(p.numero_limpio||p['Teléfono']),
      email:clean(p.Email).toLowerCase()
    }
  }
  async function resolvePatient(appt){
    const phone=digits(appt.numero_limpio||appt.numero)
    const email=clean(appt.correo).toLowerCase()
    let byPhone=[],byEmail=[]
    if(phone.length>=7)byPhone=await sb('GET','/rest/v1/aos_pacientes?numero_limpio=eq.'+encodeURIComponent(phone)+'&select=*&limit=3')
    if(validEmail(email))byEmail=await sb('GET','/rest/v1/aos_pacientes?Email=eq.'+encodeURIComponent(email)+'&select=*&limit=3')
    const pRows=Array.isArray(byPhone)?byPhone:[],eRows=Array.isArray(byEmail)?byEmail:[]
    if(pRows.length>1||eRows.length>1)return {ok:false,review:true,reason:'PATIENT_IDENTITY_AMBIGUOUS'}
    const p=pRows[0]||eRows[0]
    if(!p)return {ok:false,review:true,reason:'PATIENT_IDENTITY_NOT_RESOLVED'}
    if(pRows[0]&&eRows[0]&&clean(pRows[0].ID_PACIENTE)!==clean(eRows[0].ID_PACIENTE))return {ok:false,review:true,reason:'PATIENT_IDENTITY_CONFLICT'}
    const f=patientFields(p)
    if(!f.id)return {ok:false,review:true,reason:'PATIENT_CANONICAL_ID_MISSING'}
    return {ok:true,patient:f}
  }
  function contactName(p){
    const now=new Date()
    const month=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.getUTCMonth()]
    return [p.first,p.last].filter(Boolean).join(' ')+' - '+contactTag+' - '+month+String(now.getUTCFullYear()).slice(-2)
  }
  function fingerprint(p){return sha([p.id,p.phone,p.email,p.first,p.last].join('|'))}
  async function contactLink(patientRef){
    const rows=await sb('GET','/rest/v1/aos_google_contact_links_v1?patient_ref=eq.'+encodeURIComponent(patientRef)+'&select=*&limit=1')
    return Array.isArray(rows)&&rows[0]?rows[0]:null
  }
  function personMatches(person,p){
    const emails=(person.emailAddresses||[]).map(x=>clean(x.value).toLowerCase()).filter(Boolean)
    const phones=(person.phoneNumbers||[]).map(x=>digits(x.value)).filter(Boolean)
    return (p.email&&emails.includes(p.email))||(p.phone&&phones.includes(p.phone))
  }
  async function searchContact(access,p){
    const q=p.email||p.phone
    if(!q)return []
    const data=await googleJson('GET','https://people.googleapis.com/v1/people:searchContacts?query='+encodeURIComponent(q)+'&readMask=names,emailAddresses,phoneNumbers,userDefined&pageSize=10',access)
    return (data&&data.results||[]).map(x=>x.person).filter(Boolean).filter(x=>personMatches(x,p))
  }
  async function upsertContact(conn,appointmentId){
    const appt=await appointment(appointmentId)
    if(!appt)throw Object.assign(new Error('GOOGLE_APPOINTMENT_NOT_FOUND'),{code:'GOOGLE_APPOINTMENT_NOT_FOUND'})
    const resolved=await resolvePatient(appt)
    if(!resolved.ok)return {ok:false,review:true,error:resolved.reason,operation:'CONTACT_UPSERT',appointment_id:String(appointmentId)}
    const p=resolved.patient,fp=fingerprint(p),access=await connectionAccess(conn)
    let link=await contactLink(p.id),resource=link&&link.resource_name,existing=null
    if(resource){
      try{existing=await googleJson('GET','https://people.googleapis.com/v1/'+encodeURI(resource)+'?personFields=names,emailAddresses,phoneNumbers,userDefined',access)}catch(e){if(e.upstreamStatus!==404)throw e;resource=null}
    }
    if(!resource){
      const matches=await searchContact(access,p)
      if(matches.length>1)return {ok:false,review:true,error:'GOOGLE_CONTACT_EXACT_MATCH_CONFLICT',operation:'CONTACT_UPSERT',patient_ref:p.id}
      if(matches.length===1){existing=matches[0];resource=existing.resourceName}
    }
    const person={
      names:[{givenName:contactName(p),familyName:''}],
      emailAddresses:p.email?[{value:p.email,type:'other'}]:[],
      phoneNumbers:p.phone?[{value:p.phone,type:'mobile'}]:[],
      userDefined:[{key:'ASCENDA_ID',value:p.id}]
    }
    let saved
    if(resource){
      if(existing&&existing.etag)person.etag=existing.etag
      saved=await googleJson('PATCH','https://people.googleapis.com/v1/'+encodeURI(resource)+':updateContact?updatePersonFields=names,emailAddresses,phoneNumbers,userDefined',access,person)
    }else{
      saved=await googleJson('POST','https://people.googleapis.com/v1/people:createContact',access,person)
    }
    if(!saved||!saved.resourceName)throw Object.assign(new Error('GOOGLE_CONTACT_RESOURCE_MISSING'),{code:'GOOGLE_CONTACT_RESOURCE_MISSING'})
    await sb('POST','/rest/v1/aos_google_contact_links_v1',{
      patient_ref:p.id,connection_id:conn.id,resource_name:saved.resourceName,etag:clean(saved.etag)||null,
      source_fingerprint:fp,state:'ACTIVE',conflict_reason:null,last_synced_at:new Date().toISOString(),updated_at:new Date().toISOString()
    },'resolution=merge-duplicates,return=minimal')
    return {ok:true,operation:'CONTACT_UPSERT',patient_ref:p.id,resource_name:saved.resourceName}
  }

  async function markOutbox(id,state,fields){
    const body=Object.assign({state:state,updated_at:new Date().toISOString()},fields||{})
    await sb('PATCH','/rest/v1/aos_google_sync_outbox_v1?id=eq.'+encodeURIComponent(id),body,'return=minimal')
  }
  async function processOutbox(){
    if(busy)return {busy:true}
    const f=flags()
    if(!configured()||!f.integration||(!f.calendar&&!f.contacts))return {skipped:true}
    busy=true
    try{
      const conn=await activeConnection()
      if(!conn)return {skipped:true,reason:'GOOGLE_NOT_CONNECTED'}
      const claimed=await serviceRpc('aos_google_sync_claim_v1',{p_limit:5,p_calendar:f.calendar,p_contacts:f.contacts})
      const rows=claimed&&Array.isArray(claimed.items)?claimed.items:[]
      let done=0,failed=0,review=0
      for(const row of rows){
        try{
          let result
          if(row.operation==='CALENDAR_UPSERT')result=await upsertCalendar(conn,row.entity_ref,row.source_revision)
          else if(row.operation==='CALENDAR_DELETE')result=await deleteCalendar(conn,row.entity_ref)
          else if(row.operation==='CONTACT_UPSERT')result=await upsertContact(conn,row.entity_ref)
          else result={ok:false,review:true,error:'GOOGLE_OPERATION_UNSUPPORTED'}
          if(result&&result.review){review++;await markOutbox(row.id,'REVIEW',{last_error_code:clean(result.error)||'GOOGLE_REVIEW_REQUIRED',lease_until:null})}
          else if(result&&result.ok){done++;await markOutbox(row.id,'DONE',{provider_ref:clean(result.google_event_id||result.resource_name)||null,last_error_code:null,lease_until:null,completed_at:new Date().toISOString()})}
          else {failed++;await markOutbox(row.id,'FAILED',{last_error_code:'GOOGLE_SYNC_FAILED',lease_until:null,available_at:new Date(Date.now()+60000).toISOString()})}
        }catch(e){
          failed++;await markOutbox(row.id,'FAILED',{last_error_code:clean(e.code)||'GOOGLE_SYNC_FAILED',lease_until:null,available_at:new Date(Date.now()+Math.min(15,Number(row.attempt_count||0)+1)*60000).toISOString()})
        }
      }
      return {ok:true,scanned:rows.length,done:done,failed:failed,review:review}
    }finally{busy=false}
  }
  function schedule(delay){
    if(timer)clearTimeout(timer)
    timer=setTimeout(function tick(){timer=null;processOutbox().finally(function(){schedule(30000)})},Math.max(5000,delay||30000))
    if(timer.unref)timer.unref()
  }
  function startWorker(){ if(!timer)schedule(10000) }
  function stopWorker(){ if(timer)clearTimeout(timer);timer=null }

  async function canaryCandidates(req,res){
    try{
      await configActor(req,true)
      const today=new Date(Date.now()-5*60*60*1000).toISOString().slice(0,10)
      const rows=await sb('GET','/rest/v1/aos_agenda_citas?fecha_cita=gte.'+encodeURIComponent(today)+'&estado_cita=in.(PENDIENTE,CITA%20CONFIRMADA)&select=id,fecha_cita,hora_cita,sede,tratamiento,nombre,apellido,correo,gcal_event_id&order=fecha_cita.asc,hora_cita.asc&limit=20')
      const items=(Array.isArray(rows)?rows:[]).map(function(x){
        return {
          id:x.id,date:x.fecha_cita,time:clean(x.hora_cita).slice(0,5),site:x.sede||'',
          treatment:x.tratamiento||'',display_name:[x.nombre,x.apellido].filter(Boolean).join(' '),
          has_email:validEmail(x.correo),calendar_linked:!!clean(x.gcal_event_id)
        }
      })
      return writeJson(res,200,{ok:true,items:items})
    }catch(e){return writeJson(res,e.status||503,safeError(e))}
  }

  async function canary(req,res){
    try{
      await configActor(req,true)
      const body=await rawBody(req,16384)
      if(clean(body.confirm)!=='GOOGLE_CANARY')return writeJson(res,400,{ok:false,error:'GOOGLE_CANARY_CONFIRM_REQUIRED'})
      const id=clean(body.appointment_id)
      if(!id)return writeJson(res,400,{ok:false,error:'GOOGLE_CANARY_APPOINTMENT_REQUIRED'})
      const conn=await activeConnection()
      if(!conn)return writeJson(res,409,{ok:false,error:'GOOGLE_NOT_CONNECTED'})
      const calendar=await upsertCalendar(conn,id,'canary:'+Date.now())
      let contact=null
      if(body.include_contact===true)contact=await upsertContact(conn,id)
      return writeJson(res,200,{ok:true,version:VERSION,calendar:calendar,contact:contact,flags_unchanged:flags()})
    }catch(e){return writeJson(res,e.status||503,safeError(e))}
  }

  async function backfill(req,res){
    try{
      await configActor(req,true)
      const body=await rawBody(req,16384)
      if(clean(body.confirm)!=='GOOGLE_BACKFILL')return writeJson(res,400,{ok:false,error:'GOOGLE_BACKFILL_CONFIRM_REQUIRED'})
      const limit=Math.max(1,Math.min(2000,Number(body.limit||500)))
      const result=await serviceRpc('aos_google_future_backfill_v1',{p_limit:limit})
      return writeJson(res,200,result||{ok:true})
    }catch(e){return writeJson(res,e.status||503,safeError(e))}
  }

  async function handle(req,res,url){
    if(url.pathname==='/api/google/oauth/callback'&&req.method==='GET'){await oauthCallback(req,res,url);return true}
    if(url.pathname==='/api/google/status'&&req.method==='GET'){await status(req,res);return true}
    if(url.pathname==='/api/google/oauth/start'&&req.method==='POST'){await oauthStart(req,res);return true}
    if(url.pathname==='/api/google/calendars'&&req.method==='GET'){await calendars(req,res);return true}
    if(url.pathname==='/api/google/calendar/select'&&req.method==='POST'){await selectCalendar(req,res);return true}
    if(url.pathname==='/api/google/disconnect'&&req.method==='POST'){await disconnect(req,res);return true}
    if(url.pathname==='/api/google/canary/candidates'&&req.method==='GET'){await canaryCandidates(req,res);return true}
    if(url.pathname==='/api/google/canary'&&req.method==='POST'){await canary(req,res);return true}
    if(url.pathname==='/api/google/backfill'&&req.method==='POST'){await backfill(req,res);return true}
    return false
  }

  return {
    version:VERSION,configured:configured,flags:flags,handle:handle,startWorker:startWorker,stopWorker:stopWorker,
    processOutbox:processOutbox,upsertCalendar:upsertCalendar,deleteCalendar:deleteCalendar,upsertContact:upsertContact,
    encryptToken:encryptToken,decryptToken:decryptToken
  }
}

module.exports={VERSION,OAUTH_SCOPES,createGoogleIntegration}
