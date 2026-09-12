'use strict'

const crypto = require('crypto')
const https = require('https')

function createGoogleIntegrationV1(opts) {
  opts = opts || {}
  const verifyApp = opts.verifyApp
  const SB_URL = String(opts.supabaseUrl || process.env.SUPABASE_URL || 'https://ituyqwstonmhnfshnaqz.supabase.co').replace(/\/+$/,'')
  const SERVICE_KEY = String(opts.serviceRoleKey || process.env.SUPABASE_SERVICE_ROLE_KEY || '')
  const CLIENT_ID = () => String(process.env.GOOGLE_CLIENT_ID || '')
  const CLIENT_SECRET = () => String(process.env.GOOGLE_CLIENT_SECRET || '')
  const REDIRECT_URI = () => String(process.env.GOOGLE_REDIRECT_URI || '')
  const MASTER_ON = () => String(process.env.GOOGLE_INTEGRATION_ENABLED || '').toLowerCase() === 'true'
  const CAL_ON = () => String(process.env.GOOGLE_CALENDAR_SYNC_ENABLED || '').toLowerCase() === 'true'
  const CONTACT_ON = () => String(process.env.GOOGLE_CONTACT_SYNC_ENABLED || '').toLowerCase() === 'true'
  const SCOPES = [
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
    'https://www.googleapis.com/auth/calendar.events.owned',
    'https://www.googleapis.com/auth/contacts'
  ]
  const workerId = 'google-v1-' + process.pid
  const warmedContactSearch = new Set()

  function json(res, status, body) {
    res.writeHead(status, {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'})
    res.end(JSON.stringify(body))
  }

  function html(res, status, body) {
    res.writeHead(status, {'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'})
    res.end(body)
  }

  function redirect(res, location) {
    res.writeHead(302, {'Location':location,'Cache-Control':'no-store'})
    res.end()
  }

  function request(hostname, path, method, headers, body) {
    return new Promise(function(resolve) {
      var payload = body == null ? null : (Buffer.isBuffer(body) ? body : Buffer.from(String(body)))
      var h = Object.assign({}, headers || {})
      if (payload && h['Content-Length'] == null) h['Content-Length'] = payload.length
      var req = https.request({hostname:hostname,path:path,method:method || 'GET',headers:h}, function(r) {
        var chunks=[]
        r.on('data',function(c){chunks.push(c)})
        r.on('end',function(){
          var text=Buffer.concat(chunks).toString('utf8')
          var parsed=null
          try { parsed=JSON.parse(text) } catch(e) { parsed=text }
          resolve({status:r.statusCode || 0,headers:r.headers || {},body:parsed,text:text})
        })
      })
      req.on('error',function(e){resolve({status:599,body:{error:e.message},text:e.message,headers:{}})})
      if(payload) req.write(payload)
      req.end()
    })
  }

  function sb(path, method, body, prefer) {
    if (!SERVICE_KEY) return Promise.resolve({status:503,body:{error:'SERVICE_ROLE_NOT_CONFIGURED'}})
    var u = new URL(SB_URL + path)
    var payload = body == null ? null : JSON.stringify(body)
    var headers = {'apikey':SERVICE_KEY,'Authorization':'Bearer '+SERVICE_KEY}
    if(payload) headers['Content-Type']='application/json'
    if(prefer) headers['Prefer']=prefer
    return request(u.hostname,u.pathname+u.search,method || 'GET',headers,payload)
  }

  async function auth(req, res) {
    if (typeof verifyApp !== 'function') { json(res,503,{ok:false,error:'AUTH_VERIFIER_NOT_CONFIGURED'}); return null }
    var token = String(req.headers['x-ascenda-session'] || req.headers['x-aos-app-token'] || '')
    var a = await verifyApp(token)
    if (!a || a.ok !== true) { json(res,(a&&a.status)||401,{ok:false,error:'UNAUTHORIZED'}); return null }
    a._token = token
    return a
  }

  function readBody(req) {
    return new Promise(function(resolve,reject){
      var chunks=[], total=0
      req.on('data',function(c){
        total += c.length
        if(total > 1024*1024) { reject(new Error('BODY_TOO_LARGE')); req.destroy(); return }
        chunks.push(c)
      })
      req.on('end',function(){
        try { resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {}) }
        catch(e){ reject(new Error('INVALID_JSON')) }
      })
      req.on('error',reject)
    })
  }

  function sha(v) { return crypto.createHash('sha256').update(String(v||'')).digest('hex') }
  function b64url(buf){ return Buffer.from(buf).toString('base64').replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'') }
  function fromB64url(v){
    var s=String(v||'').replace(/-/g,'+').replace(/_/g,'/')
    while(s.length%4) s+='='
    return Buffer.from(s,'base64')
  }
  function tokenKey() {
    var raw=String(process.env.GOOGLE_TOKEN_ENCRYPTION_KEY || '')
    if(!raw) return null
    var b
    try { b=fromB64url(raw) } catch(e) { b=Buffer.alloc(0) }
    return b.length===32 ? b : crypto.createHash('sha256').update(raw).digest()
  }
  function encryptSecret(value) {
    var key=tokenKey()
    if(!key) throw new Error('GOOGLE_TOKEN_ENCRYPTION_KEY_MISSING')
    var iv=crypto.randomBytes(12)
    var cipher=crypto.createCipheriv('aes-256-gcm',key,iv)
    var ct=Buffer.concat([cipher.update(String(value),'utf8'),cipher.final()])
    var tag=cipher.getAuthTag()
    return ['v1',b64url(iv),b64url(tag),b64url(ct)].join('.')
  }
  function decryptSecret(packed) {
    var key=tokenKey()
    if(!key) throw new Error('GOOGLE_TOKEN_ENCRYPTION_KEY_MISSING')
    var p=String(packed||'').split('.')
    if(p.length!==4 || p[0]!=='v1') throw new Error('GOOGLE_TOKEN_FORMAT_INVALID')
    var decipher=crypto.createDecipheriv('aes-256-gcm',key,fromB64url(p[1]))
    decipher.setAuthTag(fromB64url(p[2]))
    return Buffer.concat([decipher.update(fromB64url(p[3])),decipher.final()]).toString('utf8')
  }
  function configured() {
    return !!(CLIENT_ID() && CLIENT_SECRET() && REDIRECT_URI() && SERVICE_KEY && tokenKey())
  }

  async function integrationRow() {
    var r=await sb('/rest/v1/aos_integraciones?select=*&tipo=eq.google&nombre=eq.'+encodeURIComponent('Google Calendar + Contacts')+'&limit=1','GET')
    return r.status<300 && Array.isArray(r.body) && r.body[0] ? r.body[0] : null
  }

  async function connectionById(id) {
    var r=await sb('/rest/v1/aos_google_connections_v1?select=*&id=eq.'+encodeURIComponent(id)+'&limit=1','GET')
    return r.status<300 && Array.isArray(r.body) && r.body[0] ? r.body[0] : null
  }

  async function primaryConnection() {
    var r=await sb('/rest/v1/aos_google_connections_v1?select=*&status=eq.CONNECTED&is_primary=eq.true&limit=1','GET')
    return r.status<300 && Array.isArray(r.body) && r.body[0] ? r.body[0] : null
  }

  async function accessToken(conn) {
    if(!conn || !conn.refresh_token_enc) throw new Error('GOOGLE_REFRESH_TOKEN_MISSING')
    var refresh=decryptSecret(conn.refresh_token_enc)
    var form=new URLSearchParams({
      client_id:CLIENT_ID(),
      client_secret:CLIENT_SECRET(),
      refresh_token:refresh,
      grant_type:'refresh_token'
    }).toString()
    var r=await request('oauth2.googleapis.com','/token','POST',{'Content-Type':'application/x-www-form-urlencoded'},form)
    if(r.status>=300 || !r.body || !r.body.access_token) throw new Error('GOOGLE_TOKEN_REFRESH_FAILED')
    return r.body.access_token
  }

  async function googleJson(token, hostname, path, method, body) {
    var payload=body==null?null:JSON.stringify(body)
    var headers={'Authorization':'Bearer '+token}
    if(payload) headers['Content-Type']='application/json'
    return request(hostname,path,method||'GET',headers,payload)
  }

  async function status(req,res) {
    var a=await auth(req,res); if(!a) return
    var integ=await integrationRow()
    var r=await sb('/rest/v1/aos_google_connections_v1?select=id,account_email,selected_calendar_id,selected_calendar_name,calendar_enabled,contacts_enabled,is_primary,status,last_success_at,last_error,created_at,updated_at&order=is_primary.desc,created_at.desc','GET')
    var connections=r.status<300 && Array.isArray(r.body)?r.body:[]
    json(res,200,{
      ok:true,
      configured:configured(),
      integration_enabled:MASTER_ON(),
      calendar_sync_enabled:CAL_ON(),
      contact_sync_enabled:CONTACT_ON(),
      integration:integ?{id:integ.id,nombre:integ.nombre,estado:integ.estado,cuenta:integ.cuenta,config:integ.config||{}}:null,
      connections:connections
    })
  }

  async function oauthStart(req,res) {
    var a=await auth(req,res); if(!a) return
    if(!configured()) return json(res,503,{ok:false,error:'GOOGLE_NOT_CONFIGURED'})
    if(!MASTER_ON()) return json(res,409,{ok:false,error:'GOOGLE_INTEGRATION_SAFE_OFF'})
    var integ=await integrationRow()
    if(!integ) return json(res,404,{ok:false,error:'GOOGLE_INTEGRATION_ROW_NOT_FOUND'})
    var state=b64url(crypto.randomBytes(32))
    var body={
      state_hash:sha(state),
      integration_id:integ.id,
      session_fingerprint:sha(a._token),
      requested_by:String(a.usuario || a.user_id || ''),
      return_to:'admin-config',
      expires_at:new Date(Date.now()+10*60*1000).toISOString()
    }
    var ins=await sb('/rest/v1/aos_google_oauth_states_v1','POST',body,'return=minimal')
    if(ins.status>=300) return json(res,500,{ok:false,error:'GOOGLE_STATE_STORE_FAILED'})
    var q=new URLSearchParams({
      client_id:CLIENT_ID(),
      redirect_uri:REDIRECT_URI(),
      response_type:'code',
      access_type:'offline',
      prompt:'consent',
      include_granted_scopes:'true',
      scope:SCOPES.join(' '),
      state:state
    })
    json(res,200,{ok:true,auth_url:'https://accounts.google.com/o/oauth2/v2/auth?'+q.toString()})
  }

  async function oauthCallback(req,res,url) {
    if(!configured()) return html(res,503,'<h2>ASCENDA Google no está configurado.</h2>')
    var state=String(url.searchParams.get('state')||'')
    var code=String(url.searchParams.get('code')||'')
    var oauthError=String(url.searchParams.get('error')||'')
    if(oauthError) return callbackPage(res,false,'Google canceló la autorización: '+oauthError)
    if(!state || !code) return callbackPage(res,false,'Respuesta OAuth incompleta.')
    var nowIso=new Date().toISOString()
    var sr=await sb('/rest/v1/aos_google_oauth_states_v1?select=*&state_hash=eq.'+sha(state)+'&consumed_at=is.null&expires_at=gt.'+encodeURIComponent(nowIso)+'&limit=1','GET')
    var st=sr.status<300 && Array.isArray(sr.body)&&sr.body[0]?sr.body[0]:null
    if(!st) return callbackPage(res,false,'La autorización expiró o ya fue utilizada.')

    var form=new URLSearchParams({
      code:code,
      client_id:CLIENT_ID(),
      client_secret:CLIENT_SECRET(),
      redirect_uri:REDIRECT_URI(),
      grant_type:'authorization_code'
    }).toString()
    var tr=await request('oauth2.googleapis.com','/token','POST',{'Content-Type':'application/x-www-form-urlencoded'},form)
    if(tr.status>=300 || !tr.body || !tr.body.access_token) return callbackPage(res,false,'Google no pudo completar el intercambio OAuth.')

    var ur=await googleJson(tr.body.access_token,'www.googleapis.com','/oauth2/v2/userinfo','GET')
    if(ur.status>=300 || !ur.body || !ur.body.email) return callbackPage(res,false,'No se pudo identificar la cuenta Google autorizada.')
    var email=String(ur.body.email).toLowerCase().trim()

    var existingR=await sb('/rest/v1/aos_google_connections_v1?select=*&integration_id=eq.'+st.integration_id+'&account_email=eq.'+encodeURIComponent(email)+'&limit=1','GET')
    var existing=existingR.status<300&&Array.isArray(existingR.body)&&existingR.body[0]?existingR.body[0]:null
    var refreshEnc=null
    if(tr.body.refresh_token) refreshEnc=encryptSecret(tr.body.refresh_token)
    else if(existing && existing.refresh_token_enc) refreshEnc=existing.refresh_token_enc
    else return callbackPage(res,false,'Google no entregó refresh token. Revoca el acceso anterior y vuelve a conectar.')

    await sb('/rest/v1/aos_google_connections_v1?integration_id=eq.'+st.integration_id+'&is_primary=eq.true','PATCH',{is_primary:false,updated_at:new Date().toISOString()},'return=minimal')

    var payload={
      integration_id:st.integration_id,
      account_email:email,
      google_account_id:String(ur.body.id||'')||null,
      refresh_token_enc:refreshEnc,
      granted_scopes:String(tr.body.scope||'').split(/\s+/).filter(Boolean),
      status:'CONNECTED',
      is_primary:true,
      connected_by:st.requested_by||null,
      token_version:1,
      last_success_at:new Date().toISOString(),
      last_error:null,
      updated_at:new Date().toISOString()
    }
    var up=await sb('/rest/v1/aos_google_connections_v1?on_conflict=integration_id,account_email','POST',payload,'resolution=merge-duplicates,return=representation')
    if(up.status>=300) return callbackPage(res,false,'ASCENDA no pudo guardar la conexión Google.')
    var conn=Array.isArray(up.body)&&up.body[0]?up.body[0]:null
    await sb('/rest/v1/aos_google_oauth_states_v1?state_hash=eq.'+sha(state),'PATCH',{consumed_at:new Date().toISOString()},'return=minimal')

    var integ=await integrationRow()
    var cfg=Object.assign({},integ&&integ.config||{}, {connection_id:conn&&conn.id||null,oauth_mode:'server'})
    await sb('/rest/v1/aos_integraciones?id=eq.'+st.integration_id,'PATCH',{
      estado:'conectado',cuenta:email,config:cfg,updated_at:new Date().toISOString()
    },'return=minimal')

    callbackPage(res,true,'Cuenta conectada: '+escapeHtml(email))
  }

  function callbackPage(res,ok,message) {
    var safe=String(message||'').replace(/[<>&"]/g,function(c){return {'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;'}[c]})
    html(res,ok?200:400,'<!doctype html><meta charset="utf-8"><title>ASCENDA Google</title><body style="font-family:Arial;padding:40px;background:#f7f9fc;color:#071d4a"><h2>'+(ok?'✅ Google conectado':'⚠️ No se pudo conectar')+'</h2><p>'+safe+'</p><p>Ya puedes cerrar esta ventana.</p><script>try{window.opener&&window.opener.postMessage({type:"ASCENDA_GOOGLE_OAUTH",ok:'+(ok?'true':'false')+'},"*")}catch(e){};setTimeout(function(){try{window.close()}catch(e){}},1200)</script></body>')
  }
  function escapeHtml(v){return String(v||'').replace(/[<>&"]/g,function(c){return {'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;'}[c]})}

  async function listCalendars(req,res,url) {
    var a=await auth(req,res); if(!a) return
    if(!MASTER_ON()) return json(res,409,{ok:false,error:'GOOGLE_INTEGRATION_SAFE_OFF'})
    var id=String(url.searchParams.get('connection_id')||'')
    var conn=id?await connectionById(id):await primaryConnection()
    if(!conn || conn.status!=='CONNECTED') return json(res,404,{ok:false,error:'GOOGLE_CONNECTION_NOT_FOUND'})
    try {
      var token=await accessToken(conn)
      var r=await googleJson(token,'www.googleapis.com','/calendar/v3/users/me/calendarList?minAccessRole=writer&showHidden=false','GET')
      if(r.status>=300) throw new Error('GOOGLE_CALENDAR_LIST_FAILED')
      var items=(r.body&&r.body.items||[]).map(function(x){return {id:x.id,summary:x.summary||x.id,primary:!!x.primary,accessRole:x.accessRole}})
      json(res,200,{ok:true,calendars:items})
    } catch(e){json(res,502,{ok:false,error:e.message})}
  }

  async function settings(req,res) {
    var a=await auth(req,res); if(!a) return
    var d
    try { d=await readBody(req) } catch(e){return json(res,400,{ok:false,error:e.message})}
    var conn=await connectionById(String(d.connection_id||''))
    if(!conn) return json(res,404,{ok:false,error:'GOOGLE_CONNECTION_NOT_FOUND'})
    if(d.calendar_enabled===true && !CAL_ON()) return json(res,409,{ok:false,error:'GOOGLE_CALENDAR_GLOBAL_SAFE_OFF'})
    if(d.contacts_enabled===true && !CONTACT_ON()) return json(res,409,{ok:false,error:'GOOGLE_CONTACT_GLOBAL_SAFE_OFF'})
    var patch={updated_at:new Date().toISOString()}
    if(typeof d.calendar_enabled==='boolean') patch.calendar_enabled=d.calendar_enabled
    if(typeof d.contacts_enabled==='boolean') patch.contacts_enabled=d.contacts_enabled
    if(d.selected_calendar_id) patch.selected_calendar_id=String(d.selected_calendar_id)
    if(d.selected_calendar_name!=null) patch.selected_calendar_name=String(d.selected_calendar_name||'')
    var r=await sb('/rest/v1/aos_google_connections_v1?id=eq.'+conn.id,'PATCH',patch,'return=representation')
    json(res,r.status<300?200:500,{ok:r.status<300,connection:r.status<300&&Array.isArray(r.body)?r.body[0]:null,error:r.status<300?undefined:'GOOGLE_SETTINGS_SAVE_FAILED'})
  }

  async function disconnect(req,res) {
    var a=await auth(req,res); if(!a) return
    var d
    try { d=await readBody(req) } catch(e){return json(res,400,{ok:false,error:e.message})}
    var conn=d.connection_id?await connectionById(String(d.connection_id)):await primaryConnection()
    if(!conn) return json(res,404,{ok:false,error:'GOOGLE_CONNECTION_NOT_FOUND'})
    try {
      if(conn.refresh_token_enc) {
        var refresh=decryptSecret(conn.refresh_token_enc)
        var form='token='+encodeURIComponent(refresh)
        await request('oauth2.googleapis.com','/revoke','POST',{'Content-Type':'application/x-www-form-urlencoded'},form)
      }
    } catch(e) {}
    await sb('/rest/v1/aos_google_connections_v1?id=eq.'+conn.id,'PATCH',{
      refresh_token_enc:null,status:'REVOKED',is_primary:false,calendar_enabled:false,contacts_enabled:false,updated_at:new Date().toISOString()
    },'return=minimal')
    var integ=await integrationRow()
    if(integ) await sb('/rest/v1/aos_integraciones?id=eq.'+integ.id,'PATCH',{estado:'pendiente',cuenta:'',updated_at:new Date().toISOString()},'return=minimal')
    json(res,200,{ok:true})
  }

  function validEmail(v){return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(v||'').trim())}
  function normalizePhone(v){
    var d=String(v||'').replace(/\D/g,'')
    if(d.length===9) return '+51'+d
    if(d.length===11 && d.slice(0,2)==='51') return '+'+d
    return d ? '+'+d : ''
  }
  function parseClock(v) {
    var s=String(v||'').trim().toUpperCase()
    var m=s.match(/^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?/)
    if(!m) return {h:9,m:0}
    var h=parseInt(m[1],10), min=parseInt(m[2],10)
    if(m[3]==='PM'&&h<12) h+=12
    if(m[3]==='AM'&&h===12) h=0
    return {h:h,m:min}
  }
  function appointmentTimes(appt) {
    var date=String(appt.fecha_cita||'').slice(0,10)
    var t=parseClock(appt.hora_cita)
    var hh=String(t.h).padStart(2,'0'), mm=String(t.m).padStart(2,'0')
    var start=date+'T'+hh+':'+mm+':00-05:00'
    var dt=new Date(start)
    var end=new Date(dt.getTime()+30*60000).toISOString().replace('Z','+00:00')
    return {start:start,end:end}
  }
  function eventIdFor(connId,appointmentId){return 'a'+sha(String(connId)+':'+String(appointmentId)).slice(0,31)}
  function scheduleHash(appt){return sha([appt.id,appt.fecha_cita,appt.hora_cita,appt.tratamiento,appt.sede,appt.nombre,appt.apellido,appt.correo,appt.doctora,appt.estado_cita].join('|'))}

  async function upsertCalendar(connectionId,appointmentId) {
    var conn=await connectionById(connectionId)
    if(!conn || conn.status!=='CONNECTED') throw new Error('GOOGLE_CONNECTION_NOT_FOUND')
    var ar=await sb('/rest/v1/aos_agenda_citas?select=*&id=eq.'+encodeURIComponent(appointmentId)+'&limit=1','GET')
    var appt=ar.status<300&&Array.isArray(ar.body)&&ar.body[0]?ar.body[0]:null
    if(!appt) throw new Error('APPOINTMENT_NOT_FOUND')
    if(String(appt.estado_cita||'').toUpperCase()==='CANCELADA') return deleteCalendar(connectionId,appointmentId)
    var linkR=await sb('/rest/v1/aos_google_calendar_links_v1?select=*&connection_id=eq.'+conn.id+'&appointment_id=eq.'+encodeURIComponent(appointmentId)+'&limit=1','GET')
    var link=linkR.status<300&&Array.isArray(linkR.body)&&linkR.body[0]?linkR.body[0]:null
    var token=await accessToken(conn)
    var calId=conn.selected_calendar_id||'primary'
    var eventId=link&&link.event_id?link.event_id:eventIdFor(conn.id,appt.id)
    var times=appointmentTimes(appt)
    var fullName=[appt.nombre,appt.apellido].filter(Boolean).join(' ').trim()||'Paciente'
    var attendees=validEmail(appt.correo)?[{email:String(appt.correo).trim()}]:undefined
    var event={
      id:eventId,
      summary:'ZIVITAL · '+fullName+(appt.tratamiento?' · '+appt.tratamiento:''),
      description:[
        'Cita ZIVITAL',
        appt.tratamiento?'Tratamiento: '+appt.tratamiento:'',
        appt.doctora?'Profesional: '+appt.doctora:'',
        'Referencia ASCENDA: '+appt.id
      ].filter(Boolean).join('\n'),
      location:appt.sede||'',
      start:{dateTime:times.start,timeZone:'America/Lima'},
      end:{dateTime:times.end,timeZone:'America/Lima'},
      extendedProperties:{private:{ascenda_appointment_id:String(appt.id),ascenda_source:'ASCENDA_OS',ascenda_schedule_hash:scheduleHash(appt)}},
      reminders:{useDefault:true}
    }
    if(attendees) event.attendees=attendees
    var send=attendees?'all':'none'
    var path='/calendar/v3/calendars/'+encodeURIComponent(calId)+'/events/'+encodeURIComponent(eventId)+'?sendUpdates='+send
    var r
    if(link) {
      var patch=Object.assign({},event); delete patch.id
      r=await googleJson(token,'www.googleapis.com',path,'PATCH',patch)
      if(r.status===404) link=null
    }
    if(!link) {
      r=await googleJson(token,'www.googleapis.com','/calendar/v3/calendars/'+encodeURIComponent(calId)+'/events?sendUpdates='+send,'POST',event)
      if(r.status===409) {
        var patch2=Object.assign({},event); delete patch2.id
        r=await googleJson(token,'www.googleapis.com',path,'PATCH',patch2)
      }
    }
    if(!r || r.status>=300) throw new Error('GOOGLE_CALENDAR_UPSERT_FAILED_'+(r&&r.status||0))
    var linkPayload={
      connection_id:conn.id,appointment_id:appt.id,calendar_id:calId,event_id:eventId,
      html_link:r.body&&r.body.htmlLink||link&&link.html_link||null,
      schedule_hash:scheduleHash(appt),sync_status:'SYNCED',last_synced_at:new Date().toISOString(),
      last_error:null,updated_at:new Date().toISOString()
    }
    await sb('/rest/v1/aos_google_calendar_links_v1?on_conflict=connection_id,appointment_id','POST',linkPayload,'resolution=merge-duplicates,return=minimal')
    await sb('/rest/v1/aos_agenda_citas?id=eq.'+encodeURIComponent(appt.id),'PATCH',{gcal_event_id:eventId},'return=minimal')
    return {event_id:eventId,html_link:linkPayload.html_link,attendee_invited:!!attendees}
  }

  async function deleteCalendar(connectionId,appointmentId) {
    var conn=await connectionById(connectionId)
    if(!conn) throw new Error('GOOGLE_CONNECTION_NOT_FOUND')
    var lr=await sb('/rest/v1/aos_google_calendar_links_v1?select=*&connection_id=eq.'+conn.id+'&appointment_id=eq.'+encodeURIComponent(appointmentId)+'&limit=1','GET')
    var link=lr.status<300&&Array.isArray(lr.body)&&lr.body[0]?lr.body[0]:null
    if(!link) return {deleted:false,reason:'NO_LINK'}
    var token=await accessToken(conn)
    var r=await googleJson(token,'www.googleapis.com','/calendar/v3/calendars/'+encodeURIComponent(link.calendar_id)+'/events/'+encodeURIComponent(link.event_id)+'?sendUpdates=all','DELETE')
    if(r.status>=300 && r.status!==404 && r.status!==410) throw new Error('GOOGLE_CALENDAR_DELETE_FAILED_'+r.status)
    await sb('/rest/v1/aos_google_calendar_links_v1?id=eq.'+link.id,'PATCH',{sync_status:'DELETED',last_synced_at:new Date().toISOString(),last_error:null,updated_at:new Date().toISOString()},'return=minimal')
    await sb('/rest/v1/aos_agenda_citas?id=eq.'+encodeURIComponent(appointmentId),'PATCH',{gcal_event_id:null},'return=minimal')
    return {deleted:true}
  }

  async function patientForAppointment(appt) {
    var rows=[]
    var phone=String(appt.numero_limpio||appt.numero||'').replace(/\D/g,'')
    if(phone) {
      var r=await sb('/rest/v1/aos_pacientes?select=*&numero_limpio=eq.'+encodeURIComponent(phone)+'&limit=2','GET')
      if(r.status<300&&Array.isArray(r.body)) rows=r.body
    }
    if(rows.length===1) return rows[0]
    if(validEmail(appt.correo)) {
      var e=await sb('/rest/v1/aos_pacientes?select=*&Email=ilike.'+encodeURIComponent(String(appt.correo).trim())+'&limit=2','GET')
      if(e.status<300&&Array.isArray(e.body)&&e.body.length===1) return e.body[0]
    }
    return null
  }

  function monthCode(dateLike) {
    var d=new Date(dateLike||Date.now())
    if(Number.isNaN(d.getTime())) d=new Date()
    return ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'][d.getMonth()]
  }
  function contactTag(raw,config) {
    var val=String(raw||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^A-Za-z0-9]/g,'').toUpperCase()
    var map=config&&config.contact_tag_map||{}
    var key=String(raw||'').toUpperCase()
    if(map&&map[key]) return String(map[key]).toUpperCase()
    return (val||'CLI').slice(0,3)
  }
  function contactPayload(patient,appt,config) {
    var first=String(patient&&patient.Nombres||appt&&appt.nombre||'').trim()
    var last=String(patient&&patient.Apellidos||appt&&appt.apellido||'').trim()
    var treatment=String(appt&&appt.tratamiento||patient&&patient.tratamiento_principal||appt&&appt.etiqueta_campana||'Cliente')
    var stamp=appt&&appt.ts_creado||patient&&patient.created_at||Date.now()
    var yy=String(new Date(stamp).getFullYear()).slice(-2)
    var formatted=((first+' '+last).trim()+' - '+contactTag(treatment,config)+' - '+monthCode(stamp)+yy).trim()
    var phone=normalizePhone(patient&&patient['Teléfono']||patient&&patient.numero_limpio||appt&&appt.numero_limpio||appt&&appt.numero||'')
    var email=String(patient&&patient.Email||appt&&appt.correo||'').trim()
    var patientId=String(patient&&patient.ID_PACIENTE||'')
    var body={names:[{givenName:formatted}],externalIds:patientId?[{value:patientId,type:'customer'}]:[]}
    if(phone) body.phoneNumbers=[{value:phone}]
    if(validEmail(email)) body.emailAddresses=[{value:email}]
    return {body:body,phone:phone,email:validEmail(email)?email:'',formatted:formatted,patient_id:patientId}
  }

  async function peopleRequest(token,path,method,body){return googleJson(token,'people.googleapis.com',path,method,body)}
  async function exactContactMatches(token,query,phone,email) {
    if(!query) return []
    var warmKey=sha(token).slice(0,16)
    if(!warmedContactSearch.has(warmKey)) {
      await peopleRequest(token,'/v1/people:searchContacts?query=&readMask=names,emailAddresses,phoneNumbers,externalIds&pageSize=10','GET')
      warmedContactSearch.add(warmKey)
    }
    var r=await peopleRequest(token,'/v1/people:searchContacts?query='+encodeURIComponent(query)+'&readMask=names,emailAddresses,phoneNumbers,externalIds&pageSize=30','GET')
    if(r.status>=300) return []
    var results=r.body&&r.body.results||[]
    return results.map(function(x){return x.person}).filter(Boolean).filter(function(p){
      var phones=(p.phoneNumbers||[]).map(function(x){return normalizePhone(x.value)})
      var emails=(p.emailAddresses||[]).map(function(x){return String(x.value||'').toLowerCase()})
      return (phone&&phones.indexOf(phone)>=0)||(email&&emails.indexOf(email.toLowerCase())>=0)
    })
  }

  async function upsertContact(connectionId,entityType,entityId) {
    var conn=await connectionById(connectionId)
    if(!conn || conn.status!=='CONNECTED') throw new Error('GOOGLE_CONNECTION_NOT_FOUND')
    var patient=null, appt=null
    if(entityType==='PATIENT') {
      var pr=await sb('/rest/v1/aos_pacientes?select=*&ID_PACIENTE=eq.'+encodeURIComponent(entityId)+'&limit=1','GET')
      patient=pr.status<300&&Array.isArray(pr.body)&&pr.body[0]?pr.body[0]:null
    } else {
      var ar=await sb('/rest/v1/aos_agenda_citas?select=*&id=eq.'+encodeURIComponent(entityId)+'&limit=1','GET')
      appt=ar.status<300&&Array.isArray(ar.body)&&ar.body[0]?ar.body[0]:null
      if(appt) patient=await patientForAppointment(appt)
    }
    if(!patient) throw new Error('PATIENT_NOT_RESOLVED')
    var integ=await integrationRow()
    var data=contactPayload(patient,appt,integ&&integ.config||{})
    var token=await accessToken(conn)
    var lr=await sb('/rest/v1/aos_google_contact_links_v1?select=*&connection_id=eq.'+conn.id+'&patient_id=eq.'+encodeURIComponent(data.patient_id)+'&limit=1','GET')
    var link=lr.status<300&&Array.isArray(lr.body)&&lr.body[0]?lr.body[0]:null
    var resourceName=link&&link.resource_name||''
    var etag=link&&link.etag||''

    if(!resourceName) {
      var matches=[]
      if(data.phone) matches=matches.concat(await exactContactMatches(token,data.phone,data.phone,data.email))
      if(data.email) matches=matches.concat(await exactContactMatches(token,data.email,data.phone,data.email))
      var unique={}
      matches.forEach(function(p){if(p&&p.resourceName) unique[p.resourceName]=p})
      var keys=Object.keys(unique)
      if(keys.length>1) throw new Error('CONTACT_IDENTITY_CONFLICT')
      if(keys.length===1) {
        resourceName=keys[0]
        etag=unique[resourceName].etag||''
      }
    }

    var r
    if(resourceName) {
      var current=await peopleRequest(token,'/v1/'+resourceName+'?personFields=names,emailAddresses,phoneNumbers,externalIds,metadata','GET')
      if(current.status<300&&current.body&&current.body.etag) etag=current.body.etag
      var update=Object.assign({},data.body,{etag:etag})
      r=await peopleRequest(token,'/v1/'+resourceName+':updateContact?updatePersonFields=names,emailAddresses,phoneNumbers,externalIds&personFields=names,emailAddresses,phoneNumbers,externalIds,metadata','PATCH',update)
    } else {
      r=await peopleRequest(token,'/v1/people:createContact?personFields=names,emailAddresses,phoneNumbers,externalIds,metadata','POST',data.body)
    }
    if(r.status>=300||!r.body||!r.body.resourceName) throw new Error('GOOGLE_CONTACT_UPSERT_FAILED_'+r.status)
    var pHash=sha(JSON.stringify(data.body))
    await sb('/rest/v1/aos_google_contact_links_v1?on_conflict=connection_id,patient_id','POST',{
      connection_id:conn.id,patient_id:data.patient_id,resource_name:r.body.resourceName,etag:r.body.etag||null,
      payload_hash:pHash,sync_status:'SYNCED',last_synced_at:new Date().toISOString(),last_error:null,updated_at:new Date().toISOString()
    },'resolution=merge-duplicates,return=minimal')
    return {resource_name:r.body.resourceName,display_name:data.formatted}
  }

  async function finishQueue(row,ok,error) {
    var patch={updated_at:new Date().toISOString(),locked_at:null,locked_by:null}
    if(ok) { patch.state='ACCEPTED'; patch.accepted_at=new Date().toISOString(); patch.last_error=null }
    else if(String(error||'').indexOf('CONTACT_IDENTITY_CONFLICT')===0) { patch.state='SKIPPED'; patch.last_error=String(error).slice(0,500) }
    else {
      patch.state='FAILED'; patch.last_error=String(error||'UNKNOWN').slice(0,500)
      patch.available_at=new Date(Date.now()+Math.min(3600000,Math.max(30000,row.attempt_count*row.attempt_count*30000))).toISOString()
    }
    await sb('/rest/v1/aos_google_sync_outbox_v1?id=eq.'+row.id,'PATCH',patch,'return=minimal')
  }

  async function processQueueOnce() {
    if(!MASTER_ON() || (!CAL_ON()&&!CONTACT_ON())) return {claimed:0,processed:0}
    var cr=await sb('/rest/v1/rpc/aos_google_claim_sync_v1','POST',{p_worker:workerId,p_limit:10},'return=representation')
    var rows=cr.status<300&&Array.isArray(cr.body)?cr.body:[]
    var done=0
    for(var i=0;i<rows.length;i++) {
      var row=rows[i]
      try {
        if((row.action==='CALENDAR_UPSERT'||row.action==='CALENDAR_DELETE')&&!CAL_ON()) {
          await sb('/rest/v1/aos_google_sync_outbox_v1?id=eq.'+row.id,'PATCH',{state:'READY',locked_at:null,locked_by:null,available_at:new Date(Date.now()+300000).toISOString(),updated_at:new Date().toISOString()},'return=minimal')
          continue
        }
        if(row.action==='CONTACT_UPSERT'&&!CONTACT_ON()) {
          await sb('/rest/v1/aos_google_sync_outbox_v1?id=eq.'+row.id,'PATCH',{state:'READY',locked_at:null,locked_by:null,available_at:new Date(Date.now()+300000).toISOString(),updated_at:new Date().toISOString()},'return=minimal')
          continue
        }
        if(row.action==='CALENDAR_UPSERT') await upsertCalendar(row.connection_id,row.entity_id)
        else if(row.action==='CALENDAR_DELETE') await deleteCalendar(row.connection_id,row.entity_id)
        else if(row.action==='CONTACT_UPSERT') await upsertContact(row.connection_id,row.entity_type,row.entity_id)
        await finishQueue(row,true)
        done++
      } catch(e) { await finishQueue(row,false,e&&e.message||e) }
    }
    return {claimed:rows.length,processed:done}
  }

  async function runOnceRoute(req,res) {
    var a=await auth(req,res); if(!a) return
    var r=await processQueueOnce()
    json(res,200,{ok:true,result:r})
  }

  async function testCalendar(req,res) {
    var a=await auth(req,res); if(!a) return
    if(!MASTER_ON()) return json(res,409,{ok:false,error:'GOOGLE_INTEGRATION_SAFE_OFF'})
    var d
    try { d=await readBody(req) } catch(e){return json(res,400,{ok:false,error:e.message})}
    var conn=d.connection_id?await connectionById(String(d.connection_id)):await primaryConnection()
    if(!conn) return json(res,404,{ok:false,error:'GOOGLE_CONNECTION_NOT_FOUND'})
    try {
      var token=await accessToken(conn)
      var start=new Date(Date.now()+15*60000), end=new Date(start.getTime()+15*60000)
      var body={
        summary:'ASCENDA · Prueba Calendar ZIVITAL',
        description:'Canary controlado de integración Google Calendar. Puede eliminarse después de validar.',
        start:{dateTime:start.toISOString(),timeZone:'America/Lima'},
        end:{dateTime:end.toISOString(),timeZone:'America/Lima'},
        extendedProperties:{private:{ascenda_source:'ASCENDA_OS',ascenda_canary:'true'}},
        reminders:{useDefault:true}
      }
      if(validEmail(d.attendee_email)) body.attendees=[{email:String(d.attendee_email).trim()}]
      var send=body.attendees?'all':'none'
      var r=await googleJson(token,'www.googleapis.com','/calendar/v3/calendars/'+encodeURIComponent(conn.selected_calendar_id||'primary')+'/events?sendUpdates='+send,'POST',body)
      if(r.status>=300) throw new Error('GOOGLE_CALENDAR_TEST_FAILED_'+r.status)
      json(res,200,{ok:true,event_id:r.body.id,html_link:r.body.htmlLink||null,attendee_invited:!!body.attendees})
    } catch(e){json(res,502,{ok:false,error:e.message})}
  }

  async function testContact(req,res) {
    var a=await auth(req,res); if(!a) return
    if(!MASTER_ON()) return json(res,409,{ok:false,error:'GOOGLE_INTEGRATION_SAFE_OFF'})
    var d
    try { d=await readBody(req) } catch(e){return json(res,400,{ok:false,error:e.message})}
    var conn=d.connection_id?await connectionById(String(d.connection_id)):await primaryConnection()
    if(!conn) return json(res,404,{ok:false,error:'GOOGLE_CONNECTION_NOT_FOUND'})
    try {
      var token=await accessToken(conn)
      var body={names:[{givenName:String(d.name||'ASCENDA CANARY - TEST').slice(0,120)}]}
      if(validEmail(d.email)) body.emailAddresses=[{value:String(d.email).trim()}]
      if(d.phone) body.phoneNumbers=[{value:normalizePhone(d.phone)}]
      body.externalIds=[{value:'ASCENDA-CANARY-'+Date.now(),type:'customer'}]
      var r=await peopleRequest(token,'/v1/people:createContact?personFields=names,emailAddresses,phoneNumbers,externalIds,metadata','POST',body)
      if(r.status>=300) throw new Error('GOOGLE_CONTACT_TEST_FAILED_'+r.status)
      json(res,200,{ok:true,resource_name:r.body.resourceName})
    } catch(e){json(res,502,{ok:false,error:e.message})}
  }

  async function backfillAppointments(req,res) {
    var a=await auth(req,res); if(!a) return
    var d
    try { d=await readBody(req) } catch(e){return json(res,400,{ok:false,error:e.message})}
    var conn=d.connection_id?await connectionById(String(d.connection_id)):await primaryConnection()
    if(!conn) return json(res,404,{ok:false,error:'GOOGLE_CONNECTION_NOT_FOUND'})
    var from=String(d.date_from||new Date().toISOString().slice(0,10))
    var to=String(d.date_to||from.slice(0,8)+'31')
    var ar=await sb('/rest/v1/aos_agenda_citas?select=id,fecha_cita,hora_cita,tratamiento,sede,nombre,apellido,correo,numero_limpio,numero,doctora,estado_cita&fecha_cita=gte.'+encodeURIComponent(from)+'&fecha_cita=lte.'+encodeURIComponent(to)+'&order=fecha_cita.asc&limit=1000','GET')
    var rows=ar.status<300&&Array.isArray(ar.body)?ar.body:[]
    var active=rows.filter(function(x){return ['CANCELADA','NO ASISTIO'].indexOf(String(x.estado_cita||'').toUpperCase())<0})
    var withEmail=active.filter(function(x){return validEmail(x.correo)}).length
    if(d.confirm!==true) return json(res,200,{ok:true,dry_run:true,total:rows.length,active:active.length,with_email:withEmail})
    if(!CAL_ON() || !conn.calendar_enabled) return json(res,409,{ok:false,error:'GOOGLE_CALENDAR_NOT_ENABLED_FOR_BACKFILL'})
    var inserted=0
    for(var i=0;i<active.length;i++) {
      var ap=active[i], rev=scheduleHash(ap)
      var ir=await sb('/rest/v1/aos_google_sync_outbox_v1','POST',{
        idempotency_key:'gcal-backfill:'+conn.id+':'+ap.id+':'+rev,
        connection_id:conn.id,entity_type:'APPOINTMENT',entity_id:ap.id,action:'CALENDAR_UPSERT',
        payload:{revision:rev,source:'backfill'}
      },'resolution=ignore-duplicates,return=minimal')
      if(ir.status<300) inserted++
      if(CONTACT_ON()&&conn.contacts_enabled) await sb('/rest/v1/aos_google_sync_outbox_v1','POST',{
        idempotency_key:'gcontact-backfill:'+conn.id+':'+ap.id+':'+rev,
        connection_id:conn.id,entity_type:'APPOINTMENT',entity_id:ap.id,action:'CONTACT_UPSERT',
        payload:{revision:rev,source:'backfill'}
      },'resolution=ignore-duplicates,return=minimal')
    }
    json(res,200,{ok:true,dry_run:false,queued:inserted,active:active.length,with_email:withEmail})
  }

  function calendarLinkSignature(appointmentId) {
    var key=tokenKey()
    if(!key) return ''
    return b64url(crypto.createHmac('sha256',crypto.createHash('sha256').update(Buffer.concat([Buffer.from('calendar-link:'),key])).digest()).update(String(appointmentId)).digest()).slice(0,32)
  }
  function calendarPublicUrl(appointmentId) {
    if(!appointmentId || !REDIRECT_URI()) return ''
    var base=REDIRECT_URI().replace(/\/api\/google\/oauth\/callback.*$/,'')
    return base+'/api/google/appointment-link?appointment_id='+encodeURIComponent(String(appointmentId))+'&sig='+encodeURIComponent(calendarLinkSignature(appointmentId))
  }
  function emailCalendarButton(appointmentId) {
    var url=calendarPublicUrl(appointmentId)
    if(!url) return ''
    return '<div style="text-align:center;margin:22px 0 10px"><a href="'+url+'" style="display:inline-block;background:#0A4FBF;color:#fff;text-decoration:none;padding:12px 20px;border-radius:10px;font-weight:700;font-family:Arial,sans-serif">📅 Ver en Google Calendar</a></div>'
  }
  async function appointmentLink(req,res,url) {
    var id=String(url.searchParams.get('appointment_id')||'')
    var sig=String(url.searchParams.get('sig')||'')
    if(!id||!sig||sig.length!==32||!crypto.timingSafeEqual(Buffer.from(sig),Buffer.from(calendarLinkSignature(id)))) return html(res,403,'<h2>Enlace de Calendar no válido.</h2>')
    var r=await sb('/rest/v1/aos_google_calendar_links_v1?select=html_link,sync_status&appointment_id=eq.'+encodeURIComponent(id)+'&sync_status=eq.SYNCED&order=updated_at.desc&limit=1','GET')
    var link=r.status<300&&Array.isArray(r.body)&&r.body[0]?r.body[0]:null
    if(link&&/^https:\/\/calendar\.google\.com\//.test(String(link.html_link||''))) return redirect(res,link.html_link)
    html(res,202,'<!doctype html><meta charset="utf-8"><body style="font-family:Arial;padding:40px"><h2>📅 Cita ASCENDA</h2><p>La cita está registrada. Google Calendar todavía está sincronizando este evento.</p></body>')
  }

  async function handle(req,res) {
    var url
    try { url=new URL(req.url,'https://ascenda.local') } catch(e){return json(res,400,{ok:false,error:'BAD_URL'})}
    var p=url.pathname
    try {
      if(p==='/api/google/status'&&req.method==='GET') return status(req,res)
      if(p==='/api/google/oauth/start'&&req.method==='GET') return oauthStart(req,res)
      if(p==='/api/google/oauth/callback'&&req.method==='GET') return oauthCallback(req,res,url)
      if(p==='/api/google/calendars'&&req.method==='GET') return listCalendars(req,res,url)
      if(p==='/api/google/settings'&&req.method==='POST') return settings(req,res)
      if(p==='/api/google/disconnect'&&req.method==='POST') return disconnect(req,res)
      if(p==='/api/google/test/calendar'&&req.method==='POST') return testCalendar(req,res)
      if(p==='/api/google/test/contact'&&req.method==='POST') return testContact(req,res)
      if(p==='/api/google/worker/run-once'&&req.method==='POST') return runOnceRoute(req,res)
      if(p==='/api/google/backfill/appointments'&&req.method==='POST') return backfillAppointments(req,res)
      if(p==='/api/google/appointment-link'&&req.method==='GET') return appointmentLink(req,res,url)
      return json(res,404,{ok:false,error:'GOOGLE_ROUTE_NOT_FOUND'})
    } catch(e) {
      return json(res,500,{ok:false,error:String(e&&e.message||'GOOGLE_INTERNAL_ERROR')})
    }
  }

  var timer=setInterval(function(){processQueueOnce().catch(function(){})},30000)
  if(timer&&timer.unref) timer.unref()

  return {
    handle:handle,
    processQueueOnce:processQueueOnce,
    emailCalendarButton:emailCalendarButton,
    calendarPublicUrl:calendarPublicUrl,
    _test:{encryptSecret:encryptSecret,decryptSecret:decryptSecret,calendarLinkSignature:calendarLinkSignature,contactTag:contactTag,monthCode:monthCode}
  }
}

module.exports={createGoogleIntegrationV1}
