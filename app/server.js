const http = require('http')
const https = require('https')
const fs   = require('fs')
const path = require('path')
const { createEmailGateway } = require('./email-gateway')
const EMAIL_GATEWAY = createEmailGateway()
const PORT = parseInt(process.env.PORT || '4173', 10)
// Servir siempre desde public/ (archivos HTML estÃ¡ticos editados directamente)
// El build de vite no aplica a estos archivos
const PUB  = path.join(__dirname, 'public')
const MIME = {
  '.html':'text/html; charset=utf-8','.js':'application/javascript',
  '.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.ico':'image/x-icon',
  '.json':'application/json; charset=utf-8','.webmanifest':'application/manifest+json',
  '.woff':'font/woff','.woff2':'font/woff2','.ttf':'font/ttf',
  '.jpg':'image/jpeg','.jpeg':'image/jpeg','.webp':'image/webp','.gif':'image/gif',
  '.txt':'text/plain; charset=utf-8','.map':'application/json'
}

// â•â•â• SUPABASE â•â•â•
const SB_URL = 'https://ituyqwstonmhnfshnaqz.supabase.co'
const SB_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0'
const VERIFY_TOKEN = 'ascendaos_zivital_2026'
// F16: Email tables are backend-only. No service-role value is stored in source.
const EMAIL_SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.service_role || ''
function f16DbKey(endpoint) {
  var e = String(endpoint || '')
  return /^\/rest\/v1\/aos_emails?_/.test(e) ? EMAIL_SB_KEY : SB_KEY
}
function f16RequireEmailBackend(endpoint) {
  if (/^\/rest\/v1\/aos_emails?_/.test(String(endpoint || '')) && !EMAIL_SB_KEY) {
    throw new Error('EMAIL_SERVICE_ROLE_NOT_CONFIGURED')
  }
}

function f16SupabaseHeaders(dbKey, extra) {
  var headers = { 'apikey': dbKey }
  if (!/^sb_(?:secret|publishable)_/.test(String(dbKey || ''))) headers.Authorization = 'Bearer ' + dbKey
  return Object.assign(headers, extra || {})
}

function sbPost(endpoint, body, method) {
  f16RequireEmailBackend(endpoint)
  const url = new URL(SB_URL + endpoint)
  const httpMethod = String(method || 'POST').toUpperCase() === 'PATCH' ? 'PATCH' : 'POST'
  const dbKey = f16DbKey(endpoint)
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body)
    const req = https.request({
      hostname: url.hostname, path: url.pathname + url.search,
      method: httpMethod,
      headers: f16SupabaseHeaders(dbKey, { 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(data) })
    }, (res) => { let d = ''; res.on('data', c => d += c); res.on('end', () => resolve(res.statusCode)) })
    req.on('error', reject)
    req.write(data)
    req.end()
  })
}
function sbGet(endpoint) {
  try { f16RequireEmailBackend(endpoint) } catch (e) { return Promise.resolve([]) }
  const url = new URL(SB_URL + endpoint)
  const dbKey = f16DbKey(endpoint)
  return new Promise(function(resolve, reject) {
    https.get({
      hostname: url.hostname, path: url.pathname + url.search,
      headers: f16SupabaseHeaders(dbKey)
    }, function(r) {
      var d = ''; r.on('data', function(c) { d += c }); r.on('end', function() {
        try { resolve(JSON.parse(d)) } catch(e) { resolve([]) }
      })
    }).on('error', function() { resolve([]) })
  })
}
function sbRpc(fnName, params) {
  const url = new URL(SB_URL + '/rest/v1/rpc/' + fnName)
  var data = JSON.stringify(params || {})
  return new Promise(function(resolve) {
    var req = https.request({
      hostname: url.hostname, path: url.pathname, method: 'POST',
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) }
    }, function(r) {
      var d = ''; r.on('data', function(c) { d += c }); r.on('end', function() {
        try { resolve(JSON.parse(d)) } catch(e) { resolve(null) }
      })
    })
    req.on('error', function() { resolve(null) })
    req.write(data); req.end()
  })
}
function sbPatch(endpoint, body) {
  try { f16RequireEmailBackend(endpoint) } catch (e) { return Promise.resolve(false) }
  const url = new URL(SB_URL + endpoint)
  const dbKey = f16DbKey(endpoint)
  var data = JSON.stringify(body || {})
  return new Promise(function(resolve) {
    var req = https.request({
      hostname: url.hostname, path: url.pathname + url.search, method: 'PATCH',
      headers: f16SupabaseHeaders(dbKey, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), 'Prefer': 'return=minimal' })
    }, function(r) {
      var d = ''; r.on('data', function(c) { d += c }); r.on('end', function() { resolve(r.statusCode < 300) })
    })
    req.on('error', function() { resolve(false) })
    req.write(data); req.end()
  })
}

// â•â•â• VALIDADOR DE SESION KRONIA â•â•â•
// Verifica que el usuario que llama al endpoint existe en aos_usuarios
function validarSesionKronia(usuario, idAsesor) {
  if (!usuario || usuario.trim() === '') return Promise.resolve(false)
  var url = '/rest/v1/aos_usuarios?select=nombre,codigo_asesor,activo&nombre=eq.' + encodeURIComponent(usuario.toUpperCase())
  return sbGet(url).then(function(rows) {
    if (!rows || !rows.length) return false
    var u = rows[0]
    if (u.activo === false) return false
    // Si pasan id_asesor, debe coincidir
    if (idAsesor && u.codigo_asesor && idAsesor !== u.codigo_asesor) return false
    return true
  }).catch(function() { return false })
}

function procesarWhisper(chunks, res) {
  try {
        var buf = Buffer.concat(chunks)
        sbGet('/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key&limit=1').then(function(rows) {
          var groqKey = rows && rows[0] ? rows[0].api_key : null
          if (!groqKey) { res.writeHead(400); res.end(JSON.stringify({error:'Groq key no encontrada'})); return }
          var boundary = '----KronIA' + Date.now()
          var payload = '--' + boundary + '\r\nContent-Disposition: form-data; name="file"; filename="audio.webm"\r\nContent-Type: audio/webm\r\n\r\n'
          var payloadEnd = '\r\n--' + boundary + '\r\nContent-Disposition: form-data; name="model"\r\n\r\nwhisper-large-v3-turbo\r\n--' + boundary + '\r\nContent-Disposition: form-data; name="language"\r\n\r\nes\r\n--' + boundary + '--\r\n'
          var fullBody = Buffer.concat([Buffer.from(payload), buf, Buffer.from(payloadEnd)])
          var wReq = https.request({
            hostname: 'api.groq.com', path: '/openai/v1/audio/transcriptions', method: 'POST',
            headers: { 'Authorization': 'Bearer ' + groqKey, 'Content-Type': 'multipart/form-data; boundary=' + boundary, 'Content-Length': fullBody.length }
          }, function(wRes) {
            var wData = ''; wRes.on('data', function(c) { wData += c }); wRes.on('end', function() {
              try {
                var r = JSON.parse(wData)
                res.writeHead(200, { 'Content-Type': 'application/json' })
                res.end(JSON.stringify({ ok: true, texto: r.text || '' }))
              } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Whisper parse error'})) }
            })
          })
          wReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
          wReq.write(fullBody); wReq.end()
        }).catch(function() { res.writeHead(500); res.end(JSON.stringify({error:'DB error'})) })
  } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Audio error'})) }
}

function procesarKroniaChat(d, pregunta, usuario, rol, sede, sessionId, res) {
  try {
    var historial = d.historial || []
        var leadActual = d.lead_actual || null
        var confirmarAccion = d.confirmar_accion || null
        var idAsesor = d.id_asesor || ''
        if (!pregunta && !confirmarAccion) { res.writeHead(400); res.end(JSON.stringify({error:'Pregunta vacÃ­a'})); return }
        
        // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
        // BRANCH 1: Si viene confirmar_accion = ejecutar la acciÃ³n pendiente
        // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
        if (confirmarAccion && confirmarAccion.rpc && confirmarAccion.params) {
          var rpcsPermitidas = [
            'aos_editar_venta',
            'aos_kronia_editar_cita',
            'aos_kronia_editar_paciente',
            'aos_kronia_reprogramar_seguimiento',
            'aos_kronia_marcar_estado_cita',
            'aos_kronia_agregar_nota_paciente'
          ]
          if (rpcsPermitidas.indexOf(confirmarAccion.rpc) === -1) {
            res.writeHead(400); res.end(JSON.stringify({error:'RPC no autorizada para KronIA'})); return
          }
          // Inyectar usuario y rol segÃºn la RPC (cada una tiene su contrato)
          var params = Object.assign({}, confirmarAccion.params)
          if (confirmarAccion.rpc === 'aos_editar_venta') {
            params.p_editado_por = usuario.toUpperCase()
            params.p_rol = rol
            params.p_origen = 'kronia'
          } else if (confirmarAccion.rpc === 'aos_kronia_agregar_nota_paciente') {
            params.p_usuario = usuario.toUpperCase()
          } else {
            params.p_usuario = usuario.toUpperCase()
            params.p_rol = rol
          }
          
          var startTs = Date.now()
          sbRpc(confirmarAccion.rpc, params).then(function(result) {
            var dur = Date.now() - startTs
            
            // AuditorÃ­a en aos_kronia_acciones
            sbPost('/rest/v1/aos_kronia_acciones', {
              usuario: usuario, rol: rol, session_id: sessionId,
              accion: 'tool_call', objeto_tipo: confirmarAccion.rpc.replace('aos_kronia_','').replace('aos_',''),
              objeto_id: String(params.p_venta_id || params.p_cita_id || params.p_paciente_id || params.p_seg_id || params.p_numero_paciente || ''),
              tool_name: confirmarAccion.rpc,
              parametros: JSON.stringify(params),
              resultado: result ? JSON.stringify(result).substring(0,500) : 'null',
              cambios: result && result.cambios ? result.cambios : null,
              exitoso: result && result.ok === true,
              error: result && result.error ? result.error : null,
              duracion_ms: dur
            }).catch(function(){})
            
            if (!result || result.ok === false) {
              res.writeHead(200, { 'Content-Type': 'application/json' })
              res.end(JSON.stringify({ ok: true, respuesta: 'âš ï¸ No pude ejecutar: ' + (result && result.error ? result.error : 'error desconocido'), provider: 'ejecutor' }))
              return
            }
            
            // Mensaje humano
            var msg = 'âœ… Listo. '
            if (result.cambios && result.total > 0) {
              msg += 'Cambios aplicados: '
              var cambiosArr = typeof result.cambios === 'string' ? JSON.parse(result.cambios) : result.cambios
              msg += cambiosArr.map(function(c){return c.campo+': '+(c.antes||'(vacÃ­o)')+' â†’ '+c.despues}).join(', ')
            } else if (result.total === 0) {
              msg = 'â„¹ï¸ No hubo cambios (los valores ya eran iguales).'
            } else if (result.fecha_nueva) {
              msg += 'Reprogramado al '+result.fecha_nueva
            } else if (result.despues) {
              msg += result.antes+' â†’ '+result.despues
            } else {
              msg += JSON.stringify(result).substring(0,200)
            }
            
            sbPost('/rest/v1/aos_agente_logs', {
              agente_id: 'kronia', accion: 'ejecutar_' + confirmarAccion.rpc.replace('aos_kronia_','').replace('aos_',''),
              input_resumen: 'AcciÃ³n confirmada por ' + usuario,
              output_resumen: msg.substring(0,200), exitoso: true, duracion_ms: dur
            }).catch(function(){})
            sbRpc('aos_agente_registrar_ejecucion', { p_agente_id: 'kronia', p_exitoso: true }).catch(function(){})
            
            res.writeHead(200, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ ok: true, respuesta: msg, provider: 'ejecutor', resultado: result }))
          }).catch(function(e) {
            res.writeHead(200, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ ok: true, respuesta: 'âš ï¸ Error al ejecutar: ' + e.message, provider: 'ejecutor' }))
          })
          return
        }
        
        // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
        // BRANCH 2: Detectar si la pregunta es de EJECUCIÃ“N
        // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
        var pLower = pregunta.toLowerCase()
        var verbosEjecucion = /(cambia|corrige|corregir|edita|editar|modifica|modificar|actualiz|reprogram|reasign|mueve|cambiar fecha|cambiar estado|pon en|pÃ¡salo|pasalo|asÃ­gnale|asignale)/
        var esEjecucion = verbosEjecucion.test(pLower) && !/no\s+(cambies|edites|modifiques)/.test(pLower)
        
        if (!pregunta) { res.writeHead(400); res.end(JSON.stringify({error:'Pregunta vacÃ­a'})); return }

        var contextQueries = []
        var esAdmin = rol === 'ADMIN' || rol === 'admin'
        var hoy = new Date().toISOString().slice(0,10)
        var mesInicio = hoy.slice(0,8) + '01'
        var mesNum = new Date().getMonth() + 1
        var anioNum = new Date().getFullYear()
        var idAsesor = d.id_asesor || ''

        /* CatÃ¡logo completo */
        /* CatÃ¡logo de servicios â€” solo cargar si la pregunta menciona tratamientos/precios.
           OPTIMIZACION SES-038: antes se cargaba SIEMPRE (40 servicios completos = ~3KB
           innecesarios por chat). Ahora solo si lo pide. */
        var _pqcat = pregunta.toLowerCase()
        var pideCatalogo = /tratamiento|servicio|precio|costo|cuanto cuesta|cuanto vale|catalogo|catÃ¡logo|paquete|promo|oferta|hidrofacial|hifu|toxina|enzima|botox|capilar|facial|corporal/.test(_pqcat)
        if (pideCatalogo) {
          contextQueries.push(sbGet('/rest/v1/aos_catalogo_servicios?estado=eq.ACTIVO&select=nombre,categoria,precio_oferta,precio_base,descripcion_comercial,beneficios,contraindicaciones,perfil_paciente,faqs&limit=40&order=categoria'))
        } else {
          contextQueries.push(Promise.resolve(null))
        }
        
        if (!esAdmin) {
          /* OPTIMIZACION SES-038: si es saludo puro, no cargar nada pesado */
          var _saludoAsesor = /^(hola|hi|buen[ao]s|qu[eÃ©] tal|c[oÃ³]mo est[aÃ¡]s|hey|saludos|gracias|listo|ok|chau|adios|ad[iÃ­]os)\s*[\?Â¿!Â¡\.]*$/i.test(pregunta.trim())
          if (_saludoAsesor) {
            contextQueries.push(Promise.resolve(null)) // panel asesor
            contextQueries.push(Promise.resolve(null)) // comisiones
            contextQueries.push(Promise.resolve(null)) // inventario
            contextQueries.push(Promise.resolve(null)) // leads hoy
            contextQueries.push(Promise.resolve(null)) // seguimientos
          } else {
            /* Panel asesor consolidado (mÃ©tricas del mes + hoy) */
            contextQueries.push(sbRpc('aos_panel_asesor', {p_asesor: usuario, p_id_asesor: idAsesor, p_hoy: hoy, p_mes_inicio: mesInicio}))
            /* Comisiones REALES */
            contextQueries.push(sbRpc('aos_comisiones_asesor', {p_asesor: usuario, p_id_asesor: idAsesor, p_mes: mesNum, p_anio: anioNum}))
            /* Inventario por sede */
            contextQueries.push(sbGet('/rest/v1/aos_inventario?select=nombre,sede,stock_actual,unidad,precio_unitario&stock_actual=gt.0&order=nombre&limit=40'))
            /* Leads importados hoy */
            contextQueries.push(sbGet('/rest/v1/aos_leads?fecha=eq.' + hoy + '&select=numero_limpio,tratamiento,anuncio,fecha&order=id.desc&limit=20'))
            /* Seguimientos pendientes */
            contextQueries.push(sbGet('/rest/v1/aos_seguimientos?select=*&limit=15&order=id.desc'))
          }
        } else {
          /* ADMIN: cargar mÃ©tricas globales del mes (panel + ventas + comisiones + agenda + llamadas)
             OPTIMIZACION SES-038: si es saludo puro, NO cargar nada pesado.
             DetecciÃ³n de saludo se hace mas abajo, pero la replicamos aqui para optimizar. */
          var _esSaludo = /^(hola|hi|buen[ao]s|qu[eÃ©] tal|c[oÃ³]mo est[aÃ¡]s|hey|saludos|gracias|listo|ok|chau|adios|ad[iÃ­]os)\s*[\?Â¿!Â¡\.]*$/i.test(pregunta.trim())
          if (_esSaludo) {
            /* Saludo: cero datos pesados, deja 5 slots nulos para mantener indices */
            contextQueries.push(Promise.resolve(null)) // 1: panel
            contextQueries.push(Promise.resolve(null)) // 2: ventas mes
            contextQueries.push(Promise.resolve(null)) // 3: inventario
            contextQueries.push(Promise.resolve(null)) // 4: leads hoy
            contextQueries.push(Promise.resolve(null)) // 5: seguimientos
          } else {
            contextQueries.push(sbRpc('aos_panel_admin', {p_hoy: hoy, p_ayer: hoy, p_mes_inicio: mesInicio}))
            contextQueries.push(sbRpc('aos_ventas_admin', {p_mes: mesNum, p_anio: anioNum})) // resumen ventas mes
            contextQueries.push(sbGet('/rest/v1/aos_inventario?select=nombre,sede,stock_actual,unidad,precio_unitario&stock_actual=gt.0&order=nombre&limit=40'))
            contextQueries.push(sbGet('/rest/v1/aos_leads?fecha=eq.' + hoy + '&select=numero_limpio,tratamiento,anuncio&order=id.desc&limit=20'))
            contextQueries.push(sbGet('/rest/v1/aos_seguimientos?select=*&limit=15&order=id.desc'))
          }
        }

        /* Si la pregunta menciona tendencias/anÃ¡lisis/LTV/cohortes â†’ cargar insights de SofÃ­a */
        var preguntaLower = pregunta.toLowerCase()
        var pideAnalisis = /tendencia|analisis|anÃ¡lisis|ltv|cohorte|comparar|crecimiento|conversion|conversiÃ³n|facturaciÃ³n|facturacion|mes pasado|histÃ³rico|historico|evoluciÃ³n|evolucion/.test(preguntaLower)
        if (pideAnalisis) {
          contextQueries.push(sbRpc('aos_kronia_obtener_insights_sofia', {}))
        } else {
          contextQueries.push(Promise.resolve(null))
        }
        
        /* Si estÃ¡ en modo ejecutor, cargar ventas y seguimientos recientes para tener IDs reales */
        if (esEjecucion) {
          // Extraer posibles nombres/nÃºmeros mencionados en la pregunta para bÃºsqueda dirigida
          var palabras = pregunta.toUpperCase().match(/[A-ZÃÃ‰ÃÃ“ÃšÃ‘]{4,}/g) || []
          // Filtrar palabras comunes
          var stopWords = ['VENTA','CITA','PACIENTE','CLIENTE','SEGUIMIENTO','CAMBIA','CORRIGE','EDITA','MODIFICA','ACTUALIZA','REPROGRAMA','REASIGNA','FECHA','MONTO','ESTADO','PAGO','NUEVA','VIEJA','HOY','AYER','MAÃ‘ANA','LUNES','MARTES','MIERCOLES','JUEVES','VIERNES','SABADO','DOMINGO','MAYO','ABRIL','JUNIO','HOLA','GRACIAS','POR','FAVOR','PARA','DESDE','HASTA','SOLES','SOLES','SOLO']
          var nombres = palabras.filter(function(w){return stopWords.indexOf(w)===-1})
          var numeros = pregunta.match(/\d{7,9}/g) || []
          
          var ventasUrl = '/rest/v1/aos_ventas?select=id,venta_id,nombres,apellidos,tratamiento,monto,fecha,estado_pago,asesor,numero_limpio,dni&fecha=gte.' + new Date(Date.now()-60*86400000).toISOString().slice(0,10) + '&order=fecha.desc&limit=40'
          if (!esAdmin) ventasUrl += '&asesor=eq.' + encodeURIComponent(usuario.toUpperCase())
          contextQueries.push(sbGet(ventasUrl))
          
          // BÃºsqueda dirigida por nombre/nÃºmero mencionado en la pregunta
          var ventasMencionadasPromise = Promise.resolve([])
          if (nombres.length > 0 || numeros.length > 0) {
            // Buscar por cada nombre/nÃºmero mencionado usando la RPC
            var filtros = nombres.slice(0,3).concat(numeros.slice(0,2))
            var promesas = filtros.map(function(f){
              return sbRpc('aos_kronia_buscar_venta', { p_filtro: f, p_usuario: usuario.toUpperCase(), p_rol: rol })
                .then(function(r){return (r && r.ventas) ? r.ventas : []})
                .catch(function(){return []})
            })
            ventasMencionadasPromise = Promise.all(promesas).then(function(arrs){
              // Aplanar y deduplicar por id
              var todas = []; var ids = {}
              arrs.forEach(function(arr){arr.forEach(function(v){if(!ids[v.id]){ids[v.id]=true;todas.push(v)}})})
              return todas
            })
          }
          contextQueries.push(ventasMencionadasPromise)
          
          // Seguimientos pendientes del usuario
          var segUrl = '/rest/v1/aos_seguimientos?select=*&%22ESTADO%22=eq.PENDIENTE&order=%22FECHA_PROGRAMADA%22.desc&limit=20'
          if (!esAdmin) segUrl += '&%22ASESOR%22=eq.' + encodeURIComponent(usuario.toUpperCase())
          contextQueries.push(sbGet(segUrl))
        } else {
          contextQueries.push(Promise.resolve(null))
          contextQueries.push(Promise.resolve(null))
          contextQueries.push(Promise.resolve(null))
        }

        /* â•â•â• STATS GLOBALES KRONIA (Ã­ndices 10-13) â•â•â•
           OPTIMIZACION SES-038 (Supabase NANO saturado): carga AGRESIVAMENTE
           bajo demanda. sinFoco YA NO precarga nada â€” antes precargaba leads+
           agenda+comisiones "por si acaso" en cada chat y eso multiplicaba x4
           las consultas. Ahora solo carga lo que la pregunta menciona EXPLICITAMENTE. */
        var pq = pregunta.toLowerCase()
        /* Saludos / preguntas conversacionales sin sustancia: cero precarga */
        var esSaludo = /^(hola|hi|buen[ao]s|qu[eÃ©] tal|c[oÃ³]mo est[aÃ¡]s|hey|saludos|gracias|listo|ok|chau|adios|ad[iÃ­]os)\s*[\?Â¿!Â¡\.]*$/i.test(pregunta.trim())
        var pideLeads     = /lead|prospecto|campaÃ±a|campana|anuncio|importad/.test(pq)
        var pideAgenda    = /cita|agenda|agendad|asisti|no asist|reprogram|doctora|turno|programad/.test(pq)
        var pideLlamadas  = /llamad|llamÃ³|llamo|contact|marcar|gestion telef|tipificac/.test(pq)
        var pidePacientes = /paciente|cliente nuevo|clientes nuevos|cartera|activos|registrad|base de datos/.test(pq)
        /* sinFoco solo se usa para que las preguntas vagas tipo "como va todo"
           muestren panorama. Excluimos saludos puros. */
        var sinFoco = !esSaludo && !pideLeads && !pideAgenda && !pideLlamadas && !pidePacientes
        /* OPTIMIZACION CLAVE: sinFoco YA NO dispara stats automaticos.
           Antes: precargaba leads+agenda en cada chat sin foco = 2 RPC extras siempre.
           Ahora: solo carga si la pregunta lo MENCIONA explicitamente. */
        contextQueries.push(pideLeads     ? sbRpc('aos_kronia_stats_leads', {})     : Promise.resolve(null))
        contextQueries.push(pideAgenda    ? sbRpc('aos_kronia_stats_agenda', {})    : Promise.resolve(null))
        contextQueries.push(pideLlamadas  ? sbRpc('aos_kronia_stats_llamadas', {})  : Promise.resolve(null))
        contextQueries.push(pidePacientes ? sbRpc('aos_kronia_stats_pacientes', {}) : Promise.resolve(null))

        /* COMISIONES ADMIN: SOLO si la pregunta menciona comisiones.
           Antes: sinFoco la disparaba siempre = la RPC mas pesada en cada chat admin. */
        var pideComisiones = /comisi|porcentaje|regla|incentiv|bonif|ranking|cuanto gana|cuanto gano|cuanto ha ganado/.test(pq)
        if (esAdmin && pideComisiones) {
          contextQueries.push(sbRpc('aos_comisiones_admin', {p_mes: mesNum, p_anio: anioNum}))
        } else {
          contextQueries.push(Promise.resolve(null))
        }

        /* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
           KRONIA EXPLORER â€” Acceso al ecosistema bajo demanda (admin only)
           Indices 15-22. Solo carga si la pregunta lo pide explicitamente
           para optimizar tokens.
           â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
        var pideVentasGlobal  = esAdmin && /venta[s]?|facturad|cobr|ingres|ticket|promedio|total/.test(pq)
        var pideInventarioGl  = esAdmin && /inventario|stock|product[ao]|insumo|almacen|cantidad disponible|qued/.test(pq)
        var pideEquipoGlobal  = esAdmin && /equipo|asesor|doctor|enfermer|personal|trabajador|sueld|rrhh|meta/.test(pq)
        var pideMarketingGl   = esAdmin && /marketing|inversi[oÃ³]n|campa[Ã±n]a|anuncio|publicidad|meta ads|facebook|instagram|roas|cpa|cac/.test(pq)
        var pideFinanzasGl    = esAdmin && /finanz|caja|gasto|balance|costo|utilidad|ganancia|ingreso|egreso|presupuesto/.test(pq)
        var pideAtencionesGl  = esAdmin && /atenci[oÃ³]n|triaje|evaluaci[oÃ³]n|procedimiento|sesi[oÃ³]n cl[iÃ­]nic|atendi/.test(pq)
        var pideSeguimGlobal  = esAdmin && /seguimient|recontact|vencid|pendient|control de pacient/.test(pq)
        var pideAgendaFutura  = esAdmin && /pr[oÃ³]xim|siguiente|esta semana|pr[oÃ³]xima semana|futura|por venir|maÃ±ana|manana/.test(pq)

        /* Indice 15: inventario */
        if (pideInventarioGl) {
          contextQueries.push(sbRpc('aos_kronia_explorar', {p_modulo: 'inventario', p_accion: 'por_sede'}))
        } else { contextQueries.push(Promise.resolve(null)) }

        /* Indice 16: equipo */
        if (pideEquipoGlobal) {
          contextQueries.push(sbRpc('aos_kronia_explorar', {p_modulo: 'equipo', p_accion: 'lista'}))
        } else { contextQueries.push(Promise.resolve(null)) }

        /* Indice 17: marketing */
        if (pideMarketingGl) {
          contextQueries.push(sbRpc('aos_kronia_explorar', {p_modulo: 'marketing', p_accion: 'inversion_mes', p_params: JSON.stringify({mes: mesNum, anio: anioNum})}))
        } else { contextQueries.push(Promise.resolve(null)) }

        /* Indice 18: finanzas (balance global del mes) */
        if (pideFinanzasGl) {
          contextQueries.push(sbRpc('aos_kronia_explorar', {p_modulo: 'finanzas', p_accion: 'balance_mes', p_params: JSON.stringify({mes: mesNum, anio: anioNum})}))
        } else { contextQueries.push(Promise.resolve(null)) }

        /* Indice 19: atenciones (flujo clinico) */
        if (pideAtencionesGl) {
          contextQueries.push(sbRpc('aos_kronia_explorar', {p_modulo: 'atenciones', p_accion: 'resumen'}))
        } else { contextQueries.push(Promise.resolve(null)) }

        /* Indice 20: seguimientos (vencidos + por asesor) */
        if (pideSeguimGlobal) {
          contextQueries.push(sbRpc('aos_kronia_explorar', {p_modulo: 'seguimientos', p_accion: 'por_asesor'}))
        } else { contextQueries.push(Promise.resolve(null)) }

        /* Indice 21: agenda futura (proximos 7 dias) */
        if (pideAgendaFutura) {
          contextQueries.push(sbRpc('aos_kronia_explorar', {p_modulo: 'citas', p_accion: 'futuras', p_params: JSON.stringify({dias: 7, limite: 30})}))
        } else { contextQueries.push(Promise.resolve(null)) }

        /* Indice 22: ventas global detallado (cuando admin pregunta por ventas).
           Si menciona "sede / san isidro / pueblo libre / sucursal / local" -> por_sede
           Si menciona "tratamiento / servicio / producto" -> por_tratamiento
           Default -> por_tratamiento (mas info granular) */
        var pideVentasPorSede = /sede|san isidro|pueblo libre|sucursal|local|por separado|cada local|cada sede/.test(pq)
        var accionVentas = pideVentasPorSede ? 'por_sede' : 'por_tratamiento'
        if (pideVentasGlobal && esAdmin) {
          contextQueries.push(sbRpc('aos_kronia_explorar', {p_modulo: 'ventas', p_accion: accionVentas, p_params: JSON.stringify({mes: mesNum, anio: anioNum})}))
        } else { contextQueries.push(Promise.resolve(null)) }

        /* Indice 23: ventas por_sede SIEMPRE si admin pregunta y menciona sede
           (incluso si ya se pidio por_tratamiento, para tener ambas vistas) */
        if (pideVentasGlobal && esAdmin && pideVentasPorSede && accionVentas !== 'por_sede') {
          contextQueries.push(sbRpc('aos_kronia_explorar', {p_modulo: 'ventas', p_accion: 'por_sede', p_params: JSON.stringify({mes: mesNum, anio: anioNum})}))
        } else { contextQueries.push(Promise.resolve(null)) }

        Promise.all(contextQueries).then(function(results) {
          var catalogo = results[0] || []
          var panelData = results[1] || {}
          var comisionesData = results[2] || null
          var inventario = results[3] || []
          var leadsHoy = results[4] || []
          var seguimientos = results[5] || []
          var insightsSofia = results[6] || null
          var ventasEjecutor = results[7] || null
          var ventasMencionadas = results[8] || null
          var segEjecutor = results[9] || null
          var statsLeads = results[10] || null
          var statsAgenda = results[11] || null
          var statsLlamadas = results[12] || null
          var statsPacientes = results[13] || null
          var comisionesAdmin = results[14] || null
          /* KRONIA EXPLORER results (indices 15-22) â€” bajo demanda */
          var expInventario = results[15] || null
          var expEquipo = results[16] || null
          var expMarketing = results[17] || null
          var expFinanzas = results[18] || null
          var expAtenciones = results[19] || null
          var expSeguimientos = results[20] || null
          var expAgendaFutura = results[21] || null
          var expVentasGlobal = results[22] || null
          
          // Combinar ventas recientes + mencionadas (priorizar mencionadas, deduplicar)
          if (ventasMencionadas && ventasMencionadas.length > 0) {
            var idsSet = {}
            var combinadas = []
            ventasMencionadas.forEach(function(v){ idsSet[v.id]=true; combinadas.push(v) })
            if (ventasEjecutor) ventasEjecutor.forEach(function(v){ if(!idsSet[v.id]){ idsSet[v.id]=true; combinadas.push(v) } })
            ventasEjecutor = combinadas.slice(0, 50)
          }

          var catResumen = catalogo.map(function(c) {
            var faqs='';try{var f=typeof c.faqs==='string'?JSON.parse(c.faqs):(c.faqs||[]);if(f.length)faqs=' FAQ:'+f.slice(0,2).map(function(q){return q.q+'->'+q.a}).join('|')}catch(e){}
            return c.nombre+' ('+c.categoria+') S/'+(c.precio_oferta||0)+
              (c.descripcion_comercial?' -- '+c.descripcion_comercial.substring(0,100):'')+
              (c.beneficios?' | Benef:'+c.beneficios.substring(0,80):'')+
              (c.contraindicaciones?' | NO:'+c.contraindicaciones.substring(0,60):'')+
              (c.perfil_paciente?' | Para:'+c.perfil_paciente.substring(0,60):'')+faqs
          }).join('\n')

          var datosCtx = ''
          if (!esAdmin && panelData) {
            datosCtx += '\n--- TUS DATOS ('+usuario+') ---'
            datosCtx += '\nLLAMADAS HOY: '+(panelData.llamHoy||0)+' | CITAS HOY: '+(panelData.citasHoy||0)
            datosCtx += '\nLLAMADAS MES: '+(panelData.llamMes||0)+' | CITAS MES: '+(panelData.citasMes||0)+' | ASISTIDOS: '+(panelData.asistMes||0)
            datosCtx += '\nVENTAS MES: '+(panelData.ventasMes||0)+' ventas | FACTURADO: S/'+(panelData.factMes||0)
            datosCtx += '\nLEADS NUEVOS: '+(panelData.leadsNuevos||0)+' | LEADS LLAMADOS: '+(panelData.leadsLlamados||0)+' | LEADS CON CITA: '+(panelData.leadsCitas||0)
            /* Tipificaciones del mes */
            if(panelData.tipifMes&&typeof panelData.tipifMes==='object'){var tipifs=panelData.tipifMes;datosCtx+='\nTIPIFICACIONES: '+Object.keys(tipifs).map(function(k){return k+':'+tipifs[k]}).join(', ')}
            /* Resumen anual */
            if(panelData.resumenAnual&&panelData.resumenAnual.length){datosCtx+='\nRESUMEN ANUAL: '+panelData.resumenAnual.map(function(r){return r.mes_nombre+': '+r.llamadas+'llam, '+r.citas+'citas, S/'+Math.round(r.facturado||0)}).join(' | ')}
            /* Llamadas detalle hoy */
            if(panelData.llamadasHoy&&panelData.llamadasHoy.length){datosCtx+='\nDETALLE LLAMADAS HOY: '+panelData.llamadasHoy.slice(0,10).map(function(l){return l.hora+' '+l.numero+' '+l.estado}).join(' | ')}
            /* Comisiones REALES */
            if(comisionesData&&comisionesData.comTotal!==undefined){
              datosCtx+='\nCOMISIONES MES: S/'+comisionesData.comTotal+' (Servicios:S/'+(comisionesData.comServ||0)+' Productos:S/'+(comisionesData.comProd||0)+') Ranking:#'+(comisionesData.ranking||'?')
              if(comisionesData.detalle&&comisionesData.detalle.length){datosCtx+='\nDETALLE COMISIONES:';comisionesData.detalle.forEach(function(v){datosCtx+='\n  '+v.fecha+' '+(v.nombres||'')+' '+(v.apellidos||'')+' | '+v.tratamiento+' S/'+v.monto+' -> Com:S/'+v.comision_calculada+' ('+v.tipo+')'})}
              datosCtx+='\nNOTA: Solo las ventas donde TU eres asesor asignado generan comision. Un cliente puede comprar cosas asignadas a otro asesor o "NO APLICA".'
              if(comisionesData.topClientes&&comisionesData.topClientes.length){datosCtx+='\nTOP CLIENTES HISTORICOS: '+comisionesData.topClientes.map(function(c,i){return(i+1)+'.'+c.cliente+' S/'+Math.round(c.total)+' ('+c.compras+'compras ult:'+c.ult_fecha+')'}).join(' | ')}
            }
            if(leadActual)datosCtx+='\nLEAD ACTUAL: '+leadActual.num+' | Trat:'+leadActual.trat+' | Intento:'+(leadActual.intento||1)
            /* Inventario */
            if(inventario.length){var invPorSede={};inventario.forEach(function(i){var s=i.sede||'?';if(!invPorSede[s])invPorSede[s]=[];invPorSede[s].push(i.nombre+':'+i.stock_actual+(i.unidad||''))});datosCtx+='\nINVENTARIO: '+Object.keys(invPorSede).map(function(s){return s+' -> '+invPorSede[s].join(', ')}).join(' || ')}
            if(leadsHoy.length)datosCtx+='\nLEADS HOY: '+leadsHoy.length+' nums. Trats:'+[...new Set(leadsHoy.map(function(l){return l.tratamiento}))].join(',')
          } else if(esAdmin && panelData) {
            datosCtx += '\n--- METRICAS GLOBALES ADMIN (mes actual) ---'
            // panelData = aos_panel_admin (datos de hoy/ayer)
            if(panelData.kpis_hoy){var kh=panelData.kpis_hoy;datosCtx+='\nHOY: '+(kh.llamadas||0)+' llamadas, '+(kh.citas||0)+' citas, '+(kh.ventas||0)+' ventas, S/'+(kh.facturado||0)+' facturado, '+(kh.leads||0)+' leads'}
            if(panelData.kpis_mes){var km=panelData.kpis_mes;datosCtx+='\nMES ACUM: '+(km.llamadas||0)+' llamadas, '+(km.citas||0)+' citas, '+(km.ventas||0)+' ventas, S/'+Math.round(km.facturado||0)+' facturado, '+(km.leads||0)+' leads'}
            
            // comisionesData = aos_ventas_admin (resumen completo del mes)
            if(comisionesData){
              var v = comisionesData
              datosCtx += '\nVENTAS MES: total='+(v.nVentas||0)+' (servicios:'+(v.nServ||0)+', productos:'+(v.nProd||0)+') | facturado=S/'+Math.round(v.factTotal||0)+' (serv:S/'+Math.round(v.factServ||0)+', prod:S/'+Math.round(v.factProd||0)+') | ticket prom=S/'+Math.round(v.ticketProm||0)
              if(v.nPagoCompleto!==undefined) datosCtx += '\nESTADOS: completas='+(v.nPagoCompleto||0)+' adelantos='+(v.nAdelanto||0)+'(S/'+Math.round(v.factAdelanto||0)+') sin_definir='+(v.nSinDefinir||0)
              if(v.porAsesor && v.porAsesor.length){datosCtx+='\nVENTAS POR ASESOR: '+v.porAsesor.slice(0,8).map(function(a){return a.asesor+':'+a.cantidad+' (S/'+Math.round(a.facturado||0)+')'}).join(' | ')}
              if(v.porSede && v.porSede.length){datosCtx+='\nVENTAS POR SEDE: '+v.porSede.map(function(s){return s.sede+':'+s.cantidad+' (S/'+Math.round(s.facturado||0)+')'}).join(' | ')}
              if(v.porTratamiento && v.porTratamiento.length){datosCtx+='\nTOP TRATAMIENTOS: '+v.porTratamiento.slice(0,8).map(function(t){return t.tratamiento+':'+t.cantidad+' (S/'+Math.round(t.facturado||0)+')'}).join(' | ')}
              if(v.porMetodoPago && v.porMetodoPago.length){datosCtx+='\nMETODOS PAGO: '+v.porMetodoPago.slice(0,6).map(function(m){return m.metodo+':'+(m.cantidad||0)+' (S/'+Math.round(m.facturado||0)+')'}).join(' | ')}
              if(v.anual && v.anual.length){datosCtx+='\nHISTORICO ANUAL: '+v.anual.map(function(a){return 'mes'+a.mes+':'+a.nVentas+' ventas S/'+Math.round(a.facturado||0)}).join(' | ')}
            }

            /* === COMISIONES ADMIN (reglas + ranking por asesor) === */
            if(comisionesAdmin){
              var c = comisionesAdmin
              datosCtx += '\n\n--- COMISIONES ---'
              /* Reglas activas */
              if(c.reglas && c.reglas.length){
                var reglasProd = c.reglas.filter(function(r){return r.tipo==='PRODUCTO' && r.activo})
                var reglasServ = c.reglas.filter(function(r){return r.tipo==='SERVICIO' && r.activo})
                if(reglasServ.length){
                  var rServ = reglasServ[0]
                  datosCtx += '\nREGLA SERVICIOS: '+(rServ.descripcion||((rServ.comision_pct*100)+'% del monto'))
                }
                if(reglasProd.length){
                  datosCtx += '\nREGLAS PRODUCTOS (escalado por monto):'
                  reglasProd.forEach(function(r){
                    datosCtx += '\n  Desde S/'+r.monto_min+' -> comision fija S/'+r.comision
                  })
                }
              }
              /* Ranking por asesor del mes */
              if(c.porAsesor && c.porAsesor.length){
                datosCtx += '\nCOMISIONES DEL MES POR ASESOR (ranking):'
                c.porAsesor.forEach(function(a, idx){
                  datosCtx += '\n  '+(idx+1)+'. '+a.asesor+' -> S/'+a.com_total+' total (servicios S/'+a.com_serv+' + productos S/'+a.com_prod+') | '+a.n_ventas+' ventas / S/'+Math.round(a.facturado||0)+' facturado'
                })
              }
              /* NoAplica */
              if(c.noAplica){
                datosCtx += '\nVentas sin comision (NO APLICA): '+c.noAplica.n+' ventas / S/'+Math.round(c.noAplica.total||0)
              }
            }

            if(inventario && inventario.length){var invPorSede={};inventario.forEach(function(i){var s=i.sede||'?';if(!invPorSede[s])invPorSede[s]=[];invPorSede[s].push(i.nombre+':'+i.stock_actual+(i.unidad||''))});datosCtx+='\nINVENTARIO: '+Object.keys(invPorSede).map(function(s){return s+' -> '+invPorSede[s].slice(0,10).join(', ')}).join(' || ')}
            if(leadsHoy && leadsHoy.length)datosCtx+='\nLEADS HOY: '+leadsHoy.length+' nuevos. Trats:'+[...new Set(leadsHoy.map(function(l){return l.tratamiento}))].join(',')
            if(seguimientos && seguimientos.length){var segPend = seguimientos.filter(function(s){return s.ESTADO==='PENDIENTE'}).length; var segVenc = seguimientos.filter(function(s){return s.ESTADO==='VENCIDO'}).length; datosCtx+='\nSEGUIMIENTOS (muestra): '+segPend+' pendientes, '+segVenc+' vencidos en muestra'}

            /* â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
               KRONIA EXPLORER â€” Datos del ecosistema bajo demanda
               Estos bloques solo aparecen si la pregunta menciona el modulo.
               Cada bloque pesa ~150-400 tokens, suma manejable.
               â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• */
            if(expInventario && Array.isArray(expInventario) && expInventario.length){
              datosCtx += '\n\n--- INVENTARIO POR SEDE ---'
              expInventario.forEach(function(s){
                datosCtx += '\n  '+s.sede+': '+s.items+' items, valor total S/'+Math.round(s.valor_total||0)
              })
            }
            if(expEquipo && Array.isArray(expEquipo) && expEquipo.length){
              datosCtx += '\n\n--- EQUIPO ACTIVO ---'
              expEquipo.slice(0,15).forEach(function(e){
                datosCtx += '\n  '+e.codigo+' '+e.nombre+' ('+e.puesto+', sede '+e.sede+')'+(e.sueldo?' sueldo S/'+e.sueldo:'')+(e.meta?' meta '+e.meta:'')
              })
            }
            if(expMarketing){
              datosCtx += '\n\n--- MARKETING / INVERSION ---'
              datosCtx += '\nInversion total mes: S/'+Math.round(expMarketing.inversion_total||0)+' ('+(expMarketing.campanas||0)+' campaÃ±as)'
              if(expMarketing.por_tratamiento){
                datosCtx += '\nPor tratamiento: '+expMarketing.por_tratamiento.slice(0,10).map(function(p){return p.tratamiento+':S/'+Math.round(p.monto)}).join(' | ')
              }
            }
            if(expFinanzas){
              datosCtx += '\n\n--- BALANCE DEL MES ---'
              datosCtx += '\nIngresos por ventas: S/'+Math.round(expFinanzas.ingresos_ventas||0)
              datosCtx += '\nGastos de caja: S/'+Math.round(expFinanzas.gastos_caja||0)
              datosCtx += '\nInversion marketing: S/'+Math.round(expFinanzas.inversion_marketing||0)
              if(expFinanzas.comisiones_pagadas && Array.isArray(expFinanzas.comisiones_pagadas)){
                var totalCom = expFinanzas.comisiones_pagadas.reduce(function(a,c){return a+(parseFloat(c.com_total)||0)},0)
                datosCtx += '\nComisiones pagadas: S/'+Math.round(totalCom)
              }
            }
            if(expAtenciones){
              datosCtx += '\n\n--- ATENCIONES CLINICAS ---'
              datosCtx += '\nMes: '+(expAtenciones.mes_total||0)+' atenciones, '+(expAtenciones.mes_completas||0)+' completas, '+(expAtenciones.mes_en_curso||0)+' en curso'
            }
            if(expSeguimientos && Array.isArray(expSeguimientos) && expSeguimientos.length){
              datosCtx += '\n\n--- SEGUIMIENTOS POR ASESOR ---'
              expSeguimientos.slice(0,10).forEach(function(s){
                datosCtx += '\n  '+s.asesor+': '+s.pendientes+' pendientes, '+s.vencidos+' VENCIDOS'
              })
            }
            if(expAgendaFutura && Array.isArray(expAgendaFutura) && expAgendaFutura.length){
              datosCtx += '\n\n--- AGENDA PROXIMOS 7 DIAS ---'
              datosCtx += '\nTotal: '+expAgendaFutura.length+' citas programadas'
              expAgendaFutura.slice(0,15).forEach(function(c){
                datosCtx += '\n  '+c.fecha_cita+' '+(c.hora_cita||'')+' '+(c.nombre||'')+' '+(c.apellido||'')+' | '+(c.tratamiento||'')+' | '+(c.sede||'')+(c.doctora?' / '+c.doctora:'')+' ['+(c.estado_cita||'?')+']'
              })
            }
            if(expVentasGlobal && Array.isArray(expVentasGlobal) && expVentasGlobal.length){
              /* Detectar si vinieron datos por_sede o por_tratamiento */
              var primerItem = expVentasGlobal[0] || {}
              if(primerItem.sede !== undefined){
                datosCtx += '\n\n--- VENTAS POR SEDE (MES '+mesNum+'/'+anioNum+') ---'
                expVentasGlobal.forEach(function(s){
                  datosCtx += '\n  '+s.sede+': '+s.ventas+' ventas | facturado S/'+Math.round(s.facturado)
                })
              } else {
                datosCtx += '\n\n--- VENTAS POR TRATAMIENTO (MES) ---'
                expVentasGlobal.slice(0,12).forEach(function(t){
                  datosCtx += '\n  '+t.tratamiento+': '+t.ventas+' ventas | S/'+Math.round(t.facturado)
                })
              }
            }
            /* Indice 23: ventas por sede adicional (cuando ya cargamos por_tratamiento Y pregunto sede) */
            var expVentasPorSede = results[23] || null
            if(expVentasPorSede && Array.isArray(expVentasPorSede) && expVentasPorSede.length){
              datosCtx += '\n\n--- VENTAS POR SEDE (MES '+mesNum+'/'+anioNum+') ---'
              expVentasPorSede.forEach(function(s){
                datosCtx += '\n  '+s.sede+': '+s.ventas+' ventas | facturado S/'+Math.round(s.facturado)
              })
            }
          }

          /* â•â•â• STATS OPERATIVAS DEL DÃA A DÃA (admin y asesor) â•â•â• */
          if(statsLeads){
            var sl=statsLeads
            datosCtx+='\n\n--- LEADS ---'
            datosCtx+='\nLEADS: hoy='+(sl.hoy||0)+' | esta semana='+(sl.semana||0)+' | este mes='+(sl.mes||0)+' | histÃ³rico total='+(sl.historico||0)
            datosCtx+='\nCONVERSIÃ“N A CITA (mes): '+(sl.conversion_pct||0)+'% ('+(sl.convertidos_mes||0)+' de '+(sl.mes||0)+' leads ya tienen cita)'
            if(sl.por_tratamiento){datosCtx+='\nLEADS MES POR TRATAMIENTO: '+Object.keys(sl.por_tratamiento).map(function(k){return k+':'+sl.por_tratamiento[k]}).join(', ')}
            if(sl.por_anuncio){datosCtx+='\nTOP ANUNCIOS MES: '+Object.keys(sl.por_anuncio).map(function(k){return k+':'+sl.por_anuncio[k]}).join(' | ')}
          }
          if(statsAgenda){
            var sa=statsAgenda
            datosCtx+='\n\n--- AGENDA / CITAS ---'
            datosCtx+='\nCITAS: hoy='+(sa.citas_hoy||0)+' | esta semana='+(sa.citas_semana||0)+' | este mes='+(sa.citas_mes||0)
            if(sa.hoy_por_estado){datosCtx+='\nCITAS HOY POR ESTADO: '+Object.keys(sa.hoy_por_estado).map(function(k){return k+':'+sa.hoy_por_estado[k]}).join(', ')}
            if(sa.mes_por_estado){datosCtx+='\nCITAS MES POR ESTADO: '+Object.keys(sa.mes_por_estado).map(function(k){return k+':'+sa.mes_por_estado[k]}).join(', ')}
            if(sa.mes_por_sede){datosCtx+='\nCITAS MES POR SEDE: '+Object.keys(sa.mes_por_sede).map(function(k){return k+':'+sa.mes_por_sede[k]}).join(', ')}
            if(sa.hoy_detalle&&sa.hoy_detalle.length){datosCtx+='\nDETALLE CITAS HOY: '+sa.hoy_detalle.map(function(c){return c.hora+' '+c.nombre+' ('+c.tratamiento+') '+c.sede+' Â·'+c.estado}).join(' | ')}
          }
          if(statsLlamadas){
            var sll=statsLlamadas
            datosCtx+='\n\n--- LLAMADAS ---'
            datosCtx+='\nLLAMADAS: hoy='+(sll.llam_hoy||0)+' | esta semana='+(sll.llam_semana||0)+' | este mes='+(sll.llam_mes||0)+' | minutos mes='+(sll.minutos_mes||0)
            if(sll.mes_por_asesor){datosCtx+='\nLLAMADAS MES POR ASESOR: '+Object.keys(sll.mes_por_asesor).map(function(k){return k+':'+sll.mes_por_asesor[k]}).join(', ')}
            if(sll.mes_por_estado){datosCtx+='\nLLAMADAS MES POR TIPIFICACIÃ“N: '+Object.keys(sll.mes_por_estado).map(function(k){return k+':'+sll.mes_por_estado[k]}).join(', ')}
          }
          if(statsPacientes){
            var sp=statsPacientes
            datosCtx+='\n\n--- PACIENTES ---'
            datosCtx+='\nPACIENTES: total='+(sp.total||0)+' | nuevos este mes='+(sp.nuevos_mes||0)+' | activos (90d)='+(sp.activos_90d||0)+' | con compras='+(sp.con_compras||0)
            if(sp.por_estado){datosCtx+='\nPACIENTES POR ESTADO: '+Object.keys(sp.por_estado).map(function(k){return k+':'+sp.por_estado[k]}).join(', ')}
          }

          var systemPrompt = 'Eres KronIA, asistente AI de Zi Vital (clinica de medicina estetica, Lima, Peru). '+
            'Eres parte del equipo de Zi Vital, no un bot generico. Hablas natural, directo y cercano, como una colega que conoce el negocio. '+
            'Tono peruano profesional pero humano: nada de respuestas roboticas ni formales de mas. Si te saludan, saluda. Si te piden un dato, dalo al toque. '+
            'Respondes conciso por defecto, pero te extiendes cuando el tema lo amerita (un analisis, un script de venta, un plan). '+
            'Cuando pidan script o mensaje para cliente, escribe el dialogo natural listo para copiar.\\n\\n'+
            'COMO USAR TUS DATOS:\\n'+
            'Abajo en este prompt tienes secciones con datos REALES y actualizados de la clinica (LEADS, AGENDA/CITAS, LLAMADAS, PACIENTES, VENTAS, INVENTARIO, etc). '+
            'Esos son tus datos en vivo: usalos para responder con cifras concretas. Cuando te pregunten "cuantos leads este mes", "cuantas citas hoy", "como va la cartera", etc., '+
            'la respuesta esta en esas secciones â€” leela y respondela directo con el numero.\\n'+
            'REGLA DE ORO sobre acceso: NUNCA digas frases como "no tengo acceso" o "no puedo ver esa informacion" de forma seca. '+
            'Si el dato exacto NO aparece en las secciones de abajo, di con naturalidad: "Ese dato puntual no lo tengo cargado en este momento, pero puedo consultarlo si me das un poco mas de detalle" '+
            'o sugiere la forma de obtenerlo. La diferencia importa: tu SI tienes acceso al sistema, solo que a veces un dato muy especifico no esta pre-cargado en esta consulta.\\n\\n'+
            'ACCESO POR ROL: '+
            (esAdmin ?
              'Eres asistente del ADMIN (Cesar, dueno de la clinica): ACCESO TOTAL al ecosistema completo. '+
              'Tienes acceso explorador a 13 modulos: VENTAS (resumen/por asesor/sede/tratamiento/detalle), CITAS (hoy/futuras/por doctora/estado), '+
              'LLAMADAS (resumen/por asesor/estado), LEADS (mes/conversion/anuncios), PACIENTES (total/top facturadores/buscar), '+
              'COMISIONES (ranking mes/reglas), INVENTARIO (stock/alertas/por sede), EQUIPO (lista/sueldos/metas), '+
              'MARKETING (inversion mes/campanas/ROAS), FINANZAS (cajas/gastos/balance del mes), '+
              'ATENCIONES (flujo clinico por profesional), SEGUIMIENTOS (vencidos/por asesor), AGENDA FUTURA (proximos 7 dias). '+
              'En el contexto abajo veras los modulos que la pregunta pidio cargar â€” usa esos numeros para responder. '+
              'Si te falta un dato MUY especifico no pre-cargado (ej. nombre + DNI de cliente x), '+
              'di: "Dame un momento, voy a buscarlo" y propon una tool (search venta/paciente). '+
              'NUNCA digas "no tengo acceso" â€” si el dato no esta cargado, pide refinar la pregunta o ejecuta una tool.' :
              'Eres asistente de la asesora "'+usuario+'". Ve libremente: sus ventas, sus clientes y lo facturado con cada uno, sus comisiones, sus llamadas y metricas, '+
              'pacientes que gestiona, inventario, catalogo, precios, sus leads. Ademas tiene a la vista los totales operativos de la clinica (leads/citas/llamadas/pacientes del equipo) para que se ubique en el contexto general. '+
              'Responde con datos concretos: nombres, montos, fechas, tratamientos. '+
              'UNICO LIMITE REAL: las comisiones y el detalle de ventas de OTRA asesora en particular son privados. Si pide eso puntual, dile con buena onda: '+
              '"El detalle de comisiones de otra asesora es privado, pero los totales del equipo si te los puedo mostrar." Los totales globales del equipo si los puede ver.')+
            '\n\nCATALOGO:\n'+catResumen.substring(0,3500)+
            datosCtx+
            (insightsSofia && typeof insightsSofia === 'object' ? '\n\nINSIGHTS DE SOFIA (analista de datos):\n'+JSON.stringify(insightsSofia).substring(0,1500)+'\nUSA estos datos para responder sobre tendencias, LTV, cohortes, evolucion, conversion.' : '')+
            (esEjecucion && ventasEjecutor && ventasEjecutor.length ? '\n\nVENTAS RECIENTES (id es el campo CRÃTICO para editar):\n'+ventasEjecutor.map(function(v){return 'id:'+v.id+' | '+(v.nombres||'')+' '+(v.apellidos||'')+' | '+v.tratamiento+' | S/'+v.monto+' | '+v.fecha+' | '+v.estado_pago+' | asesor:'+v.asesor+' | cel:'+(v.numero_limpio||'')}).join('\n').substring(0,3500) : '')+
            (esEjecucion && segEjecutor && segEjecutor.length ? '\n\nSEGUIMIENTOS PENDIENTES (para mapear a IDs):\n'+segEjecutor.map(function(s){return 'ID:'+s.ID+' NUM:'+s.NUMERO+' '+s.TRATAMIENTO+' Â· fecha:'+s.FECHA_PROGRAMADA+' '+s.HORA_PROGRAMADA+' Â· asesor:'+s.ASESOR}).join('\n').substring(0,1500) : '')+
            (esEjecucion ? '\n\nâ•â•â•â•â•â•â• MODO EJECUTOR â•â•â•â•â•â•â•\nEl usuario quiere EDITAR algo. Tu trabajo: identificar la acciÃ³n, validar que tienes todos los datos, y proponer el JSON.\n\nREGLAS CRÃTICAS:\n1. NUNCA inventes IDs. Si no tienes el ID exacto del registro, primero pide info para identificarlo (nombre del cliente, fecha aproximada, nÃºmero de celular).\n2. NUNCA ejecutes â€” solo PROPONES con un JSON al final.\n3. Si la bÃºsqueda devuelve VARIAS coincidencias, lista las opciones y pide que elija cuÃ¡l.\n4. NUNCA digas \"ya estÃ¡ hecho\" o \"lo he modificado\" â€” eso es alucinaciÃ³n. Solo el JSON puede ejecutar.\n5. Si te faltan datos, pregunta primero. NO generes JSON con datos inventados.\n\nFormato de propuesta (al final de tu respuesta humana):\n```json\n{\n  "preview": "Voy a cambiar X de Y a Z",\n  "rpc": "aos_editar_venta",\n  "params": { ... }\n}\n```\n\nRPCs DISPONIBLES Y SUS PARAMS:\n\n1. EDITAR VENTA: aos_editar_venta(p_venta_id, p_campos)\n   - p_venta_id: id numÃ©rico de la venta (campo `id` de las ventas listadas)\n   - p_campos: objeto JSON con los campos a cambiar. Permitidos: fecha, monto, nombres, apellidos, dni, celular, tratamiento, descripcion, pago, estado_pago, asesor, atendio, sede, tipo, numero_limpio, nro_doc\n   - Ejemplo cambiar monto: { p_venta_id: 1583, p_campos: { monto: "6.95" } }\n   - Ejemplo cambiar fecha: { p_venta_id: 1583, p_campos: { fecha: "2026-05-14" } }\n   - Ejemplo cambiar varios: { p_venta_id: 1583, p_campos: { asesor: "MIREYA", monto: "500" } }\n\n2. EDITAR CITA: aos_kronia_editar_cita(p_cita_id, p_campos)\n   - p_cita_id: id numÃ©rico\n   - p_campos: { fecha_cita, hora_cita, nombre, tratamiento, asesor, sede, doctora, estado_cita }\n\n3. EDITAR PACIENTE: aos_kronia_editar_paciente(p_paciente_id, p_campos)\n   - p_paciente_id: id text del paciente\n   - p_campos: { nombres, apellidos, telefono, dni, email, numero_limpio, sede }\n\n4. REPROGRAMAR SEGUIMIENTO: aos_kronia_reprogramar_seguimiento(p_seg_id, p_nueva_fecha, p_nueva_hora)\n   - p_seg_id: ID del seguimiento (de la lista de seguimientos)\n   - p_nueva_fecha: "YYYY-MM-DD"\n   - p_nueva_hora: "HH:MM"\n\n5. MARCAR ESTADO CITA: aos_kronia_marcar_estado_cita(p_cita_id, p_nuevo_estado)\n   - p_cita_id: id\n   - p_nuevo_estado: uno de [POR LLAMAR, LLAMADA, ASISTIO, NO ASISTIO, REPROGRAMADA, CANCELADA, CONFIRMADA]\n\n6. AGREGAR NOTA PACIENTE: aos_kronia_agregar_nota_paciente(p_numero_paciente, p_nota)\n   - p_numero_paciente: nÃºmero de celular (solo dÃ­gitos)\n   - p_nota: texto de la nota\n\nNOTAS:\n- Estados vÃ¡lidos de pago: "PAGO COMPLETO", "ADELANTO", "PENDIENTE", "ANULADO"\n- Solo ADMIN puede reasignar ventas a otro asesor o editar ventas de otros asesores\n- Las bÃºsquedas en "VENTAS RECIENTES" del contexto te dan los IDs exactos.' : '')+
            '\nFecha: '+hoy+' | Sede: '+(sede||'N/A')

          var messages = [{ role: 'system', content: systemPrompt }]
          /* Historial: solo ultimos 8 turnos validos (4 intercambios) para mantener contexto sin saturar */
          var histLimpio = (historial || [])
            .filter(function(h){ return h && (h.role==='user'||h.role==='assistant') && h.content && String(h.content).trim() })
            .slice(-8)
          histLimpio.forEach(function(h) { messages.push({ role: h.role, content: String(h.content).slice(0,2000) }) })
          messages.push({ role: 'user', content: pregunta })

          sbGet('/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key&limit=1').then(function(rows) {
            var groqKey = rows && rows[0] ? rows[0].api_key : null
            if (!groqKey) { res.writeHead(400); res.end(JSON.stringify({error:'Groq key no encontrada'})); return }

            /* Funcion que llama a Groq con un modelo dado.
               Si recibe 429 (rate limit) y es el modelo 70B, hace fallback automatico a 8B-instant
               que tiene cuota separada. Asi nunca cae del todo. */
            function llamarGroq(modelo, intento){
              intento = intento || 1
              var groqBody = JSON.stringify({
                model: modelo,
                messages: messages,
                max_tokens: esEjecucion ? 1500 : (esAdmin ? 1500 : 900),
                temperature: esEjecucion ? 0.3 : (esAdmin ? 0.4 : 0.6)
              })
              var groqReq = https.request({
                hostname: 'api.groq.com', path: '/openai/v1/chat/completions', method: 'POST',
                headers: { 'Authorization': 'Bearer ' + groqKey, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(groqBody) }
              }, function(gRes) {
                var gData = ''; gRes.on('data', function(c) { gData += c }); gRes.on('end', function() {
                  /* FALLBACK 429: si el modelo grande hit rate limit, reintenta con el chico */
                  if (gRes.statusCode === 429 && modelo === 'llama-3.3-70b-versatile' && intento === 1) {
                    console.log('[KRONIA-CHAT] 70B hit rate limit, fallback a 8b-instant')
                    return llamarGroq('llama-3.1-8b-instant', 2)
                  }
                  procesarRespuestaGroq(gData, gRes.statusCode, modelo, groqBody.length)
                })
              })
              groqReq.on('error', function(err){
                console.error('[KRONIA-CHAT] Error de red Groq:', err.message)
                res.writeHead(200,{'Content-Type':'application/json'})
                res.end(JSON.stringify({ok:true, respuesta:'Error de conexiÃ³n con el modelo. ProbÃ¡ de nuevo.', provider:'groq', cost:0}))
              })
              groqReq.write(groqBody); groqReq.end()
            }

            /* Wrapper del parseo original. Recibe data + status + modelo usado + tamaÃ±o payload */
            function procesarRespuestaGroq(gData, statusCode, modeloUsado, payloadSize){
              try {
                var result = JSON.parse(gData)
                /* === DIAGNÃ“STICO: si la respuesta no tiene choices, loguear el error real === */
                if (!result.choices || !result.choices[0]) {
                  console.error('[KRONIA-CHAT] Groq sin choices. Status:', statusCode, 'Modelo:', modeloUsado)
                  console.error('[KRONIA-CHAT] Respuesta Groq:', JSON.stringify(result).slice(0, 1000))
                  console.error('[KRONIA-CHAT] Payload size:', payloadSize, 'bytes / System prompt:', systemPrompt.length, 'chars')
                  var errorMsg = 'No pude generar respuesta.'
                  if (result.error && result.error.message) {
                    /* Si es rate limit, mensaje amable */
                    if (statusCode === 429) {
                      errorMsg = 'LleguÃ© al lÃ­mite diario de consultas en este modelo. ProbÃ¡ una pregunta mÃ¡s simple o esperÃ¡ unos minutos.'
                    } else {
                      errorMsg = 'Error: ' + result.error.message.slice(0, 200)
                    }
                  } else if (statusCode === 413 || payloadSize > 30000) {
                    errorMsg = 'La consulta tiene demasiado contexto. HacÃ© una pregunta mÃ¡s especÃ­fica.'
                  } else if (statusCode >= 500) {
                    errorMsg = 'El modelo estÃ¡ saturado. ProbÃ¡ de nuevo en un momento.'
                  }
                  res.writeHead(200,{'Content-Type':'application/json'})
                  res.end(JSON.stringify({ok:true, respuesta: errorMsg, provider:'groq', cost:0, debug: {status: statusCode, modelo: modeloUsado}}))
                  return
                }
                var text = result.choices[0].message.content || ''
                if (!text && result.choices[0].message.tool_calls) {
                  console.error('[KRONIA-CHAT] Groq devolviÃ³ tool_calls sin content')
                  text = 'Necesito hacer una bÃºsqueda. Dame un momento... (modo herramientas)'
                }
                if (!text) {
                  console.error('[KRONIA-CHAT] content vacÃ­o. finish_reason:', result.choices[0].finish_reason)
                  text = 'No pude generar respuesta.'
                }
                  
                  // â•â•â• Extraer plan de acciÃ³n si estÃ¡ en modo ejecutor â•â•â•
                  var accionPropuesta = null
                  if (esEjecucion) {
                    var jsonMatch = text.match(/```(?:json)?\s*(\{[\s\S]*?\})\s*```/)
                    if (jsonMatch) {
                      try {
                        var parsed = JSON.parse(jsonMatch[1])
                        if (parsed.rpc && parsed.params) {
                          accionPropuesta = {
                            accion: parsed.accion || 'editar',
                            preview: parsed.preview || 'Confirma esta acciÃ³n',
                            rpc: parsed.rpc,
                            params: parsed.params
                          }
                          // Limpiar el JSON del texto visible (lo reemplazamos por el preview)
                          text = text.replace(/```(?:json)?\s*\{[\s\S]*?\}\s*```/, '').trim()
                          if (!text || text.length < 10) {
                            text = 'ðŸ“ ' + accionPropuesta.preview + '\n\nÂ¿Confirmas?'
                          } else {
                            text += '\n\nÂ¿Confirmas?'
                          }
                        }
                      } catch(e) { /* no es JSON vÃ¡lido, continuar */ }
                    }
                  }
                  
                  /* Guardar CADA mensaje en historial */
                  sbPost('/rest/v1/aos_kronia_conversaciones', {
                    usuario: usuario, rol: rol, sede: sede,
                    pregunta: pregunta.substring(0,500), respuesta: text.substring(0,2000),
                    session_id: sessionId, fue_exitosa: true,
                    metadata: JSON.stringify({model:esEjecucion?'llama-3.3-70b-versatile':'llama-3.1-8b-instant',tokens:result.usage||{},lead:leadActual||null,accion:accionPropuesta||null})
                  }).catch(function(){})

                  /* Registrar como ejecuciÃ³n del agente KronIA en aos_agente_logs */
                  sbPost('/rest/v1/aos_agente_logs', {
                    agente_id: 'kronia',
                    accion: esEjecucion ? (accionPropuesta ? 'proponer_accion' : 'chat_query') : 'chat_query',
                    input_resumen: pregunta.substring(0,150),
                    output_resumen: text.substring(0,200),
                    exitoso: true,
                    duracion_ms: (result.usage && result.usage.total_time) ? Math.round(result.usage.total_time*1000) : 0
                  }).catch(function(){})
                  /* Actualizar contador del agente KronIA */
                  sbRpc('aos_agente_registrar_ejecucion', { p_agente_id: 'kronia', p_exitoso: true }).catch(function(){})

                  res.writeHead(200, { 'Content-Type': 'application/json' })
                  var respPayload = { ok: true, respuesta: text, provider: 'groq', cost: 0 }
                  if (accionPropuesta) respPayload.accion_propuesta = accionPropuesta
                  res.end(JSON.stringify(respPayload))
                } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Parse error: '+e.message})) }
              } /* fin procesarRespuestaGroq */

            /* OPTIMIZACION SES-038: usar 8b-instant por default (cuota mucho mas alta,
               respuestas mas rapidas, libera conexiones Supabase antes). 70b solo para
               modo ejecutor (que requiere razonamiento complejo de tools). */
            var modeloInicial = esEjecucion ? 'llama-3.3-70b-versatile' : 'llama-3.1-8b-instant'
            llamarGroq(modeloInicial, 1)
          }).catch(function(e) { res.writeHead(500); res.end(JSON.stringify({error:'DB error'})) })
        }).catch(function(e) { res.writeHead(500); res.end(JSON.stringify({error:'Context error'})) })
  } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Error procesando: '+e.message})) }
}

// â•â•â• WEBHOOK VERIFY (GET) â•â•â•
function webhookVerify(req, res) {
  const u = new URL(req.url, 'http://localhost')
  const mode = u.searchParams.get('hub.mode')
  const token = u.searchParams.get('hub.verify_token')
  const challenge = u.searchParams.get('hub.challenge')
  if (mode === 'subscribe' && token === VERIFY_TOKEN) {
    console.log('[WH] Verified OK')
    res.writeHead(200, { 'Content-Type': 'text/plain' }); res.end(challenge)
  } else {
    console.log('[WH] Verify FAILED'); res.writeHead(403); res.end('Forbidden')
  }
}

// â•â•â• WEBHOOK MESSAGE (POST) â•â•â•
function webhookMessage(req, res) {
  let body = ''
  req.on('data', c => body += c)
  req.on('end', () => {
    res.writeHead(200); res.end('EVENT_RECEIVED')
    try {
      const p = JSON.parse(body)
      sbPost('/rest/v1/aos_webhook_log', { source: 'whatsapp', payload: p }).catch(() => {})
      var entries = p.entry || []
      for (var i = 0; i < entries.length; i++) {
        var changes = entries[i].changes || []
        for (var j = 0; j < changes.length; j++) {
          if (changes[j].field !== 'messages') continue
          var val = changes[j].value || {}
          var msgs = val.messages || [], contacts = val.contacts || []
          for (var k = 0; k < msgs.length; k++) {
            var msg = msgs[k], from = msg.from || ''
            var contact = null
            for (var c = 0; c < contacts.length; c++) { if (contacts[c].wa_id === from) { contact = contacts[c]; break } }
            var profileName = contact && contact.profile ? contact.profile.name || '' : ''
            var msgType = msg.type || 'text'
            var msgBody = ''
            if (msg.text) msgBody = msg.text.body || ''
            else if (msg.button) msgBody = msg.button.text || ''
            var campaignSource = '', adId = ''
            if (msg.referral) { campaignSource = msg.referral.headline || 'META_AD'; adId = msg.referral.source_id || '' }
            console.log('[WA]', from, profileName, msgType, (msgBody || '').substring(0, 40))
            sbPost('/rest/v1/aos_whatsapp_mensajes', {
              wa_message_id: msg.id || null, from_number: from, from_name: profileName,
              message_type: msgType, message_body: msgBody,
              timestamp_wa: msg.timestamp ? new Date(parseInt(msg.timestamp) * 1000).toISOString() : new Date().toISOString(),
              campaign_source: campaignSource || null, ad_id: adId || null, estado: 'NUEVO'
            }).catch(function(e) { console.error('[WA] Insert err:', e.message) })
          }
        }
      }
    } catch (e) { console.error('[WH] Parse err:', e.message) }
  })
}

// â•â•â• STATIC â•â•â•
function serve(f, res) {
  var mime = MIME[path.extname(f)] || 'text/plain'
  fs.stat(f, function(err, stat) {
    if (err) { res.writeHead(404); res.end('Not found'); return }
    res.writeHead(200, { 'Content-Type': mime, 'Content-Length': stat.size, 'Cache-Control': 'no-cache, no-store, must-revalidate', 'Pragma': 'no-cache', 'Expires': '0', 'ETag': stat.mtime.getTime().toString(36) })
    fs.createReadStream(f).pipe(res)
  })
}

// â•â•â• SERVER â•â•â•
http.createServer(function(req, res) {
  var p = req.url.split('?')[0]
  // F16: all admin Email writes and provider webhooks enter through a server-authoritative boundary.
  if (p === '/api/email-gateway') return EMAIL_GATEWAY.handleAdmin(req, res)
  if (p === '/api/send-email') return EMAIL_GATEWAY.handleAdmin(req, res)
  if (p === '/api/resend-webhook') return EMAIL_GATEWAY.handleWebhook(req, res)
  if (p === '/webhook' || p === '/webhook/') {
    if (req.method === 'GET') return webhookVerify(req, res)
    if (req.method === 'POST') return webhookMessage(req, res)
  }
  if (p === '/health') { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end('{"status":"ok"}'); return }
  // ===== TIPO DE CAMBIO PROXY =====
  if (p === '/api/tipo-cambio') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    https.get({ hostname: 'api.exchangerate-api.com', path: '/v4/latest/USD', headers: { 'User-Agent': 'AscendaOS/1.0' } }, function(apiRes) {
      var data = ''; apiRes.on('data', function(c) { data += c }); apiRes.on('end', function() {
        try {
          var j = JSON.parse(data); var pen = j.rates && j.rates.PEN ? j.rates.PEN : 3.70; var eur = j.rates && j.rates.EUR ? j.rates.EUR : 0.92; var penEur = pen / eur; var compra = (pen - 0.03).toFixed(3); var venta = (pen + 0.03).toFixed(3)
          res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ compra: compra, venta: venta, euro_venta: penEur.toFixed(3), source: 'exchangerate-api' }))
        } catch(e) { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end('{"compra":"3.695","venta":"3.750","euro_venta":"4.020","source":"fallback"}') }
      })
    }).on('error', function() { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end('{"compra":"3.695","venta":"3.750","euro_venta":"4.020","source":"fallback"}') }); return
  }
  // ===== FIN TIPO DE CAMBIO =====
  // â•â•â• STUDIO API â€” GENERACIÃ“N DE IMÃGENES (Gemini GRATIS + OpenAI fallback) â•â•â•
  if (p === '/api/studio/generate-image' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        var prompt = d.prompt || 'Professional medical aesthetic clinic Instagram post'
        var provider = d.provider || 'auto' /* auto, gemini, openai */
        
        /* Leer keys de Supabase integraciones */
        function getKey(tipo, cb) {
          https.get({
            hostname: 'ituyqwstonmhnfshnaqz.supabase.co',
            path: '/rest/v1/aos_integraciones?tipo=eq.' + tipo + '&estado=eq.conectado&select=api_key&limit=1',
            headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }
          }, function(r) {
            var data = ''; r.on('data', function(c) { data += c }); r.on('end', function() {
              try { var rows = JSON.parse(data); cb(rows && rows[0] ? rows[0].api_key : null) } catch(e) { cb(null) }
            })
          }).on('error', function() { cb(null) })
        }
        
        function tryGemini(geminiKey) {
          var geminiBody = JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { responseModalities: ['TEXT', 'IMAGE'] }
          })
          var gemReq = https.request({
            hostname: 'generativelanguage.googleapis.com',
            path: '/v1beta/models/gemini-2.5-flash-image:generateContent?key=' + geminiKey,
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(geminiBody) }
          }, function(gRes) {
            var gData = ''; gRes.on('data', function(c) { gData += c }); gRes.on('end', function() {
              try {
                var result = JSON.parse(gData)
                if (result.candidates && result.candidates[0] && result.candidates[0].content) {
                  var parts = result.candidates[0].content.parts || []
                  var imgPart = parts.find(function(p) { return p.inlineData })
                  var textPart = parts.find(function(p) { return p.text })
                  if (imgPart && imgPart.inlineData) {
                    /* Subir imagen a Supabase Storage */
                    var imgBuffer = Buffer.from(imgPart.inlineData.data, 'base64')
                    var fname = 'ai-' + Date.now() + '.png'
                    var uploadReq = https.request({
                      hostname: 'ituyqwstonmhnfshnaqz.supabase.co',
                      path: '/storage/v1/object/studio-assets/' + fname,
                      method: 'POST',
                      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'image/png', 'Content-Length': imgBuffer.length }
                    }, function(uRes) {
                      var uData = ''; uRes.on('data', function(c) { uData += c }); uRes.on('end', function() {
                        var url = 'https://ituyqwstonmhnfshnaqz.supabase.co/storage/v1/object/public/studio-assets/' + fname
                        res.writeHead(200, { 'Content-Type': 'application/json' })
                        res.end(JSON.stringify({ success: true, url: url, provider: 'gemini', text: textPart ? textPart.text : '', cost: 0 }))
                      })
                    })
                    uploadReq.on('error', function() {
                      /* Si falla upload, devolver base64 directamente */
                      res.writeHead(200, { 'Content-Type': 'application/json' })
                      res.end(JSON.stringify({ success: true, image_base64: imgPart.inlineData.data, provider: 'gemini', cost: 0 }))
                    })
                    uploadReq.write(imgBuffer); uploadReq.end()
                  } else {
                    res.writeHead(200, { 'Content-Type': 'application/json' })
                    res.end(JSON.stringify({ success: false, error: 'Gemini no generÃ³ imagen. Respuesta: ' + (textPart ? textPart.text.substring(0, 200) : 'sin texto'), provider: 'gemini' }))
                  }
                } else {
                  res.writeHead(400, { 'Content-Type': 'application/json' })
                  res.end(JSON.stringify({ error: 'Gemini error', details: gData.substring(0, 300) }))
                }
              } catch(e) { res.writeHead(500); res.end(JSON.stringify({error: 'Parse error: ' + e.message})) }
            })
          })
          gemReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error: e.message})) })
          gemReq.write(geminiBody); gemReq.end()
        }
        
        function tryOpenAI(openaiKey) {
          var imageData = JSON.stringify({ model: 'gpt-image-1', prompt: prompt, n: 1, size: '1024x1024', quality: 'medium' })
          var imgReq = https.request({
            hostname: 'api.openai.com', path: '/v1/images/generations', method: 'POST',
            headers: { 'Authorization': 'Bearer ' + openaiKey, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(imageData) }
          }, function(imgRes) {
            var iData = ''; imgRes.on('data', function(c) { iData += c }); imgRes.on('end', function() {
              try {
                var result = JSON.parse(iData)
                if (result.data && result.data[0]) {
                  res.writeHead(200, { 'Content-Type': 'application/json' })
                  res.end(JSON.stringify({ success: true, url: result.data[0].url || '', image_base64: result.data[0].b64_json || '', provider: 'openai', cost: 0.04 }))
                } else {
                  res.writeHead(400); res.end(JSON.stringify({ error: 'OpenAI no generÃ³ imagen', details: result }))
                }
              } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Parse error'})) }
            })
          })
          imgReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
          imgReq.write(imageData); imgReq.end()
        }
        
        /* Auto: primero Gemini (gratis), luego OpenAI */
        if (provider === 'openai') {
          getKey('api', function(k) { /* OpenAI tipo es 'api' con nombre OpenAI */
            var key = k || process.env.OPENAI_API_KEY
            if (!key) { res.writeHead(400); res.end(JSON.stringify({error:'OpenAI API key no configurada'})); return }
            tryOpenAI(key)
          })
        } else {
          getKey('gemini', function(gemKey) {
            if (gemKey) { tryGemini(gemKey); return }
            /* Fallback a OpenAI */
            getKey('api', function(oaiKey) {
              var key = oaiKey || process.env.OPENAI_API_KEY
              if (key) { tryOpenAI(key); return }
              res.writeHead(400); res.end(JSON.stringify({error:'No hay API de imagen configurada. Configura Gemini o OpenAI en ConfiguraciÃ³n â†’ Integraciones.'}))
            })
          })
        }
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:'Invalid JSON'})) }
    }); return
  }
  // â•â•â• STUDIO API â€” GENERAR COPY CON AI (Groq GRATIS + Claude fallback) â•â•â•
  if (p === '/api/studio/generate-copy' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        var prompt = d.prompt || ''
        var system = d.system || 'Eres el agente creativo de Zi Vital, clÃ­nica de medicina estÃ©tica en Lima, PerÃº. Generas copy para redes sociales en espaÃ±ol. Tono elegante y cercano.'
        
        /* Leer key de Groq */
        https.get({
          hostname: 'ituyqwstonmhnfshnaqz.supabase.co',
          path: '/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key&limit=1',
          headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }
        }, function(r) {
          var data = ''; r.on('data', function(c) { data += c }); r.on('end', function() {
            try {
              var rows = JSON.parse(data)
              var groqKey = rows && rows[0] ? rows[0].api_key : null
              if (!groqKey) { res.writeHead(400); res.end(JSON.stringify({error:'Groq key no encontrada'})); return }
              
              var groqBody = JSON.stringify({
                model: 'llama-3.3-70b-versatile',
                messages: [{ role: 'system', content: system }, { role: 'user', content: prompt }],
                max_tokens: 800, temperature: 0.7
              })
              var groqReq = https.request({
                hostname: 'api.groq.com', path: '/openai/v1/chat/completions', method: 'POST',
                headers: { 'Authorization': 'Bearer ' + groqKey, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(groqBody) }
              }, function(gRes) {
                var gData = ''; gRes.on('data', function(c) { gData += c }); gRes.on('end', function() {
                  try {
                    var result = JSON.parse(gData)
                    var text = result.choices && result.choices[0] ? result.choices[0].message.content : ''
                    res.writeHead(200, { 'Content-Type': 'application/json' })
                    res.end(JSON.stringify({ success: true, text: text, provider: 'groq', cost: 0 }))
                  } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Parse error'})) }
                })
              })
              groqReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
              groqReq.write(groqBody); groqReq.end()
            } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Key lookup error'})) }
          })
        }).on('error', function() { res.writeHead(500); res.end(JSON.stringify({error:'DB connection error'})) })
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:'Invalid JSON'})) }
    }); return
  }
  // â•â•â• KRONIA EXT â€” CORS PREFLIGHT GLOBAL para /api/kronia/* â•â•â•
  if (req.method === 'OPTIONS' && p.startsWith('/api/kronia/')) {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST,GET,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-AOS-User, X-AOS-Id, X-Kronia-Token'
    })
    res.end(); return
  }

  // â•â•â• KRONIA EXT â€” STEP 1: REQUEST CODE (envia codigo 2FA al email) â•â•â•
  // POST /api/kronia/login-request  { usuario }
  // Reutiliza aos_login_v2 que ya envia codigo por email
  if (p === '/api/kronia/login-request' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c){ body += c }); req.on('end', function(){
      try {
        var d = JSON.parse(body)
        var usuario = (d.usuario || '').trim()
        if (!usuario) { res.writeHead(400); res.end(JSON.stringify({ok:false, error:'Usuario requerido'})); return }
        sbRpc('aos_login_v2', { p_usuario: usuario, p_origen: 'chrome_extension' }).then(function(r){
          var out = Array.isArray(r) ? r[0] : r
          res.writeHead(200, {'Content-Type':'application/json'})
          res.end(JSON.stringify(out || {ok:false, error:'Sin respuesta del servidor'}))
        }).catch(function(e){
          res.writeHead(500); res.end(JSON.stringify({ok:false, error:'Error solicitando codigo: '+(e.message||e)}))
        })
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({ok:false, error:'JSON invalido'})) }
    }); return
  }

  // â•â•â• KRONIA EXT â€” STEP 2: VERIFY CODE & EMIT TOKEN â•â•â•
  // POST /api/kronia/login-verify  { usuario, codigo }
  // Valida el codigo 2FA y emite token de 24h
  if (p === '/api/kronia/login-verify' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c){ body += c }); req.on('end', function(){
      try {
        var d = JSON.parse(body)
        var usuario = (d.usuario || '').trim()
        var codigo = (d.codigo || '').trim()
        var deviceInfo = (d.device_info || '').slice(0,200)
        var ipOrigen = req.headers['x-forwarded-for'] || req.connection.remoteAddress || ''
        if (!usuario || !codigo) { res.writeHead(400); res.end(JSON.stringify({ok:false, error:'usuario y codigo requeridos'})); return }
        // Paso 1: validar codigo 2FA
        sbRpc('aos_verificar_2fa', { p_usuario: usuario, p_codigo: codigo }).then(function(r2){
          var v = Array.isArray(r2) ? r2[0] : r2
          if (!v || !v.ok) {
            res.writeHead(401); res.end(JSON.stringify({ok:false, error:(v && v.error) || 'Codigo invalido'})); return
          }
          // Paso 2: emitir token de extension
          sbRpc('aos_kronia_emitir_token', {
            p_usuario: v.usuario || usuario,
            p_id_asesor: v.id_asesor || v.codigo_asesor || null,
            p_rol: v.rol || 'ASESOR',
            p_sede: v.sede || null,
            p_email: v.email || null,
            p_device_info: deviceInfo,
            p_ip_origen: String(ipOrigen).slice(0,80)
          }).then(function(rt){
            var t = Array.isArray(rt) ? rt[0] : rt
            res.writeHead(200, {'Content-Type':'application/json'})
            res.end(JSON.stringify(t || {ok:false, error:'No se pudo emitir token'}))
          }).catch(function(e){
            res.writeHead(500); res.end(JSON.stringify({ok:false, error:'Error emitiendo token: '+(e.message||e)}))
          })
        }).catch(function(e){
          res.writeHead(500); res.end(JSON.stringify({ok:false, error:'Error validando codigo: '+(e.message||e)}))
        })
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({ok:false, error:'JSON invalido'})) }
    }); return
  }

  // â•â•â• KRONIA EXT â€” VERIFY TOKEN (refresca sesion) â•â•â•
  // GET /api/kronia/verify  con header Authorization: Bearer <token>
  if (p === '/api/kronia/verify' && req.method === 'GET') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var authHeader = req.headers['authorization'] || ''
    var tok = authHeader.replace(/^Bearer\s+/i,'').trim()
    if (!tok) { res.writeHead(401); res.end(JSON.stringify({ok:false, error:'Token requerido'})); return }
    sbRpc('aos_kronia_verify_token', { p_token: tok }).then(function(r){
      var v = Array.isArray(r) ? r[0] : r
      res.writeHead(v && v.ok ? 200 : 401, {'Content-Type':'application/json'})
      res.end(JSON.stringify(v || {ok:false, error:'Sin respuesta'}))
    }).catch(function(e){
      res.writeHead(500); res.end(JSON.stringify({ok:false, error:'Error: '+(e.message||e)}))
    })
    return
  }

  // â•â•â• KRONIA EXT â€” LOGOUT (revoca token) â•â•â•
  if (p === '/api/kronia/logout' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var authHeader2 = req.headers['authorization'] || ''
    var tok2 = authHeader2.replace(/^Bearer\s+/i,'').trim()
    if (!tok2) { res.writeHead(400); res.end(JSON.stringify({ok:false, error:'Token requerido'})); return }
    sbRpc('aos_kronia_revocar_token', { p_token: tok2 }).then(function(r){
      var v = Array.isArray(r) ? r[0] : r
      res.writeHead(200, {'Content-Type':'application/json'})
      res.end(JSON.stringify(v || {ok:false}))
    }).catch(function(e){
      res.writeHead(500); res.end(JSON.stringify({ok:false, error:'Error: '+(e.message||e)}))
    })
    return
  }

  // â•â•â• KRONIA CHAT â€” AI ASESOR CON CONTROL DE ROLES â•â•â•
  // Soporta dos modos de auth:
  //   1) BEARER TOKEN (extension Chrome): header Authorization: Bearer <tok>
  //      â†’ datos del usuario salen del token (mas seguro: no se pueden suplantar)
  //   2) BODY (chat interno / Brain): body con {usuario, id_asesor, rol, sede}
  //      â†’ flujo legado, valida que el usuario exista en aos_usuarios
  if (p === '/api/kronia/chat' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var bearerHeader = req.headers['authorization'] || ''
    var bearerTok = bearerHeader.replace(/^Bearer\s+/i,'').trim()
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        var pregunta = (d.pregunta || '').trim()

        // â•â•â• MODO 1: Bearer token (extension) â•â•â•
        if (bearerTok) {
          sbRpc('aos_kronia_verify_token', { p_token: bearerTok }).then(function(rt){
            var v = Array.isArray(rt) ? rt[0] : rt
            if (!v || !v.ok) {
              res.writeHead(401); res.end(JSON.stringify({error: (v && v.error) || 'Token invalido o expirado'})); return
            }
            // Datos del usuario salen del token (no del body, mas seguro)
            d.usuario = v.usuario
            d.id_asesor = v.id_asesor
            d.rol = v.rol
            d.sede = v.sede || d.sede || ''
            procesarKroniaChat(d, pregunta, v.usuario, v.rol, d.sede, d.session_id || '', res)
          }).catch(function(e){
            res.writeHead(500); res.end(JSON.stringify({error:'Error validando token: '+(e.message||e)}))
          })
          return
        }

        // â•â•â• MODO 2: legado (chat interno / Brain) â•â•â•
        var usuario = d.usuario || ''
        var rol = d.rol || 'asesor'
        var sede = d.sede || ''
        var sessionId = d.session_id || ''
        validarSesionKronia(usuario, d.id_asesor || '').then(function(valido) {
          if (!valido) { res.writeHead(401); res.end(JSON.stringify({error:'Sesion no autorizada'})); return }
          procesarKroniaChat(d, pregunta, usuario, rol, sede, sessionId, res)
        }).catch(function() { res.writeHead(500); res.end(JSON.stringify({error:'Error validando sesion'})) })
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:'Invalid JSON'})) }
    }); return
  }
  // â•â•â• KRONIA WHISPER â€” VOICE TO TEXT â•â•â•
  // Acepta Bearer token (extension) o header X-AOS-User (flujo legado)
  if (p === '/api/kronia/whisper' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var bearerW = (req.headers['authorization']||'').replace(/^Bearer\s+/i,'').trim()
    var authUser = req.headers['x-aos-user'] || ''
    var authId = req.headers['x-aos-id'] || ''
    var chunks = []; req.on('data', function(c) { chunks.push(c) }); req.on('end', function() {
      if (bearerW) {
        sbRpc('aos_kronia_verify_token', { p_token: bearerW }).then(function(rt){
          var v = Array.isArray(rt) ? rt[0] : rt
          if (!v || !v.ok) { res.writeHead(401); res.end(JSON.stringify({error:(v&&v.error)||'Token invalido'})); return }
          procesarWhisper(chunks, res)
        }).catch(function(){ res.writeHead(500); res.end(JSON.stringify({error:'Error validando token'})) })
        return
      }
      if (!authUser) { res.writeHead(401); res.end(JSON.stringify({error:'Falta auth (Bearer o X-AOS-User)'})); return }
      validarSesionKronia(authUser, authId).then(function(valido) {
        if (!valido) { res.writeHead(401); res.end(JSON.stringify({error:'Sesion no autorizada'})); return }
        procesarWhisper(chunks, res)
      })
    })
    return
  }

  if (p === '/api/studio/publish-instagram' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        var IG_TOKEN = process.env.INSTAGRAM_ACCESS_TOKEN
        var IG_USER_ID = process.env.INSTAGRAM_USER_ID
        if (!IG_TOKEN || !IG_USER_ID) { res.writeHead(500); res.end(JSON.stringify({error:'Instagram credentials not configured. Set INSTAGRAM_ACCESS_TOKEN and INSTAGRAM_USER_ID in Railway.'})); return }
        var image_url = d.image_url
        var caption = d.caption || ''
        if (!image_url) { res.writeHead(400); res.end(JSON.stringify({error:'image_url required (must be publicly accessible URL)'})); return }
        /* Step 1: Create media container */
        var containerData = 'image_url=' + encodeURIComponent(image_url) + '&caption=' + encodeURIComponent(caption) + '&access_token=' + encodeURIComponent(IG_TOKEN)
        var containerReq = https.request({
          hostname: 'graph.facebook.com', path: '/v22.0/' + IG_USER_ID + '/media?' + containerData, method: 'POST',
          headers: { 'Content-Length': 0 }
        }, function(cRes) {
          var cData = ''; cRes.on('data', function(c) { cData += c }); cRes.on('end', function() {
            try {
              var container = JSON.parse(cData)
              if (!container.id) { res.writeHead(400); res.end(JSON.stringify({error:'Container creation failed',details:container})); return }
              /* Step 2: Publish the container */
              var publishData = 'creation_id=' + container.id + '&access_token=' + encodeURIComponent(IG_TOKEN)
              var publishReq = https.request({
                hostname: 'graph.facebook.com', path: '/v22.0/' + IG_USER_ID + '/media_publish?' + publishData, method: 'POST',
                headers: { 'Content-Length': 0 }
              }, function(pRes) {
                var pData = ''; pRes.on('data', function(c) { pData += c }); pRes.on('end', function() {
                  try {
                    var pub = JSON.parse(pData)
                    res.writeHead(200, { 'Content-Type': 'application/json' })
                    res.end(JSON.stringify({ success: true, media_id: pub.id, container_id: container.id }))
                  } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Publish parse error'})) }
                })
              })
              publishReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
              publishReq.end()
            } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Container parse error'})) }
          })
        })
        containerReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
        containerReq.end()
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:'Invalid JSON'})) }
    }); return
  }
  // â•â•â• STUDIO API â€” PUBLISH TO FACEBOOK â•â•â•
  if (p === '/api/studio/publish-facebook' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        var FB_TOKEN = process.env.FACEBOOK_ACCESS_TOKEN
        var FB_PAGE_ID = process.env.FACEBOOK_PAGE_ID
        if (!FB_TOKEN || !FB_PAGE_ID) { res.writeHead(500); res.end(JSON.stringify({error:'Facebook credentials not configured'})); return }
        var postData = JSON.stringify({ message: d.caption || '', url: d.image_url || '', access_token: FB_TOKEN })
        var endpoint = d.image_url ? '/' + FB_PAGE_ID + '/photos' : '/' + FB_PAGE_ID + '/feed'
        var fbReq = https.request({
          hostname: 'graph.facebook.com', path: '/v22.0' + endpoint, method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(postData) }
        }, function(fbRes) {
          var fbData = ''; fbRes.on('data', function(c) { fbData += c }); fbRes.on('end', function() {
            res.writeHead(200, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ success: true, result: JSON.parse(fbData) }))
          })
        })
        fbReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
        fbReq.write(postData); fbReq.end()
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:'Invalid JSON'})) }
    }); return
  }
  // â•â•â• STUDIO CORS PREFLIGHT â•â•â•
  if (req.method === 'OPTIONS' && p.startsWith('/api/studio/')) {
    res.writeHead(204, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST,GET,OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }
  // â•â•â• STUDIO API â€” PULL MÃ‰TRICAS INSTAGRAM â•â•â•
  if (p === '/api/studio/metrics-instagram' && req.method === 'GET') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var IG_TOKEN = process.env.INSTAGRAM_ACCESS_TOKEN
    var IG_USER_ID = process.env.INSTAGRAM_USER_ID
    if (!IG_TOKEN || !IG_USER_ID) { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({error:'Instagram not configured',configured:false})); return }
    /* Get recent media with insights */
    https.get({
      hostname: 'graph.facebook.com',
      path: '/v22.0/' + IG_USER_ID + '/media?fields=id,caption,media_type,timestamp,like_count,comments_count,permalink&limit=25&access_token=' + encodeURIComponent(IG_TOKEN)
    }, function(igRes) {
      var data = ''; igRes.on('data', function(c) { data += c }); igRes.on('end', function() {
        try {
          var result = JSON.parse(data)
          res.writeHead(200, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify({ success: true, posts: result.data || [], configured: true }))
        } catch(e) { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({error:'Parse error',configured:true})) }
      })
    }).on('error', function(e) { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({error:e.message,configured:true})) })
    return
  }
  // â•â•â• STUDIO â€” PUBLICAR A LINKEDIN â•â•â•
  if (p === '/api/studio/publish-linkedin' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        var LI_TOKEN = process.env.LINKEDIN_ACCESS_TOKEN
        var LI_ORG = process.env.LINKEDIN_ORG_ID
        if (!LI_TOKEN) { res.writeHead(500); res.end(JSON.stringify({error:'LINKEDIN_ACCESS_TOKEN not configured'})); return }
        var author = LI_ORG ? 'urn:li:organization:' + LI_ORG : 'urn:li:person:me'
        var postData = JSON.stringify({
          author: author,
          commentary: d.caption || d.copy || '',
          visibility: 'PUBLIC',
          distribution: { feedDistribution: 'MAIN_FEED' },
          lifecycleState: 'PUBLISHED'
        })
        var liReq = https.request({
          hostname: 'api.linkedin.com', path: '/rest/posts', method: 'POST',
          headers: { 'Authorization': 'Bearer ' + LI_TOKEN, 'Content-Type': 'application/json', 'X-Restli-Protocol-Version': '2.0.0', 'LinkedIn-Version': '202508', 'Content-Length': Buffer.byteLength(postData) }
        }, function(liRes) {
          var liData = ''; liRes.on('data', function(c) { liData += c }); liRes.on('end', function() {
            var postId = liRes.headers['x-restli-id'] || ''
            res.writeHead(liRes.statusCode === 201 ? 200 : 400, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ success: liRes.statusCode === 201, post_id: postId, status: liRes.statusCode }))
          })
        })
        liReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
        liReq.write(postData); liReq.end()
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:'Invalid JSON'})) }
    }); return
  }
  // â•â•â• STUDIO â€” PUBLICAR CARRUSEL A INSTAGRAM â•â•â•
  if (p === '/api/studio/publish-instagram-carousel' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        var IG_TOKEN = process.env.INSTAGRAM_ACCESS_TOKEN
        var IG_USER_ID = process.env.INSTAGRAM_USER_ID
        if (!IG_TOKEN || !IG_USER_ID) { res.writeHead(500); res.end(JSON.stringify({error:'Instagram not configured'})); return }
        var images = d.image_urls || []
        if (images.length < 2) { res.writeHead(400); res.end(JSON.stringify({error:'Carousel needs 2+ images'})); return }
        /* Step 1: Create children containers */
        var childIds = []; var childDone = 0
        images.forEach(function(imgUrl) {
          var childData = 'image_url=' + encodeURIComponent(imgUrl) + '&is_carousel_item=true&access_token=' + encodeURIComponent(IG_TOKEN)
          var childReq = https.request({
            hostname: 'graph.facebook.com', path: '/v22.0/' + IG_USER_ID + '/media?' + childData, method: 'POST',
            headers: { 'Content-Length': 0 }
          }, function(cRes) {
            var cData = ''; cRes.on('data', function(c2) { cData += c2 }); cRes.on('end', function() {
              try { var r = JSON.parse(cData); if (r.id) childIds.push(r.id) } catch(e) {}
              childDone++
              if (childDone === images.length) {
                /* Step 2: Create carousel container */
                var carouselData = 'media_type=CAROUSEL&children=' + childIds.join(',') + '&caption=' + encodeURIComponent(d.caption || '') + '&access_token=' + encodeURIComponent(IG_TOKEN)
                var carReq = https.request({
                  hostname: 'graph.facebook.com', path: '/v22.0/' + IG_USER_ID + '/media?' + carouselData, method: 'POST',
                  headers: { 'Content-Length': 0 }
                }, function(caRes) {
                  var caData = ''; caRes.on('data', function(c3) { caData += c3 }); caRes.on('end', function() {
                    try {
                      var container = JSON.parse(caData)
                      if (!container.id) { res.writeHead(400); res.end(JSON.stringify({error:'Carousel container failed',details:container})); return }
                      /* Step 3: Publish */
                      var pubData = 'creation_id=' + container.id + '&access_token=' + encodeURIComponent(IG_TOKEN)
                      var pubReq = https.request({
                        hostname: 'graph.facebook.com', path: '/v22.0/' + IG_USER_ID + '/media_publish?' + pubData, method: 'POST',
                        headers: { 'Content-Length': 0 }
                      }, function(pRes) {
                        var pData = ''; pRes.on('data', function(c4) { pData += c4 }); pRes.on('end', function() {
                          try { var pub = JSON.parse(pData); res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ success: true, media_id: pub.id })) }
                          catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Publish error'})) }
                        })
                      })
                      pubReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
                      pubReq.end()
                    } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Container error'})) }
                  })
                })
                carReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
                carReq.end()
              }
            })
          })
          childReq.on('error', function() { childDone++; if(childDone===images.length) { res.writeHead(500); res.end(JSON.stringify({error:'Child upload failed'})) } })
          childReq.end()
        })
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:'Invalid JSON'})) }
    }); return
  }
  // â•â•â• STUDIO â€” ESTADO DE CONEXIONES â•â•â•
  if (p === '/api/studio/connections' && req.method === 'GET') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var connData = JSON.stringify({
      instagram: { configured: !!(process.env.INSTAGRAM_ACCESS_TOKEN && process.env.INSTAGRAM_USER_ID), has_token: !!process.env.INSTAGRAM_ACCESS_TOKEN },
      facebook: { configured: !!(process.env.FACEBOOK_ACCESS_TOKEN && process.env.FACEBOOK_PAGE_ID), has_token: !!process.env.FACEBOOK_ACCESS_TOKEN },
      linkedin: { configured: !!process.env.LINKEDIN_ACCESS_TOKEN, has_token: !!process.env.LINKEDIN_ACCESS_TOKEN },
      tiktok: { configured: !!process.env.TIKTOK_ACCESS_TOKEN, has_token: !!process.env.TIKTOK_ACCESS_TOKEN },
      openai: { configured: !!process.env.OPENAI_API_KEY }
    })
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(connData); return
  }
  // â•â•â• FIN STUDIO API â•â•â•
  // ===== F16 EMAIL ADMIN SEND =====
  // Handled above by EMAIL_GATEWAY with authoritative admin session verification.
  // ===== F16 LEGACY 2FA RETIRED =====
  // Current Auth V3 sends 2FA inside aos_login_v3. This legacy public provider path is closed.
  if (p === '/api/send-2fa') {
    res.writeHead(410, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' })
    res.end(JSON.stringify({ ok:false, error:'LEGACY_2FA_RETIRED' })); return
  }
  // ===== FIN F16 LEGACY 2FA =====
  // ===== TEMPLATE EMAILS (confirmaciÃ³n cita, recibo venta, seguimiento) =====
  if (p === '/api/send-template' && req.method === 'POST') {
    var templateToken = String(req.headers['x-ascenda-session'] || '')
    EMAIL_GATEWAY.verifyApp(templateToken).then(function(templateAuth) {
      if (!templateAuth || templateAuth.ok !== true) {
        res.writeHead(401, { 'Content-Type':'application/json', 'Cache-Control':'no-store' })
        res.end(JSON.stringify({ok:false,error:'UNAUTHORIZED'})); return
      }
      var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        if (!d.to || !d.template) { res.writeHead(400); res.end('{"error":"missing to/template"}'); return }
        var html = '', subject = '', tipo = d.template
        // F16: template endpoint is transactional only. Marketing must use governed activation/consent.
        if (EMAILS_TRANSACCIONALES.indexOf(String(tipo || '')) === -1) {
          res.writeHead(403, { 'Content-Type':'application/json', 'Cache-Control':'no-store' })
          res.end(JSON.stringify({ok:false,error:'GOVERNED_ACTIVATION_REQUIRED',template:String(tipo||'')})); return
        }
        // Construir variables para la plantilla
        var vars = { nombre: d.nombre||'Paciente', tratamiento: d.tratamiento||'', fecha: d.fecha||'', hora: d.hora||'', sede: d.sede||'', fecha_cita: d.fecha||d.fecha_cita||'', hora_cita: d.hora||d.hora_cita||'', monto: d.monto ? parseFloat(d.monto).toFixed(2) : '', metodo_pago: d.metodo_pago||d.metodo||'', saldo_actual: d.saldo_actual ? parseFloat(d.saldo_actual).toFixed(2) : '0.00', ultimo_tratamiento: d.ultimo_tratamiento||'', dias: d.dias||'', dias_sin_visita: d.dias_sin_visita||d.dias||'', ultima_fecha: d.ultima_fecha||'', catalogo_items: d.catalogo_items||'', pagados: d.pagados||'', dni: d.dni||'', email: d.email||d.to||'', telefono: d.telefono||'', venta_id: d.venta_id||'' }

        // Construir tabla de items dinÃ¡mica para recibo/cotizaciÃ³n
        if (d.items && d.items.length) {
          var sym = (d.moneda === 'USD') ? '$ ' : 'S/ '
          var itemsHtml = ''
          var totalCalc = 0
          d.items.forEach(function(it) {
            var sub = parseFloat(it.subtotal || it.monto || 0)
            totalCalc += sub
            itemsHtml += '<tr style="border-bottom:1px solid #F1F5F9">' +
              '<td style="padding:10px 12px;font-size:13px;color:#334155">' + (it.nombre || it.tratamiento || '') + '</td>' +
              '<td style="padding:10px 12px;font-size:13px;text-align:center;color:#64748B">' + (it.cantidad || 1) + '</td>' +
              '<td style="padding:10px 12px;font-size:13px;text-align:right;font-weight:600;color:#334155">' + sym + sub.toFixed(2) + '</td></tr>'
          })
          vars.items_tabla = '<table style="width:100%;border-collapse:collapse;margin-bottom:16px">' +
            '<thead><tr style="background:' + BRAND.color_primario + '">' +
            '<th style="padding:10px 12px;text-align:left;font-size:11px;font-weight:700;color:#64748B;text-transform:uppercase">Servicio / Producto</th>' +
            '<th style="padding:10px 12px;text-align:center;font-size:11px;font-weight:700;color:#64748B;text-transform:uppercase">Cant.</th>' +
            '<th style="padding:10px 12px;text-align:right;font-size:11px;font-weight:700;color:#64748B;text-transform:uppercase">Subtotal</th>' +
            '</tr></thead><tbody>' + itemsHtml + '</tbody>' +
            '<tfoot><tr style="background:' + BRAND.color_primario + '">' +
            '<td colspan="2" style="padding:12px;text-align:right;font-size:14px;font-weight:700;color:#334155">TOTAL</td>' +
            '<td style="padding:12px;text-align:right;font-size:16px;font-weight:800;color:' + BRAND.color_secundario + '">' + sym + (parseFloat(d.total || totalCalc)).toFixed(2) + '</td>' +
            '</tr></tfoot></table>'
          // Si no hay tratamiento individual, usar lista de nombres
          if (!vars.tratamiento) {
            vars.tratamiento = d.items.map(function(it) { return it.nombre || it.tratamiento || '' }).join(', ')
          }
          if (!vars.monto) {
            vars.monto = (parseFloat(d.total || totalCalc)).toFixed(2)
          }
        } else {
          vars.items_tabla = ''
        }

        // Contexto de segmentaciÃ³n para plantillas inteligentes
        var tplCtx = { segmento: d.segmento || '', tipo_tratamiento: d.tipo_tratamiento || '' }
        
        if (tipo === 'confirmacion_cita') {
          subject = 'âœ… Cita confirmada â€” ' + (d.sede || '') + ' Â· ' + (d.hora || '') + ' â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('confirmacion_cita', vars, function() { return buildEmailConfirmacionCita(d.nombre||'Paciente', d.tratamiento||'Consulta', d.hora||'', d.sede||'', d.fecha||'', {dni: d.dni, email: d.email || d.to, telefono: d.telefono}) }, tplCtx)
          html += emailFirmaMedica(d.doctora || d.atendio || '')
        } else if (tipo === 'recibo_venta') {
          subject = 'ðŸ§¾ Recibo de pago â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('recibo_venta', vars, function() { return buildEmailReciboVenta(d.nombre||'Cliente', d.items||[], d.total||0, d.moneda||'PEN', d.metodo||'', d.sede||'', d.fecha||'', d.venta_id||'') }), tplCtx
          html += emailFirmaMedica(d.doctora || d.atendio || '')
        } else if (tipo === 'cotizacion') {
          subject = 'ðŸ“‹ Tu cotizaciÃ³n â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('catalogo', vars, function() { return buildEmailReciboVenta(d.nombre||'Cliente', d.items||[], d.total||0, d.moneda||'PEN', '', d.sede||'', d.fecha||'', '') }), tplCtx
        } else if (tipo === 'seguimiento') {
          subject = 'ðŸ’†â€â™€ï¸ Â¿CÃ³mo te fue con tu tratamiento? â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('seguimiento', vars, function() { return buildEmailSeguimiento(d.nombre||'Paciente', d.tratamiento||'', d.dias||7) }), tplCtx
        } else if (tipo === 'recordatorio') {
          subject = d.es_manana ? 'Tu cita de maÃ±ana â€” ' + (d.hora||'') : 'Â¡Tu cita es hoy! ' + (d.hora||'')
          var recTipo = d.es_manana ? 'recordatorio' : 'recordatorio_hoy'
          html = buildFromTemplate(recTipo, vars, function() { return buildEmailRecordatorio(d.nombre||'Paciente', d.tratamiento||'', d.hora||'', d.sede||'', d.fecha||'', !!d.es_manana) }), tplCtx
          html += emailFirmaMedica(d.doctora || d.atendio || '')
        } else if (tipo === 'bienvenida') {
          subject = 'Â¡Bienvenida a ' + BRAND.nombre_empresa + '! âœ¨'
          html = buildFromTemplate('bienvenida', vars, function() { return buildEmailBienvenida(d.nombre||'Paciente') }), tplCtx
        } else if (tipo === 'agradecimiento_visita') {
          subject = 'ðŸŒŸ Â¡Gracias por tu visita! â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('agradecimiento_visita', vars, function() { return buildEmailAgradecimiento(d.nombre||'Paciente', d.tratamiento||'', d.sede||'', d.fecha||'') }), tplCtx
        } else if (tipo === 'saldo_pendiente') {
          subject = 'ðŸ’³ Tienes un saldo pendiente â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('saldo_pendiente', vars, function() { return buildEmailSaldoPendiente(d.nombre||'Paciente', d.items||[]) }), tplCtx
        } else if (tipo === 'cumpleanos') {
          subject = 'ðŸŽ‚ Â¡Feliz cumpleaÃ±os, ' + (d.nombre||'').split(' ')[0] + '! â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('cumpleanos', vars, function() { return buildEmailCumpleanos(d.nombre||'Paciente') }), tplCtx
        } else if (tipo === 'reactivacion') {
          subject = 'ðŸ’š Te extraÃ±amos, ' + (d.nombre||'').split(' ')[0] + ' â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('reactivacion', vars, function() { return buildEmailReactivacion(d.nombre||'Paciente', d.ultimo_tratamiento||'', d.dias||60) }), tplCtx
        } else if (tipo === 'no_asistencia') {
          subject = 'ðŸ˜” Lamentamos que no hayas podido asistir â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('no_asistencia', vars, function() { return buildEmailNoAsistencia(d.nombre||'Paciente', d.tratamiento||'', d.fecha||'', d.hora||'', d.sede||'') }), tplCtx
        } else if (tipo === 'confirmacion_pago') {
          subject = 'âœ… Pago recibido â€” S/' + parseFloat(d.monto||0).toFixed(2) + ' â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('confirmacion_pago', vars, function() { return buildEmailConfirmacionPago(d.nombre||'Paciente', d.tratamiento||'', d.monto||0, d.saldo_actual||0, d.metodo_pago||'') }), tplCtx
          html += emailFirmaMedica(d.doctora || d.atendio || '')
        } else if (tipo === 'reprogramacion') {
          subject = 'ðŸ”„ Tu cita ha sido reprogramada â€” ' + BRAND.nombre_empresa
          html = buildFromTemplate('reprogramacion', vars, function() { return buildEmailReprogramacion ? buildEmailReprogramacion(d.nombre||'Paciente', d.tratamiento||'', d.hora||'', d.sede||'', d.fecha||'') : emailShell('Cita reprogramada', '<p>Tu cita ha sido reprogramada.</p>') }), tplCtx
          html += emailFirmaMedica(d.doctora || d.atendio || '')
        } else {
          res.writeHead(400); res.end('{"error":"template no reconocido: ' + tipo + '"}'); return
        }
        sendAgentEmail(d.to, subject, html, tipo, d.destinatario_id || d.to)
          .then(function(r) {
            // Disparar flujo multi-paso si aplica
            if (r && r.ok && !r.skip && FLUJO_TRIGGERS[tipo]) {
              _dispararFlujo(FLUJO_TRIGGERS[tipo], d.to, d.destinatario_id || d.numero_limpio || '', {
                nombre: d.nombre || '', tratamiento: d.tratamiento || '', sede: d.sede || '',
                fecha: d.fecha || '', hora: d.hora || ''
              })
            }
            res.writeHead(200, {'Content-Type':'application/json'}); res.end(JSON.stringify(r))
          })
          .catch(function(e) { res.writeHead(500); res.end('{"error":"' + e.message + '"}') })
      } catch(e) { res.writeHead(400); res.end('{"error":"Invalid JSON"}') }
      })
    }).catch(function() {
      res.writeHead(401, { 'Content-Type':'application/json', 'Cache-Control':'no-store' })
      res.end(JSON.stringify({ok:false,error:'UNAUTHORIZED'}))
    })
    return
  }
  if (p === '/api/send-template' && req.method === 'OPTIONS') {
    res.writeHead(405, { 'Content-Type':'application/json', 'Cache-Control':'no-store' })
    res.end(JSON.stringify({ok:false,error:'METHOD_NOT_ALLOWED'})); return
  }
  // ===== FIN TEMPLATE EMAILS =====
  // ===== F16 RESEND WEBHOOK =====
  // Handled above by EMAIL_GATEWAY with cryptographic signature + replay protection.

  // ===== RESEND STATS â€” datos reales de emails enviados =====
  if (p === '/api/resend-stats' && req.method === 'GET') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    // Consultar TODAS las fuentes de emails en Supabase
    var hoy = new Date(Date.now() + (-5*60)*60000).toISOString().split('T')[0]
    var mesActual = hoy.slice(0, 7)
    Promise.all([
      sbFetch('/rest/v1/aos_emails_enviados?select=id,tipo,destinatario,email_destino,asunto,fecha_envio,resend_id,html_preview,created_at,abierto,clicks,rebotado&order=created_at.desc&limit=200'),
      sbFetch('/rest/v1/aos_email_envios?select=id,asunto,estado,destinatario_email,destinatario_nombre,enviado_at,created_at&order=created_at.desc&limit=50'),
      sbFetch('/rest/v1/aos_security_log?select=id,usuario,accion,created_at&accion=in.(login,2fa_verified)&order=created_at.desc&limit=50')
    ]).then(function(results) {
      var agente = results[0] || []
      var panel = results[1] || []
      var seguridad = results[2] || []
      // Unificar todos los emails
      var allEmails = []
      agente.forEach(function(e) {
        var dest = e.email_destino || e.destinatario || ''
        var tipoClean = (e.tipo || 'otro')
        var subj = e.asunto || e.tipo || ''
        allEmails.push({ to: dest, subject: subj, status: e.resend_id ? 'delivered' : 'sent', created_at: e.created_at, tipo: tipoClean, origen: 'agente', html: e.html_preview || '', abierto: e.abierto || false, clicks: e.clicks || 0, rebotado: e.rebotado || false })
      })
      panel.forEach(function(e) {
        allEmails.push({ to: e.destinatario_email, subject: e.asunto, status: e.estado === 'enviado' ? 'delivered' : e.estado, created_at: e.enviado_at || e.created_at, tipo: 'manual', origen: 'panel' })
      })
      seguridad.forEach(function(e) {
        allEmails.push({ to: e.usuario, subject: 'ðŸ”‘ CÃ³digo 2FA â€” Login', status: 'delivered', created_at: e.created_at, tipo: 'sistema', origen: 'sistema' })
      })
      // Ordenar por fecha desc
      allEmails.sort(function(a, b) { return (b.created_at || '') > (a.created_at || '') ? 1 : -1 })
      // Calcular mÃ©tricas
      var totalHoy = 0, totalMes = 0, entregados = 0, porTipo = {}
      var totalAbiertos = 0, totalRebotados = 0, totalClicks = 0
      allEmails.forEach(function(e) {
        var fecha = (e.created_at || '').slice(0, 10)
        var mes = (e.created_at || '').slice(0, 7)
        if (fecha === hoy) totalHoy++
        if (mes === mesActual) totalMes++
        if (e.status === 'delivered' || e.status === 'enviado') entregados++
        if (e.abierto) totalAbiertos++
        if (e.rebotado) totalRebotados++
        totalClicks += (e.clicks || 0)
        var t = e.tipo || 'otro'
        porTipo[t] = (porTipo[t] || 0) + 1
      })
      res.writeHead(200, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({
        ok: true,
        total_resend: allEmails.length,
        total_mes: totalMes,
        total_hoy: totalHoy,
        entregados: entregados,
        rebotados: totalRebotados,
        abiertos: totalAbiertos,
        clicks: totalClicks,
        open_rate: entregados > 0 ? Math.round(totalAbiertos / entregados * 100) : 0,
        click_rate: totalAbiertos > 0 ? Math.round(totalClicks / totalAbiertos * 100) : 0,
        por_tipo: porTipo,
        limite_free: 3000,
        usado_pct: Math.round(totalMes / 3000 * 100),
        emails: allEmails.slice(0, 100)
      }))
    }).catch(function(err) {
      res.writeHead(500, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ ok: false, error: err.message }))
    })
    return
  }
  if (p === '/api/resend-stats' && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }
  // ===== TURNSTILE CAPTCHA VERIFICATION =====
  if (p === '/api/verify-turnstile' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        var verifyData = 'secret=0x4AAAAAADBlrTyMhE39Qf9UBLIhNsWHC0Y&response=' + (d.token || '')
        var vReq = https.request({
          hostname: 'challenges.cloudflare.com', path: '/turnstile/v0/siteverify', method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(verifyData) }
        }, function(vRes) {
          var vData = ''; vRes.on('data', function(c) { vData += c }); vRes.on('end', function() {
            try { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(vData); }
            catch(e) { res.writeHead(200); res.end('{"success":true}'); }
          })
        })
        vReq.on('error', function() { res.writeHead(200); res.end('{"success":true}'); })
        vReq.write(verifyData); vReq.end()
      } catch(e) { res.writeHead(200); res.end('{"success":true}'); }
    }); return
  }
  if (p === '/api/verify-turnstile' && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }
  // ===== FIN TURNSTILE =====
  if (p === '/' || p === '/login') { serve(path.join(PUB, 'login.html'), res); return }
  if (p === '/app') { serve(path.join(PUB, 'app.html'), res); return }
  if (p === '/agendar' || p.startsWith('/agendar?')) { serve(path.join(PUB, 'agendar.html'), res); return }
  if (p === '/encuesta' || p.startsWith('/encuesta?')) { serve(path.join(PUB, 'encuesta.html'), res); return }
  if (p === '/agents') { serve(path.join(PUB, 'agents.html'), res); return }
  if (p === '/cerebro.html' || p === '/cerebro') { serve(path.join(PUB, 'cerebro.html'), res); return }
  // ===== AGENTS THINK-LOOP API =====
  if (p === '/api/agents/tick' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    agentTick(req, res); return
  }
  if (p === '/api/agents/status' && req.method === 'GET') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    agentStatus(res); return
  }
  if (p === '/api/agents/run' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    agentRunSingle(req, res); return
  }
  if ((p === '/api/agents/tick' || p === '/api/agents/status' || p === '/api/agents/run') && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST,GET', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }
  if (p === '/api/agents/chat' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body2 = ''
    req.on('data', function(c) { body2 += c })
    req.on('end', function() {
      try {
        var payload = JSON.parse(body2)
        var agentId  = payload.agent_id || 'kronia'
        var msgs     = Array.isArray(payload.messages) ? payload.messages : []
        // Fetch system_prompt + contexto real del sistema
        sbFetch('/rest/v1/aos_agentes?select=id,system_prompt,modelo&id=eq.' + agentId).then(function(rows) {
          var baseSysPrompt = (rows && rows[0] && rows[0].system_prompt)
            ? rows[0].system_prompt
            : 'Eres un agente AI de la clinica Zi Vital. Responde de forma concisa y util.'
          var modelo = (rows && rows[0] && rows[0].modelo) ? rows[0].modelo : 'llama-3.3-70b-versatile'

          // Cargar contexto real para que el agente sepa quÃ© puede hacer
          return buildChatContext(agentId).then(function(ctx) {
            var sysPrompt = baseSysPrompt + '\n\n' + ctx
            return callGroqChat(sysPrompt, msgs, modelo)
          })
        }).then(function(reply) {
          res.writeHead(200, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify({ ok: true, reply: reply }))
        }).catch(function(e) {
          res.writeHead(200, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify({ ok: false, reply: 'âš  ' + (e.message || 'error'), error: e.message }))
        })
      } catch(e) {
        res.writeHead(400, { 'Content-Type': 'application/json' })
        res.end(JSON.stringify({ ok: false, error: 'Bad JSON' }))
      }
    })
    return
  }
  if (p === '/api/agents/chat' && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }
  if (p === '/api/agents/costs' && req.method === 'GET') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var limaToday = new Date(Date.now() + (-5*60)*60000).toISOString().split('T')[0]
    sbFetch('/rest/v1/aos_agente_costos?fecha_lima=eq.' + limaToday + '&select=agente_id,motor,tokens_in,tokens_out,costo_usd,tarea_nombre,created_at&order=created_at.desc')
      .then(function(rows) {
        var totalTokens = 0, totalCost = 0
        ;(rows || []).forEach(function(r) { totalTokens += (r.tokens_in||0) + (r.tokens_out||0); totalCost += parseFloat(r.costo_usd||0) })
        res.writeHead(200, { 'Content-Type': 'application/json' })
        res.end(JSON.stringify({ ok: true, fecha: limaToday, totalTokens: totalTokens, totalCost: totalCost, detalle: (rows||[]).slice(0,50) }))
      }).catch(function(e) {
        res.writeHead(200, { 'Content-Type': 'application/json' })
        res.end(JSON.stringify({ ok: false, error: e.message }))
      })
    return
  }
  if (p === '/api/agents/costs' && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }

  // â•â•â• CAMILA â€” COPYWRITER ON-DEMAND â•â•â•
  // Body: { tipo: 'social_post'|'email'|'sms'|'anuncio', tratamiento: '...', tono: 'profesional'|'urgente'|'amigable', contexto?: '...' }
  if (p === '/api/agents/camila/generar' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        var tipo = d.tipo || 'social_post'
        var tratamiento = d.tratamiento || ''
        var tono = d.tono || 'profesional'
        var ctxExtra = d.contexto || ''
        if (!tratamiento) { res.writeHead(400); res.end(JSON.stringify({error:'Falta tratamiento'})); return }
        
        // Cargar info del catÃ¡logo + prompt de Camila
        Promise.all([
          sbGet('/rest/v1/aos_catalogo_servicios?nombre=ilike.*' + encodeURIComponent(tratamiento) + '*&select=nombre,precio_oferta,beneficios,contraindicaciones,perfil_paciente&limit=1'),
          sbGet('/rest/v1/aos_agentes?id=eq.creador&select=system_prompt,modelo')
        ]).then(function(results) {
          var trat = (results[0]||[])[0] || { nombre: tratamiento, beneficios: '', perfil_paciente: '' }
          var agent = (results[1]||[])[0] || { system_prompt: 'Eres Camila, copywriter de Zi Vital.', modelo: 'gemini-2.0-flash' }
          
          var formatos = {
            social_post: 'Post de Instagram/Facebook. Hook + beneficio + CTA. Max 4 lineas. Incluye 3 hashtags relevantes al final.',
            email: 'Asunto (max 50 caracteres) + cuerpo del email (max 120 palabras) + CTA claro. Saludo informal.',
            sms: 'SMS de WhatsApp. Max 50 palabras. Conversacional, directo, con emoji al inicio.',
            anuncio: 'Texto para anuncio Meta Ads. Headline (40 char) + texto principal (125 char) + descripcion (50 char).'
          }
          var instruccion = formatos[tipo] || formatos.social_post
          
          var userPrompt = 'Genera copy de tipo "' + tipo + '" con tono "' + tono + '".\n' +
            'TRATAMIENTO: ' + trat.nombre + ' (S/' + (trat.precio_oferta||'consultar') + ')\n' +
            'BENEFICIOS: ' + (trat.beneficios||'').substring(0,200) + '\n' +
            'PERFIL: ' + (trat.perfil_paciente||'').substring(0,150) + '\n' +
            (ctxExtra ? 'CONTEXTO EXTRA: ' + ctxExtra + '\n' : '') +
            'FORMATO: ' + instruccion + '\n' +
            'IMPORTANTE: Solo responde el copy, sin explicaciones ni meta-texto.'
          
          // Usar Groq (Gemini serÃ­a ideal pero ya tenemos infra de Groq)
          sbGet('/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key&limit=1').then(function(rows) {
            var groqKey = rows && rows[0] ? rows[0].api_key : null
            if (!groqKey) { res.writeHead(400); res.end(JSON.stringify({error:'Groq key no encontrada'})); return }
            
            var groqBody = JSON.stringify({
              model: 'llama-3.3-70b-versatile',
              messages: [
                { role: 'system', content: agent.system_prompt },
                { role: 'user', content: userPrompt }
              ],
              max_tokens: 400,
              temperature: 0.8
            })
            var startTs = Date.now()
            var gReq = https.request({
              hostname: 'api.groq.com', path: '/openai/v1/chat/completions', method: 'POST',
              headers: { 'Authorization': 'Bearer ' + groqKey, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(groqBody) }
            }, function(gRes) {
              var gData = ''; gRes.on('data', function(c) { gData += c }); gRes.on('end', function() {
                try {
                  var result = JSON.parse(gData)
                  var copy = result.choices && result.choices[0] ? result.choices[0].message.content.trim() : ''
                  var dur = Date.now() - startTs
                  
                  // Guardar log de Camila
                  sbPost('/rest/v1/aos_agente_logs', {
                    agente_id: 'creador', accion: 'generar_copy_' + tipo,
                    input_resumen: tratamiento + ' (' + tono + ')',
                    output_resumen: copy.substring(0, 250),
                    exitoso: copy.length > 0, duracion_ms: dur
                  }).catch(function(){})
                  sbRpc('aos_agente_registrar_ejecucion', { p_agente_id: 'creador', p_exitoso: copy.length > 0 }).catch(function(){})
                  
                  // Guardar en aos_agente_contenido para historial
                  sbPost('/rest/v1/aos_agente_contenido', {
                    agente_id: 'creador', tipo: tipo, contenido: copy,
                    metadata: JSON.stringify({ tratamiento: tratamiento, tono: tono })
                  }).catch(function(){})
                  
                  res.writeHead(200, { 'Content-Type': 'application/json' })
                  res.end(JSON.stringify({ ok: true, copy: copy, tipo: tipo, tratamiento: tratamiento, duracion_ms: dur }))
                } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Parse error'})) }
              })
            })
            gReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
            gReq.write(groqBody); gReq.end()
          })
        }).catch(function(e) { res.writeHead(500); res.end(JSON.stringify({error:'Context error'})) })
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:'Invalid JSON'})) }
    }); return
  }
  if (p === '/api/agents/camila/generar' && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }

  // â•â•â• MAYA â€” RECEPCIONISTA (WhatsApp inbound simulado / endpoint pÃºblico para webhook futuro) â•â•â•
  // Body: { numero: '...', mensaje: '...', tratamiento?: '...' }
  if (p === '/api/agents/maya/responder' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        var numero = (d.numero || '').replace(/\D/g, '')
        var mensaje = (d.mensaje || '').trim()
        if (!numero || !mensaje) { res.writeHead(400); res.end(JSON.stringify({error:'Falta numero o mensaje'})); return }
        
        Promise.all([
          sbGet('/rest/v1/aos_pacientes?numero_limpio=eq.' + numero + '&select=Nombres,Apellidos&limit=1'),
          sbGet('/rest/v1/aos_catalogo_servicios?estado=eq.ACTIVO&select=nombre,categoria,precio_oferta&limit=15&order=categoria'),
          sbGet('/rest/v1/aos_agentes?id=eq.recepcion&select=system_prompt,modelo')
        ]).then(function(results) {
          var pac = (results[0]||[])[0] || null
          var catalogo = results[1] || []
          var agent = (results[2]||[])[0] || { system_prompt: 'Eres Maya, recepcionista virtual de Zi Vital.' }
          
          var catResumen = catalogo.map(function(c){return c.nombre+' S/'+(c.precio_oferta||'consultar')}).join(', ')
          var nombrePac = pac ? (pac.Nombres + ' ' + (pac.Apellidos||'')).trim() : 'usuario nuevo'
          
          var systemPrompt = agent.system_prompt + 
            '\n\nPACIENTE: ' + nombrePac + 
            '\nCATALOGO: ' + catResumen.substring(0,800) +
            '\nINSTRUCCIONES: Responde corto (max 3 oraciones), cordial, profesional. ' +
            'Si pregunta por horarios: lunes a sabado 9am-8pm, domingos 10am-2pm. ' +
            'Si pregunta direccion: tenemos sedes en San Isidro y Pueblo Libre. ' +
            'Si quiere agendar: pidele su nombre completo, DNI y tratamiento de interes para coordinar. ' +
            'NUNCA inventes precios â€” usa SOLO los del catalogo. Si pregunta por tratamiento sin precio, di "te coordino con un asesor".'
          
          sbGet('/rest/v1/aos_integraciones?tipo=eq.groq&estado=eq.conectado&select=api_key&limit=1').then(function(rows) {
            var groqKey = rows && rows[0] ? rows[0].api_key : null
            if (!groqKey) { res.writeHead(400); res.end(JSON.stringify({error:'Groq key no encontrada'})); return }
            
            var groqBody = JSON.stringify({
              model: 'llama-3.3-70b-versatile',
              messages: [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: mensaje }
              ],
              max_tokens: 250,
              temperature: 0.7
            })
            var startTs = Date.now()
            var gReq = https.request({
              hostname: 'api.groq.com', path: '/openai/v1/chat/completions', method: 'POST',
              headers: { 'Authorization': 'Bearer ' + groqKey, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(groqBody) }
            }, function(gRes) {
              var gData = ''; gRes.on('data', function(c) { gData += c }); gRes.on('end', function() {
                try {
                  var result = JSON.parse(gData)
                  var respuesta = result.choices && result.choices[0] ? result.choices[0].message.content.trim() : ''
                  var dur = Date.now() - startTs
                  
                  // Log de Maya
                  sbPost('/rest/v1/aos_agente_logs', {
                    agente_id: 'recepcion', accion: 'responder_mensaje',
                    input_resumen: '[' + numero + '] ' + mensaje.substring(0,100),
                    output_resumen: respuesta.substring(0,200),
                    exitoso: respuesta.length > 0, duracion_ms: dur
                  }).catch(function(){})
                  sbRpc('aos_agente_registrar_ejecucion', { p_agente_id: 'recepcion', p_exitoso: respuesta.length > 0 }).catch(function(){})
                  
                  // Guardar conversaciÃ³n en tabla especÃ­fica de Maya
                  sbPost('/rest/v1/aos_maya_conversaciones', {
                    numero_paciente: numero, mensaje_in: mensaje, mensaje_out: respuesta,
                    paciente_existe: pac !== null, canal: d.canal || 'web'
                  }).catch(function(){})
                  
                  res.writeHead(200, { 'Content-Type': 'application/json' })
                  res.end(JSON.stringify({ ok: true, respuesta: respuesta, paciente: nombrePac, duracion_ms: dur }))
                } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Parse error'})) }
              })
            })
            gReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
            gReq.write(groqBody); gReq.end()
          })
        }).catch(function(e) { res.writeHead(500); res.end(JSON.stringify({error:'Context error'})) })
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:'Invalid JSON'})) }
    }); return
  }
  if (p === '/api/agents/maya/responder' && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }
  // ===== FIN AGENTS =====
  var f = path.join(PUB, p.slice(1))
  if (fs.existsSync(f) && !fs.statSync(f).isDirectory()) { serve(f, res); return }
  serve(path.join(PUB, 'login.html'), res)
}).listen(PORT, '0.0.0.0', function() {
  console.log('AscendaOS http://0.0.0.0:' + PORT)
  console.log('Webhook: https://ascenda-os-production.up.railway.app/webhook')
  console.log('Agents: Think-loop ready on /api/agents/tick')
  // PERFORMANCE GUARD: comprobar cron cada 60s; el cron de negocio no cambia.
  var _autoTickRunning = false
  function guardedAutoTick() {
    if (_autoTickRunning || !bgCanRun()) return
    _autoTickRunning = true
    try { autoTick() } catch(e) { bgFail(); console.error('[TICK] Guard error:', e.message) }
    setTimeout(function(){ _autoTickRunning = false }, 50000)
  }
  setInterval(guardedAutoTick, 60000)
  setTimeout(guardedAutoTick, 15000)
  console.log('Agents: guarded auto-tick every 60s started')
})



// â•â•â• TRACKING DE COSTOS Y CONTENIDO â•â•â•
var TOKEN_COSTS = {
  'llama-3.3-70b-versatile':   { input: 0, output: 0, motor: 'groq' },      // Groq gratis
  'llama3-70b-8192':           { input: 0, output: 0, motor: 'groq' },
  'gemini-1.5-flash':          { input: 0.075, output: 0.30, motor: 'gemini' }, // por 1M tokens
  'gemini-2.5-flash':          { input: 0.30,  output: 2.50, motor: 'gemini' },
  'gemini-2.0-flash':          { input: 0.10,  output: 0.40, motor: 'gemini' },
}

function trackCost(agentId, motor, modelo, tokensIn, tokensOut, tareaNombre) {
  var costs = TOKEN_COSTS[modelo] || TOKEN_COSTS['llama-3.3-70b-versatile'] || { input: 0, output: 0 }
  var costoUsd = (tokensIn * costs.input / 1000000) + (tokensOut * costs.output / 1000000)
  var payload = {
    agente_id: String(agentId), motor: String(motor || 'groq'), modelo: String(modelo || ''),
    tokens_in: parseInt(tokensIn) || 0, tokens_out: parseInt(tokensOut) || 0,
    costo_usd: parseFloat(costoUsd.toFixed(6)), tarea_nombre: String(tareaNombre || '')
  }
  console.log('[COST] Tracking:', agentId, parseInt(tokensIn)+parseInt(tokensOut), 'tokens, $'+costoUsd.toFixed(6))
  sbPost('/rest/v1/aos_agente_costos', payload)
    .then(function(status) { if (status >= 400) console.error('[COST] HTTP', status, JSON.stringify(payload).substring(0,100)) })
    .catch(function(e) { console.error('[COST] Error:', e.message) })
  return costoUsd
}

// Guardar contenido generado por AI (insights, copys, reportes)
function saveContent(agentId, tipo, titulo, contenido, metadata) {
  var payload = {
    agente_id: String(agentId), tipo: String(tipo), titulo: String(titulo || ''),
    contenido: String(contenido || '').substring(0, 8000),
    metadata: metadata || {}
  }
  console.log('[CONTENT] Saving:', agentId, tipo, (titulo||'').substring(0,40))
  return sbPost('/rest/v1/aos_agente_contenido', payload)
    .then(function(status) { if (status >= 400) console.error('[CONTENT] HTTP', status) })
    .catch(function(e) { console.error('[CONTENT] Error:', e.message) })
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MOTOR DE ACCIONES â€” agentes actÃºan, no solo analizan
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

var RESEND_KEY_AG = process.env.RESEND_API_KEY || ''

// â•â•â• BRANDING CACHE (se carga al inicio y refresca cada 30min) â•â•â•
var BRAND = {
  color_primario: '#f0ebe0', color_secundario: '#cea14a', color_dark: '#e1ded1',
  color_texto: '#b89447', color_enlace: '#a28444', color_degradado2: '#f1eee4',
  color_header: '#4a3728', color_header_texto: '#FFFFFF',
  logo_con_fondo_url: '', logo_sin_fondo_url: '', nombre_empresa: 'Zi Vital',
  telefono: '', whatsapp: ''
}
function loadBrand() {
  sbFetch('/rest/v1/aos_configuracion?select=clave,valor').then(function(rows) {
    if (!rows || !rows.length) return
    rows.forEach(function(r) { if (BRAND.hasOwnProperty(r.clave)) BRAND[r.clave] = r.valor })
    console.log('[BRAND] Branding cargado: header=' + BRAND.color_header + ' sec=' + BRAND.color_secundario)
  }).catch(function(e) { console.error('[BRAND] Error:', e.message) })
}
// Cargar al arrancar (con delay para que sbFetch estÃ© listo)
setTimeout(loadBrand, 3000)
setInterval(loadBrand, 1800000) // refresh cada 30 min

// â•â•â• EMAIL TEMPLATE ENGINE â€” branding dinÃ¡mico desde aos_configuracion â•â•â•
function emailShell(headerHtml, bodyHtml) {
  var logo = BRAND.logo_sin_fondo_url || BRAND.logo_con_fondo_url
  var logoBlock = logo ? '<img src="' + logo + '" alt="' + BRAND.nombre_empresa + '" style="height:36px;margin-bottom:10px;display:block;" />' : ''
  var hdrBg = BRAND.color_header || BRAND.color_dark || '#4a3728'
  var hdrTxt = BRAND.color_header_texto || '#FFFFFF'
  return '<div style="font-family:DM Sans,Arial,sans-serif;max-width:560px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;border:1px solid #E2E8F0">' +
    '<div style="background:' + hdrBg + ';padding:28px 32px">' +
    logoBlock +
    '<div style="color:' + BRAND.color_secundario + ';font-size:11px;font-weight:700;letter-spacing:0.1em;text-transform:uppercase;margin-bottom:8px">' + BRAND.nombre_empresa + '</div>' +
    '<div style="color:' + hdrTxt + '">' + headerHtml + '</div>' +
    '</div>' +
    '<div style="padding:28px 32px">' + bodyHtml + '</div>' +
    '<div style="background:' + hdrBg + ';padding:14px 32px;text-align:center;font-size:11px;color:' + BRAND.color_secundario + '">' + BRAND.nombre_empresa + ' Â· info@zivital.pe</div>' +
    '</div>'
}
function emailInfoBox(label, value) {
  return '<div style="margin-bottom:8px"><div style="font-size:11px;color:#94A3B8">' + label + '</div><div style="font-size:15px;font-weight:600;color:' + BRAND.color_secundario + '">' + value + '</div></div>'
}
function emailCard(content) {
  return '<div style="background:' + BRAND.color_primario + ';border-radius:10px;padding:18px 20px;border-left:4px solid ' + BRAND.color_secundario + ';margin-bottom:20px">' + content + '</div>'
}

// â•â•â• FIRMA MÃ‰DICA CON CMP â€” se inyecta en recibos/confirmaciones cuando hay doctora â•â•â•
var _cmpCache = {} // nombre â†’ {cmp, nombre_completo}
function loadCmpCache() {
  sbFetch('/rest/v1/aos_usuarios?select=nombre,apellidos,cmp&area=eq.mÃ©dica&cmp=neq.').then(function(rows) {
    if (!rows) return
    rows.forEach(function(r) { if (r.cmp) _cmpCache[(r.nombre||'').toUpperCase()] = { cmp: r.cmp, full: (r.nombre||'') + ' ' + (r.apellidos||'') }; })
    console.log('[CMP] Cache cargado:', Object.keys(_cmpCache).length, 'doctoras')
  }).catch(function() {})
}
setTimeout(loadCmpCache, 5000)
setInterval(loadCmpCache, 1800000)

function emailFirmaMedica(doctoraNombre) {
  if (!doctoraNombre) return ''
  var key = doctoraNombre.toUpperCase().trim()
  var doc = _cmpCache[key]
  if (!doc && key.indexOf('DRA') >= 0) {
    // Intentar buscar sin "DRA "
    var sinDra = key.replace(/^DRA\.?\s*/i, '').trim()
    Object.keys(_cmpCache).forEach(function(k) { if (k.indexOf(sinDra) >= 0) doc = _cmpCache[k]; })
  }
  if (!doc || !doc.cmp) return ''
  return '<div style="margin-top:20px;padding:14px;background:#F0F4FC;border-radius:10px;border:1px solid #DBEAFE;text-align:center">' +
    '<div style="font-size:11px;color:#6B7BA8;margin-bottom:4px">Profesional responsable</div>' +
    '<div style="font-size:14px;font-weight:800;color:#0A4FBF">' + doc.full + '</div>' +
    '<div style="font-size:11px;font-weight:700;color:#0A4FBF;margin-top:2px">CMP ' + doc.cmp + '</div>' +
    '</div>'
}

// Enviar email vÃ­a Resend (reutiliza la misma clave y from)
// ===== VALIDAR EMAIL â€” evitar errores recurrentes con emails invÃ¡lidos =====
function validarEmail(email) {
  if (!email || typeof email !== 'string') return false
  email = email.trim()
  if (email.length < 5) return false
  // Regex bÃ¡sico pero efectivo
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return false
  // Detectar caracteres non-ASCII (Ã±, acentos en email)
  if (/[^\x00-\x7F]/.test(email)) return false
  // Detectar emails vacÃ­os como @gmail.com
  if (email.indexOf('@') === 0) return false
  // Detectar punto antes de @
  if (email.indexOf('.@') >= 0) return false
  return true
}

// Tipos transaccionales: NO se limitan por cadencia (son respuestas a acciones del paciente)
var EMAILS_TRANSACCIONALES = ['confirmacion_cita','recibo_venta','recordatorio_hoy','recordatorio_manana','recordatorio','bienvenida','confirmacion_pago','cotizacion','catalogo','comprobante','agradecimiento','agradecimiento_visita','no_asistencia','reprogramacion','saldo_pendiente','seguimiento']

function sendAgentEmail(to, subject, html, tipo, destinatario_id) {
  return new Promise(function(resolve) {
    // F16: all marketing/reactivation/cross-sell agent sends require governed Audience activation + consent.
    if (EMAILS_TRANSACCIONALES.indexOf(String(tipo || '')) === -1) {
      resolve({ skip:true, reason:'F16_MARKETING_GOVERNED_ACTIVATION_REQUIRED', governed_activation_required:true }); return
    }
    // Anti-duplicado: verificar si ya se enviÃ³ hoy
    sbFetch('/rest/v1/aos_emails_enviados?tipo=eq.' + encodeURIComponent(tipo) + '&destinatario=eq.' + encodeURIComponent(destinatario_id) + '&fecha_envio=eq.' + limaDateStr())
      .then(function(rows) {
        if (rows && rows.length > 0) { resolve({ skip: true, reason: 'ya enviado hoy' }); return }

        // â•â•â• GUARD CADENCIA: mÃ¡x 2 emails marketing/semana por paciente â•â•â•
        if (EMAILS_TRANSACCIONALES.indexOf(tipo) === -1) {
          // Es marketing/engagement â€” verificar cadencia semanal
          var _limaD = new Date(Date.now() + (-5 * 60) * 60000)
          var _dow = _limaD.getDay() // 0=dom
          var _inicioSemana = new Date(_limaD.getTime() - _dow * 86400000)
          var _isoInicio = _inicioSemana.toISOString().split('T')[0]
          return sbFetch('/rest/v1/aos_email_cadencia?email_destino=eq.' + encodeURIComponent(to) + '&fecha_envio=gte.' + _isoInicio + '&select=id')
            .then(function(cadRows) {
              if (cadRows && cadRows.length >= 2) {
                console.log('[CADENCIA] Skip ' + to + ' â€” ya recibiÃ³ ' + cadRows.length + ' emails esta semana (tipo: ' + tipo + ')')
                resolve({ skip: true, reason: 'cadencia_semanal: ' + cadRows.length + '/2' })
                return
              }
              // Pasar al envÃ­o real
              _doSendEmail(to, subject, html, tipo, destinatario_id, resolve)
            }).catch(function() {
              // Si falla la consulta de cadencia, enviar de todos modos (fail-open)
              _doSendEmail(to, subject, html, tipo, destinatario_id, resolve)
            })
        }

        // Transaccional â€” enviar sin lÃ­mite de cadencia
        _doSendEmail(to, subject, html, tipo, destinatario_id, resolve)
      }).catch(function(e) { resolve({ ok: false, error: e.message }) })
  })
}

// â•â•â• ENVÃO REAL de email vÃ­a Resend + registro en cadencia â•â•â•
function _doSendEmail(to, subject, html, tipo, destinatario_id, resolve) {
  var emailData = JSON.stringify({
    from: 'ClÃ­nica Zi Vital <info@zivital.pe>',
    to: [to], subject: subject, html: html,
    reply_to: 'jaureguitorrescesar@gmail.com'
  })
  var req = https.request({
    hostname: 'api.resend.com', path: '/emails', method: 'POST',
    headers: { 'Authorization': 'Bearer ' + RESEND_KEY_AG, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(emailData) }
  }, function(res) {
    var d = ''; res.on('data', function(c) { d += c }); res.on('end', function() {
      try {
        var r = JSON.parse(d)
        if (r.id) {
          // Registrar envÃ­o para anti-duplicado
          sbPost('/rest/v1/aos_emails_enviados', {
            tipo: tipo, destinatario: destinatario_id,
            fecha_envio: limaDateStr(), resend_id: r.id,
            email_destino: to, asunto: subject,
            html_preview: html.slice(0, 50000)
          }).catch(function(){})
          // Registrar en cadencia semanal
          sbPost('/rest/v1/aos_email_cadencia', {
            paciente_id: destinatario_id, email_destino: to,
            tipo: tipo, fecha_envio: limaDateStr()
          }).catch(function(){})
          // Alerta en panel
          sbPost('/rest/v1/aos_email_alertas', {
            tipo: 'exito', template: tipo,
            titulo: 'âœ… ' + tipo + ' enviado',
            detalle: subject,
            destinatario: to, resend_id: r.id
          }).catch(function(){})
        } else {
          // Alerta de error en panel
          sbPost('/rest/v1/aos_email_alertas', {
            tipo: 'error', template: tipo,
            titulo: 'âŒ Error enviando ' + tipo,
            detalle: r.message || 'Sin respuesta de Resend',
            destinatario: to
          }).catch(function(){})
        }
        resolve({ ok: !!r.id, id: r.id, error: r.message })
      } catch(e) { resolve({ ok: false, error: e.message }) }
    })
  })
  req.on('error', function(e) { resolve({ ok: false, error: e.message }) })
  req.write(emailData); req.end()
}

// Insertar notificaciÃ³n en el CRM (aparece en el panel de notificaciones)
function notifyAdmin(titulo, contenido, tipo, prioridad) {
  return sbPost('/rest/v1/aos_notificaciones', {
    titulo: titulo, contenido: contenido,
    tipo: tipo || 'ALERTA', de: 'AGENTES_AI',
    para: 'ADMIN', prioridad: prioridad || 'ALTA',
    expira_at: new Date(Date.now() + 24*60*60*1000).toISOString()
  }).catch(function(){})
}

// Registrar acciÃ³n real del agente
function logAction(agentId, tipoAccion, descripcion, metadata) {
  return sbPost('/rest/v1/aos_agente_acciones', {
    agente_id: agentId, tipo_accion: tipoAccion,
    descripcion: descripcion, metadata: metadata || {}
  }).catch(function(){})
}

// â•â•â• CACHE DE PLANTILLAS â€” Lee de aos_email_plantillas con segmentaciÃ³n â•â•â•
var _tplCache = {} // tipo â†’ array de {body, asunto, segmento, tipo_tratamiento, prioridad}
function loadTplCache() {
  sbFetch('/rest/v1/aos_email_plantillas?select=tipo,html_body,asunto,segmento,tipo_tratamiento,prioridad&activo=eq.true').then(function(rows) {
    if (!rows) return
    _tplCache = {}
    rows.forEach(function(r) {
      if (!r.html_body || r.html_body.length < 10) return
      if (!_tplCache[r.tipo]) _tplCache[r.tipo] = []
      _tplCache[r.tipo].push({
        body: r.html_body, asunto: r.asunto || '',
        segmento: (r.segmento || '').toUpperCase() || null,
        tipo_tratamiento: (r.tipo_tratamiento || '').toUpperCase() || null,
        prioridad: r.prioridad || 0
      })
    })
    // Ordenar cada tipo por prioridad DESC (mÃ¡s especÃ­fica primero)
    Object.keys(_tplCache).forEach(function(k) {
      _tplCache[k].sort(function(a, b) { return (b.prioridad || 0) - (a.prioridad || 0) })
    })
    var total = Object.keys(_tplCache).reduce(function(s, k) { return s + _tplCache[k].length }, 0)
    console.log('[TPL] Cache cargado:', total, 'plantillas en', Object.keys(_tplCache).length, 'tipos')
  }).catch(function(e) { console.log('[TPL] Error cargando cache:', e.message) })
}
setTimeout(loadTplCache, 4000)
setInterval(loadTplCache, 600000) // Recargar cada 10 min

// Construir email desde plantilla BD con segmentaciÃ³n inteligente
// ctx = { segmento: 'VIP', tipo_tratamiento: 'TOXINA' } â€” opcional
function buildFromTemplate(tipo, vars, fallbackFn, ctx) {
  var candidates = _tplCache[tipo]
  if (!candidates || !candidates.length) return fallbackFn()

  var seg = (ctx && ctx.segmento || '').toUpperCase() || null
  var trat = (ctx && ctx.tipo_tratamiento || '').toUpperCase() || null

  // Buscar mejor match: segmento+tratamiento â†’ segmento â†’ tratamiento â†’ genÃ©rica
  var best = null
  for (var i = 0; i < candidates.length; i++) {
    var c = candidates[i]
    var matchSeg = !c.segmento || c.segmento === seg
    var matchTrat = !c.tipo_tratamiento || c.tipo_tratamiento === trat
    if (matchSeg && matchTrat) {
      // Calcular score: +2 si match segmento especÃ­fico, +2 si match tratamiento especÃ­fico
      var score = (c.segmento && c.segmento === seg ? 2 : 0) + (c.tipo_tratamiento && c.tipo_tratamiento === trat ? 2 : 0)
      if (!best || score > best.score) best = { tpl: c, score: score }
    }
  }
  if (!best) {
    // Fallback: buscar genÃ©rica (sin segmento ni tratamiento)
    for (var j = 0; j < candidates.length; j++) {
      if (!candidates[j].segmento && !candidates[j].tipo_tratamiento) { best = { tpl: candidates[j], score: 0 }; break }
    }
  }
  if (!best) return fallbackFn()

  var tpl = best.tpl
  var body = tpl.body
  Object.keys(vars).forEach(function(k) {
    body = body.replace(new RegExp('\\{\\{' + k + '\\}\\}', 'g'), vars[k] || '')
  })
  var asunto = tpl.asunto || ''
  Object.keys(vars).forEach(function(k) {
    asunto = asunto.replace(new RegExp('\\{\\{' + k + '\\}\\}', 'g'), vars[k] || '')
  })
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">' + asunto + '</div>',
    body
  )
}

// Template email recordatorio de cita â€” COMPLETO con direcciÃ³n y estacionamiento
function buildEmailRecordatorio(nombre, tratamiento, hora, sede, fecha, esManana) {
  var titulo = esManana ? 'Te esperamos maÃ±ana' : 'Â¡Tu cita es hoy!'
  var cuando = esManana ? 'maÃ±ana' : 'hoy'
  var esPL = sede && sede.toUpperCase().indexOf('PUEBLO') > -1
  var sedeNombre = esPL ? 'PUEBLO LIBRE' : 'SAN ISIDRO'
  var sedeDir = esPL ? 'Av. Brasil 1170, Pueblo Libre - Lima' : 'Av. Javier Prado Este 996 - Ofi 501 - Lima Â· Edificio Capricornio'
  var sedeMaps = esPL ? 'https://goo.gl/maps/Cw36T6YPudyRNmVe6' : 'https://maps.app.goo.gl/co7ch54zHCt1Nj6w5'

  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">' + titulo + ', ' + (nombre || '').split(' ')[0] + ' ðŸ‘‹</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 20px">Te recordamos que tienes una cita programada para <b>' + cuando + '</b>:</p>' +

    emailCard(
      '<div style="font-size:13px;font-weight:800;color:' + BRAND.color_secundario + ';margin-bottom:12px">ðŸ“Œ TU CITA DE ' + cuando.toUpperCase() + '</div>' +
      '<table style="width:100%;font-size:13px;border-collapse:collapse">' +
      '<tr><td style="padding:5px 0;color:#64748B;width:100px">Servicio:</td><td style="padding:5px 0;font-weight:700;color:' + BRAND.color_secundario + '">' + (tratamiento || '') + '</td></tr>' +
      (fecha ? '<tr><td style="padding:5px 0;color:#64748B">DÃ­a:</td><td style="padding:5px 0;font-weight:600;color:#071D4A">' + fecha + '</td></tr>' : '') +
      '<tr><td style="padding:5px 0;color:#64748B">Hora:</td><td style="padding:5px 0;font-weight:700;color:' + BRAND.color_secundario + '">' + (hora || '') + '</td></tr>' +
      '<tr><td style="padding:5px 0;color:#64748B">Sede:</td><td style="padding:5px 0;font-weight:800;color:' + BRAND.color_secundario + '">' + sedeNombre + '</td></tr>' +
      '</table>'
    ) +

    // DirecciÃ³n
    '<div style="margin-top:12px;padding:14px;background:#F8FAFF;border-radius:10px;border:1px solid #E2E8F0">' +
    '<div style="font-size:11px;font-weight:700;color:#071D4A;margin-bottom:4px">ðŸ“ Sede ' + sedeNombre + '</div>' +
    '<div style="font-size:13px;color:#475569">' + sedeDir + '</div>' +
    '<a href="' + sedeMaps + '" style="display:inline-block;margin-top:6px;font-size:11px;color:' + BRAND.color_secundario + ';font-weight:600;text-decoration:none">Ver en Google Maps â†’</a>' +
    '</div>' +

    // Recomendaciones
    '<div style="margin-top:10px;padding:12px;background:#FFF7ED;border-radius:8px;border:1px solid #FED7AA">' +
    '<p style="color:#92400E;font-size:12px;margin:0">â±ï¸ Llegar <b>15 minutos antes</b> y presentar tu DNI en recepciÃ³n.</p>' +
    '</div>' +

    '<p style="color:#94A3B8;font-size:12px;margin-top:20px">Si necesitas reprogramar, llÃ¡manos o escrÃ­benos por WhatsApp.</p>' +
    '<p style="color:' + BRAND.color_secundario + ';font-size:14px;font-weight:700;text-align:center;margin-top:12px">Â¡TE ESPERAMOS! ðŸ¤—</p>'
  )
}

// Template email bienvenida paciente nuevo (branding dinÃ¡mico)
function buildEmailBienvenida(nombre) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Bienvenida a ' + BRAND.nombre_empresa + ', ' + nombre.split(' ')[0] + ' âœ¨</div>',
    '<p style="color:#475569;font-size:15px">Nos alegra tenerte como parte de nuestra comunidad. En ' + BRAND.nombre_empresa + ' estamos comprometidos con tu bienestar y belleza.</p>' +
    '<p style="color:#475569;font-size:15px">Ante cualquier consulta sobre tus tratamientos o para agendar tu prÃ³xima cita, no dudes en escribirnos.</p>' +
    '<div style="margin-top:24px;text-align:center">' +
    '<a href="mailto:info@zivital.pe" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">ContÃ¡ctanos</a>' +
    '</div>'
  )
}

// Template email confirmaciÃ³n de cita â€” COMPLETO con datos del paciente, direcciÃ³n, estacionamiento
function buildEmailConfirmacionCita(nombre, tratamiento, hora, sede, fecha, datos) {
  var d = datos || {}
  var esPL = sede && sede.toUpperCase().indexOf('PUEBLO') > -1
  var sedeNombre = esPL ? 'PUEBLO LIBRE' : 'SAN ISIDRO'
  var sedeDir = esPL ? 'Av. Brasil 1170, Pueblo Libre - Lima' : 'Av. Javier Prado Este 996 - Ofi 501 - Lima Â· Edificio Capricornio'
  var sedeMaps = esPL ? 'https://goo.gl/maps/Cw36T6YPudyRNmVe6' : 'https://maps.app.goo.gl/co7ch54zHCt1Nj6w5'
  var sedeRef = esPL ? 'A 4 cuadras de la Rambla (en la misma recta)' : ''

  // Estacionamiento por sede
  var estacionamiento = ''
  if (esPL) {
    estacionamiento = '<div style="font-size:11px;font-weight:700;color:#071D4A;margin-bottom:6px">ðŸš— Estacionamiento</div>' +
      '<div style="font-size:11px;color:#475569;line-height:1.6">' +
      'âœ… Frente a nuestra fachada (depende de la hora)<br>' +
      'âœ… <a href="https://maps.app.goo.gl/6uVF3qf4MVbYjGkn9" style="color:' + BRAND.color_secundario + '">Univ. Alas Peruanas</a> â€” Jr. Pedro Ruiz Gallo 251<br>' +
      'âœ… <a href="https://maps.app.goo.gl/aLcsQ2Pg1fmfZU3h6" style="color:' + BRAND.color_secundario + '">C.E.P. Santa MarÃ­a</a> â€” Jr. Pedro Ruiz Gallo 137<br>' +
      'âœ… <a href="https://goo.gl/maps/yhwvXKMothFwQJoH6" style="color:' + BRAND.color_secundario + '">Playa Otorcuna</a> â€” Juan Pablo Fernandini 1255' +
      '</div>'
  } else {
    estacionamiento = '<div style="font-size:11px;font-weight:700;color:#071D4A;margin-bottom:6px">ðŸš— Estacionamiento</div>' +
      '<div style="font-size:11px;color:#475569;line-height:1.6">' +
      'âœ… Frente al Edificio Capricornio (segÃºn disponibilidad)<br>' +
      'âœ… <a href="https://maps.app.goo.gl/omT3RWCxVnrvg4MNA" style="color:' + BRAND.color_secundario + '">Gratuito (mÃ¡x. 3h)</a> â€” Av. Aux. Rep. de PanamÃ¡<br>' +
      'âœ… <a href="https://maps.app.goo.gl/bM6xMzotahK5BQPJ8" style="color:' + BRAND.color_secundario + '">Los Portales</a> â€” C. Ricardo Angulo 197<br>' +
      'âœ… <a href="https://maps.app.goo.gl/YEfCyNqVS5imdkL89" style="color:' + BRAND.color_secundario + '">C.C. Santa Catalina</a> â€” Av. Carlos VillarÃ¡n 500' +
      '</div>'
  }

  // Taxi info para San Isidro
  var taxiInfo = esPL ? '' :
    '<div style="margin-top:10px;padding:10px;background:#EBF5FF;border-radius:8px;border:1px solid #BFDBFE">' +
    '<div style="font-size:11px;font-weight:700;color:#1E40AF">ðŸš– Si vienes en taxi con app</div>' +
    '<div style="font-size:10px;color:#475569;margin-top:4px">Buscar: <b>Av. Javier Prado Este 996, San Isidro</b> o <b>ZI VITAL SAN ISIDRO</b><br>' +
    'âš ï¸ YANGO: usar <i>Av Pablo Carriquiry 106, San Isidro</i> (esquina del edificio)</div></div>'

  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">AquÃ­ te envÃ­o tu confirmaciÃ³n de cita â™¥</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 6px">Hola <b>' + (nombre || '').split(' ')[0] + '</b>, tu cita ha sido registrada exitosamente.</p>' +
    '<p style="color:#475569;font-size:12px;margin:0 0 20px">Te saluda tu Asesora de salud de la ClÃ­nica EstÃ©tica Zi Vital ðŸ¥ðŸ‘©â€âš•ï¸</p>' +

    // Card de datos de la cita
    emailCard(
      '<div style="font-size:13px;font-weight:800;color:' + BRAND.color_secundario + ';margin-bottom:12px">ðŸ“Œ CITA CONFIRMADA</div>' +
      '<table style="width:100%;font-size:13px;border-collapse:collapse">' +
      '<tr><td style="padding:6px 0;color:#64748B;width:130px">Nombre:</td><td style="padding:6px 0;font-weight:600;color:#071D4A">' + (nombre || '') + '</td></tr>' +
      (d.dni ? '<tr><td style="padding:6px 0;color:#64748B">DNI / C.E:</td><td style="padding:6px 0;font-weight:600;color:#071D4A">' + d.dni + '</td></tr>' : '') +
      (d.email ? '<tr><td style="padding:6px 0;color:#64748B">E-mail:</td><td style="padding:6px 0;color:#071D4A">' + d.email + '</td></tr>' : '') +
      (d.telefono ? '<tr><td style="padding:6px 0;color:#64748B">TelÃ©fono:</td><td style="padding:6px 0;color:#071D4A">' + d.telefono + '</td></tr>' : '') +
      '<tr><td style="padding:6px 0;color:#64748B">DÃ­a:</td><td style="padding:6px 0;font-weight:700;color:' + BRAND.color_secundario + '">' + (fecha || '') + '</td></tr>' +
      '<tr><td style="padding:6px 0;color:#64748B">Horario:</td><td style="padding:6px 0;font-weight:700;color:' + BRAND.color_secundario + '">' + (hora || '') + '</td></tr>' +
      '<tr><td style="padding:6px 0;color:#64748B">Servicio:</td><td style="padding:6px 0;font-weight:700;color:' + BRAND.color_secundario + '">' + (tratamiento || '') + '</td></tr>' +
      '<tr><td style="padding:6px 0;color:#64748B">Sede:</td><td style="padding:6px 0;font-weight:800;color:' + BRAND.color_secundario + '">' + sedeNombre + '</td></tr>' +
      '</table>'
    ) +

    // DirecciÃ³n con mapa
    '<div style="margin-top:16px;padding:14px;background:#F8FAFF;border-radius:10px;border:1px solid #E2E8F0">' +
    '<div style="font-size:11px;font-weight:700;color:#071D4A;margin-bottom:4px">ðŸ“ Sede ' + sedeNombre + '</div>' +
    '<div style="font-size:13px;color:#475569">' + sedeDir + '</div>' +
    (sedeRef ? '<div style="font-size:11px;color:#94A3B8;margin-top:2px">' + sedeRef + '</div>' : '') +
    '<a href="' + sedeMaps + '" style="display:inline-block;margin-top:8px;font-size:11px;color:' + BRAND.color_secundario + ';font-weight:600;text-decoration:none">ðŸ“ Ver en Google Maps â†’</a>' +
    '</div>' +

    // Recomendaciones
    '<div style="margin-top:12px;padding:14px;background:#FFF7ED;border-radius:8px;border:1px solid #FED7AA">' +
    '<p style="color:#92400E;font-size:12px;margin:0">â±ï¸ Llegar <b>15 minutos antes</b> y presentar su DNI en recepciÃ³n.</p>' +
    '<p style="color:#92400E;font-size:11px;margin:6px 0 0">âœ”ï¸ La consulta/tratamiento es personalizado. Puede haber tiempo de espera segÃºn la afluencia. Agradecemos su comprensiÃ³n.</p>' +
    '</div>' +

    // Estacionamiento
    '<div style="margin-top:12px;padding:14px;background:#F0FDF4;border-radius:8px;border:1px solid #BBF7D0">' +
    estacionamiento +
    '</div>' +

    taxiInfo +

    '<p style="color:#94A3B8;font-size:11px;margin-top:20px;text-align:center">ðŸ“± AgrÃ©ganos a tus contactos como <b>ZI VITAL</b> para recibir recordatorios y cupones de descuento.</p>' +
    '<p style="color:' + BRAND.color_secundario + ';font-size:14px;font-weight:700;text-align:center;margin-top:16px">Â¡TE ESPERAMOS! ðŸ¤—</p>'
  )
}

// Template email recibo de venta (nueva â€” branding dinÃ¡mico)
function buildEmailReciboVenta(nombre, items, total, moneda, metodoPago, sede, fecha, ventaId) {
  var sym = moneda === 'USD' ? '$ ' : 'S/ '
  var itemsHtml = ''
  if (items && items.length) {
    items.forEach(function(it) {
      itemsHtml += '<tr style="border-bottom:1px solid #F1F5F9">' +
        '<td style="padding:10px 12px;font-size:13px;color:#334155">' + (it.nombre || it.tratamiento || '') + '</td>' +
        '<td style="padding:10px 12px;font-size:13px;text-align:center;color:#64748B">' + (it.cantidad || 1) + '</td>' +
        '<td style="padding:10px 12px;font-size:13px;text-align:right;font-weight:600;color:#334155">' + sym + parseFloat(it.subtotal || it.monto || 0).toFixed(2) + '</td>' +
        '</tr>'
    })
  }
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Recibo de pago ðŸ§¾</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 20px">Hola <b>' + nombre.split(' ')[0] + '</b>, aquÃ­ tienes el detalle de tu compra.</p>' +
    emailCard(
      '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">' +
      '<span style="font-size:11px;color:#94A3B8">Nro. OperaciÃ³n</span>' +
      '<span style="font-size:13px;font-weight:700;color:' + BRAND.color_secundario + '">' + (ventaId || 'â€”') + '</span>' +
      '</div>' +
      '<div style="display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px">' +
      emailInfoBox('Fecha', fecha || '') + emailInfoBox('Sede', sede || '') + emailInfoBox('MÃ©todo', metodoPago || '') +
      '</div>'
    ) +
    '<table style="width:100%;border-collapse:collapse;margin-bottom:16px">' +
    '<thead><tr style="background:' + BRAND.color_primario + '">' +
    '<th style="padding:10px 12px;text-align:left;font-size:11px;font-weight:700;color:#64748B;text-transform:uppercase;letter-spacing:.3px">Servicio / Producto</th>' +
    '<th style="padding:10px 12px;text-align:center;font-size:11px;font-weight:700;color:#64748B;text-transform:uppercase">Cant.</th>' +
    '<th style="padding:10px 12px;text-align:right;font-size:11px;font-weight:700;color:#64748B;text-transform:uppercase">Subtotal</th>' +
    '</tr></thead><tbody>' + itemsHtml + '</tbody>' +
    '<tfoot><tr style="background:' + BRAND.color_primario + '">' +
    '<td colspan="2" style="padding:12px;text-align:right;font-size:14px;font-weight:700;color:#334155">TOTAL</td>' +
    '<td style="padding:12px;text-align:right;font-size:16px;font-weight:800;color:' + BRAND.color_secundario + '">' + sym + parseFloat(total || 0).toFixed(2) + '</td>' +
    '</tr></tfoot></table>' +
    '<div style="margin-top:20px;padding:14px;background:#F8FAFC;border-radius:8px;border:1px solid #E2E8F0">' +
    '<div style="font-size:8px;font-weight:700;color:#94A3B8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px">TÃ©rminos y condiciones</div>' +
    '<div style="font-size:8px;color:#94A3B8;line-height:1.5">' +
    'â€¢ Algunas promociones aplican Ãºnicamente para pagos en efectivo, transferencia, Yape o Plin. No aplican con tarjeta de dÃ©bito o crÃ©dito.<br>' +
    'â€¢ No se realizan devoluciones post pago. En caso de requerir cambio, se emitirÃ¡ un cupÃ³n por servicios del mismo monto o mayor. No aplica para productos.<br>' +
    'â€¢ Las cotizaciones tienen validez de 7 dÃ­as calendario. Posterior a ello, los precios estÃ¡n sujetos a cambios sin previo aviso.<br>' +
    'â€¢ Este recibo es un comprobante interno de ' + BRAND.nombre_empresa + '. No constituye factura ni boleta fiscal.' +
    '</div></div>'
  )
}

// Template email seguimiento post-tratamiento (nueva â€” branding dinÃ¡mico)
function buildEmailSeguimiento(nombre, tratamiento, diasDesde) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Â¿CÃ³mo te fue con tu tratamiento? ðŸ’†â€â™€ï¸</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 20px">Hola <b>' + nombre.split(' ')[0] + '</b>, hace ' + diasDesde + ' dÃ­as realizaste tu tratamiento de <b>' + tratamiento + '</b> y queremos saber cÃ³mo te sientes.</p>' +
    emailCard(
      '<div style="font-size:14px;color:#475569">Tu bienestar es nuestra prioridad. Si tienes alguna consulta sobre los resultados o cuidados posteriores, estamos aquÃ­ para ayudarte.</div>'
    ) +
    '<div style="margin-top:20px;text-align:center">' +
    '<a href="https://wa.me/51999999999?text=Hola%2C%20quiero%20consultar%20sobre%20mi%20tratamiento%20de%20' + encodeURIComponent(tratamiento) + '" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">EscrÃ­benos por WhatsApp</a>' +
    '</div>' +
    '<p style="color:#94A3B8;font-size:12px;margin-top:20px;text-align:center">Â¿Lista para tu prÃ³xima sesiÃ³n? Agenda tu cita respondiendo a este correo.</p>'
  )
}

// â•â•â• TEMPLATE: Agradecimiento post-visita â•â•â•
function buildEmailAgradecimiento(nombre, tratamiento, sede, fecha) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Â¡Gracias por tu visita! ðŸŒŸ</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 16px">Hola <b>' + (nombre||'').split(' ')[0] + '</b>, fue un placer atenderte en tu tratamiento de <b>' + (tratamiento||'') + '</b>' + (sede ? ' en nuestra sede de <b>' + sede + '</b>' : '') + '.</p>' +
    emailCard(
      '<div style="font-size:14px;color:#475569;line-height:1.6">Tu bienestar y satisfacciÃ³n son nuestra prioridad. Esperamos que los resultados superen tus expectativas. ðŸ’†â€â™€ï¸</div>' +
      '<div style="font-size:12px;color:#6B7BA8;margin-top:8px">Si tienes alguna consulta sobre los cuidados posteriores de tu tratamiento, no dudes en escribirnos.</div>'
    ) +
    '<div style="text-align:center;margin-top:20px">' +
    '<a href="https://wa.me/51960618468?text=Hola%2C%20quiero%20consultar%20sobre%20mi%20tratamiento" style="display:inline-block;background:#25D366;color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">ðŸ’¬ EscrÃ­benos por WhatsApp</a>' +
    '</div>' +
    '<p style="color:' + BRAND.color_secundario + ';font-size:14px;font-weight:700;text-align:center;margin-top:20px">Â¡Nos vemos pronto! ðŸ¤—</p>'
  )
}

// â•â•â• TEMPLATE: Recordatorio saldo pendiente â•â•â•
function buildEmailSaldoPendiente(nombre, items) {
  var detalleHtml = (items||[]).map(function(it) {
    return '<tr><td style="padding:8px 12px;font-size:13px;font-weight:600;color:#334155">' + (it.tratamiento||'') + '</td>' +
      '<td style="padding:8px 12px;text-align:right;font-size:13px;color:#059669;font-weight:600">S/ ' + parseFloat(it.pagado||0).toFixed(2) + '</td>' +
      '<td style="padding:8px 12px;text-align:right;font-size:13px;color:#DC2626;font-weight:700">S/ ' + parseFloat(it.saldo||0).toFixed(2) + '</td></tr>'
  }).join('')
  var totalSaldo = (items||[]).reduce(function(s,it){return s+parseFloat(it.saldo||0)},0)
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Tienes un saldo pendiente ðŸ’³</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 16px">Hola <b>' + (nombre||'').split(' ')[0] + '</b>, te recordamos que tienes pagos pendientes por completar:</p>' +
    '<table style="width:100%;border-collapse:collapse;margin-bottom:16px">' +
    '<thead><tr style="background:' + BRAND.color_primario + '"><th style="padding:8px 12px;text-align:left;font-size:10px;font-weight:700;color:#64748B;text-transform:uppercase">Tratamiento</th><th style="padding:8px 12px;text-align:right;font-size:10px;font-weight:700;color:#64748B">Pagado</th><th style="padding:8px 12px;text-align:right;font-size:10px;font-weight:700;color:#64748B">Pendiente</th></tr></thead>' +
    '<tbody>' + detalleHtml + '</tbody>' +
    '<tfoot><tr style="background:' + BRAND.color_primario + '"><td style="padding:10px 12px;font-weight:700">TOTAL PENDIENTE</td><td></td><td style="padding:10px 12px;text-align:right;font-size:16px;font-weight:800;color:#DC2626">S/ ' + totalSaldo.toFixed(2) + '</td></tr></tfoot></table>' +
    '<p style="color:#475569;font-size:13px">Puedes acercarte a cualquiera de nuestras sedes para completar tu pago, o comunÃ­cate con nosotros para coordinar.</p>' +
    '<div style="text-align:center;margin-top:16px"><a href="https://wa.me/51960618468?text=Hola%2C%20quiero%20coordinar%20mi%20pago%20pendiente" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">Coordinar pago</a></div>'
  )
}

// â•â•â• TEMPLATE: CumpleaÃ±os â•â•â•
function buildEmailCumpleanos(nombre) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Â¡Feliz cumpleaÃ±os, ' + (nombre||'').split(' ')[0] + '! ðŸŽ‚ðŸŽ‰</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 16px">En <b>' + BRAND.nombre_empresa + '</b> queremos celebrar contigo este dÃ­a tan especial.</p>' +
    emailCard(
      '<div style="text-align:center">' +
      '<div style="font-size:40px;margin-bottom:8px">ðŸŽ</div>' +
      '<div style="font-size:18px;font-weight:800;color:' + BRAND.color_secundario + ';margin-bottom:4px">Â¡Te regalamos un 10% de descuento!</div>' +
      '<div style="font-size:13px;color:#6B7BA8">En tu prÃ³ximo tratamiento este mes. Solo menciona este correo al momento de tu visita.</div>' +
      '</div>'
    ) +
    '<p style="color:#475569;font-size:13px;text-align:center">Agenda tu cita y disfruta de tu regalo de cumpleaÃ±os. ðŸ¥³</p>' +
    '<div style="text-align:center;margin-top:16px"><a href="https://wa.me/51960618468?text=Hola%2C%20quiero%20agendar%20mi%20cita%20de%20cumplea%C3%B1os" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">ðŸŽ‚ Agendar mi cita</a></div>'
  )
}

// â•â•â• TEMPLATE: ReactivaciÃ³n paciente inactivo â•â•â•
function buildEmailReactivacion(nombre, ultimoTrat, diasSinVisita) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Te extraÃ±amos, ' + (nombre||'').split(' ')[0] + ' ðŸ’š</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 16px">Han pasado <b>' + (diasSinVisita||'') + ' dÃ­as</b> desde tu Ãºltimo tratamiento' + (ultimoTrat ? ' de <b>' + ultimoTrat + '</b>' : '') + ' en ' + BRAND.nombre_empresa + '.</p>' +
    emailCard(
      '<div style="font-size:14px;color:#475569;line-height:1.6">Tu piel y tu bienestar nos importan. Queremos que sigas disfrutando de los beneficios de nuestros tratamientos con las mejores condiciones.</div>'
    ) +
    '<div style="margin-top:16px;padding:16px;background:#F0FDF4;border-radius:10px;border:1px solid #BBF7D0;text-align:center">' +
    '<div style="font-size:16px;font-weight:800;color:#059669;margin-bottom:4px">ðŸŒ¿ Condiciones especiales para tu regreso</div>' +
    '<div style="font-size:13px;color:#475569">Agenda tu cita esta semana y recibe atenciÃ³n preferencial.</div>' +
    '</div>' +
    '<div style="text-align:center;margin-top:20px"><a href="https://wa.me/51960618468?text=Hola%2C%20quiero%20reagendar%20mi%20tratamiento" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">ðŸ’¬ Quiero volver</a></div>'
  )
}

// â•â•â• TEMPLATE: No asistencia â•â•â•
function buildEmailNoAsistencia(nombre, tratamiento, fecha, hora, sede) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Lamentamos que no hayas podido asistir ðŸ˜”</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 16px">Hola <b>' + (nombre||'').split(' ')[0] + '</b>, notamos que no pudiste asistir a tu cita de <b>' + (tratamiento||'') + '</b> programada para el ' + (fecha||'') + ' a las ' + (hora||'') + '.</p>' +
    emailCard(
      '<div style="font-size:14px;color:#475569">Entendemos que pueden surgir imprevistos. Tu salud y bienestar siguen siendo nuestra prioridad, y queremos ayudarte a reprogramar tu cita sin ningÃºn inconveniente.</div>'
    ) +
    '<div style="text-align:center;margin-top:20px"><a href="https://wa.me/51960618468?text=Hola%2C%20quiero%20reprogramar%20mi%20cita%20de%20' + encodeURIComponent(tratamiento||'') + '" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">ðŸ”„ Reprogramar mi cita</a></div>' +
    '<p style="color:#94A3B8;font-size:12px;margin-top:16px;text-align:center">TambiÃ©n puedes llamarnos o escribirnos por WhatsApp para coordinar una nueva fecha.</p>'
  )
}

// â•â•â• TEMPLATE: ConfirmaciÃ³n de pago â•â•â•
function buildEmailConfirmacionPago(nombre, tratamiento, monto, saldoActual, metodoPago) {
  var saldoHtml = parseFloat(saldoActual||0) > 0.01 ?
    '<div style="margin-top:16px;padding:14px;background:#FEF3C7;border-radius:10px;border:1px solid #FDE68A">' +
    '<div style="font-size:13px;color:#92400E;font-weight:700">ðŸ’° Saldo pendiente: S/ ' + parseFloat(saldoActual).toFixed(2) + '</div>' +
    '<div style="font-size:11px;color:#92400E;margin-top:4px">Puedes completar tu pago en tu prÃ³xima visita o comunicÃ¡ndote con nosotros.</div></div>' :
    '<div style="margin-top:16px;padding:14px;background:#F0FDF4;border-radius:10px;border:1px solid #BBF7D0;text-align:center">' +
    '<div style="font-size:16px;margin-bottom:4px">ðŸŽ‰</div>' +
    '<div style="font-size:14px;font-weight:700;color:#059669">Pago completo â€” Sin saldo pendiente</div></div>'
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Â¡Pago recibido con Ã©xito! âœ…</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 20px">Hola <b>' + (nombre||'').split(' ')[0] + '</b>, muchas gracias por tu confianza. Confirmamos que hemos recibido tu pago:</p>' +
    // Card principal de pago
    '<div style="background:linear-gradient(135deg,' + BRAND.color_primario + ',' + BRAND.color_degradado2 + ');border-radius:14px;padding:24px;margin-bottom:16px;text-align:center">' +
    '<div style="font-size:11px;color:#6B7BA8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px">Monto recibido</div>' +
    '<div style="font-size:36px;font-weight:800;color:#059669;font-family:Exo 2,sans-serif">S/ ' + parseFloat(monto||0).toFixed(2) + '</div>' +
    '<div style="margin-top:12px;display:flex;justify-content:center;gap:20px;flex-wrap:wrap">' +
    emailInfoBox('Servicio', tratamiento||'') +
    (metodoPago ? emailInfoBox('MÃ©todo', metodoPago) : '') +
    '</div></div>' +
    saldoHtml +
    // Agradecimiento
    '<p style="color:#475569;font-size:13px;margin-top:20px;text-align:center">Agradecemos tu preferencia. Tu bienestar es nuestra prioridad. ðŸ’†â€â™€ï¸</p>' +
    '<div style="text-align:center;margin-top:12px"><a href="https://wa.me/51960618468" style="display:inline-block;background:#25D366;color:#fff;font-weight:700;padding:10px 24px;border-radius:8px;text-decoration:none;font-size:13px">ðŸ’¬ Â¿Consultas? EscrÃ­benos</a></div>' +
    // TÃ©rminos y condiciones
    '<div style="margin-top:24px;padding:14px;background:#F8FAFC;border-radius:8px;border:1px solid #E2E8F0">' +
    '<div style="font-size:8px;font-weight:700;color:#94A3B8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px">TÃ©rminos y condiciones</div>' +
    '<div style="font-size:8px;color:#94A3B8;line-height:1.5">' +
    'â€¢ Algunas promociones aplican Ãºnicamente para pagos en efectivo, transferencia, Yape o Plin. No aplican con tarjeta de dÃ©bito o crÃ©dito.<br>' +
    'â€¢ No se realizan devoluciones post pago. En caso de requerir cambio, se emitirÃ¡ un cupÃ³n por servicios del mismo monto o mayor. No aplica para productos.<br>' +
    'â€¢ Las cotizaciones tienen validez de 7 dÃ­as calendario. Posterior a ello, los precios estÃ¡n sujetos a cambios sin previo aviso.<br>' +
    'â€¢ Este comprobante es un documento interno de ' + BRAND.nombre_empresa + ' y no constituye boleta ni factura fiscal.' +
    '</div></div>'
  )
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// EJECUTOR DE ACCIONES â€” se llama despuÃ©s de sql_query si hay accion
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
function executeAction(agent, task, queryResult) {
  var accion = (task.input_config || {}).accion
  var template = (task.input_config || {}).template
  if (!accion) return Promise.resolve()

  var data = (queryResult && queryResult.data) ? queryResult.data : []
  if (!data.length) {
    console.log('[ACTION] ' + agent.nombre + ' â€” ' + accion + ': sin datos, nada que hacer')
    return Promise.resolve()
  }

  // â•â•â• ENVÃO EN LOTES â€” evitar rate limiting de Resend â•â•â•
  // EnvÃ­a de a 3 emails, espera 2 segundos entre lotes
  // Al final envÃ­a reporte al admin (CÃ©sar)
  function sendInBatches(emails, batchSize, delayMs) {
    var results = { ok: 0, skip: 0, fail: 0, errors: [] }
    var batches = []
    for (var i = 0; i < emails.length; i += batchSize) {
      batches.push(emails.slice(i, i + batchSize))
    }
    var chain = Promise.resolve()
    batches.forEach(function(batch, bIdx) {
      chain = chain.then(function() {
        return Promise.all(batch.map(function(e) {
          return e.sendFn().then(function(r) {
            if (r && r.skip) { results.skip++; console.log('[CARTERO] Skip ' + e.email + ' â€” ya enviado') }
            else if (r && r.ok) { results.ok++; console.log('[CARTERO] âœ“ ' + e.email) }
            else { results.fail++; results.errors.push(e.email + ': respuesta inesperada'); console.log('[CARTERO] âš  ' + e.email + ' â€” sin confirmaciÃ³n') }
          }).catch(function(err) {
            results.fail++; results.errors.push(e.email + ': ' + (err.message || err))
            console.log('[CARTERO] âœ• ' + e.email + ' â€” ' + (err.message || err))
          })
        })).then(function() {
          if (bIdx < batches.length - 1) {
            return new Promise(function(res) { setTimeout(res, delayMs) })
          }
        })
      })
    })
    return chain.then(function() { return results })
  }

  // Guardar alerta en panel (siempre)
  function saveEmailAlerta(tipo, template, titulo, detalle, destinatario, resendId) {
    var body = JSON.stringify({ tipo: tipo, template: template, titulo: titulo, detalle: detalle || '', destinatario: destinatario || '', resend_id: resendId || '' })
    if (!EMAIL_SB_KEY) return
    var url = new URL(SB_URL + '/rest/v1/aos_email_alertas')
    var req = https.request({ hostname: url.hostname, path: url.pathname, method: 'POST',
      headers: { 'apikey': EMAIL_SB_KEY, 'Authorization': 'Bearer ' + EMAIL_SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(body) }
    }, function(){})
    req.on('error', function(){})
    req.write(body); req.end()
  }

  function sendAdminReport(agent, template, results, totalData) {
    var status = results.fail > 0 ? 'âš ï¸' : 'âœ…'
    var titulo = status + ' ' + template + ' â€” ' + results.ok + '/' + totalData + ' enviados'
    var detalle = 'OK:' + results.ok + ' Skip:' + results.skip + ' Fail:' + results.fail
    if (results.errors.length) detalle += ' | Errores: ' + results.errors.join(', ')

    // SIEMPRE guardar alerta en panel
    saveEmailAlerta(results.fail > 0 ? 'error' : 'exito', template, titulo, detalle)

    // Solo enviar reporte por email si son 3+ envÃ­os
    if (totalData < 3) {
      console.log('[CARTERO] Reporte unitario, solo alerta panel: ' + titulo)
      return
    }

    var adminEmail = 'jaureguitorrescesar@gmail.com'
    var subject = status + ' Elena: ' + template + ' â€” ' + results.ok + '/' + totalData
    var errorList = results.errors.length ? '<div style="margin-top:12px;padding:12px;background:#FEF2F2;border-radius:8px;border:1px solid #FECACA"><div style="font-size:11px;font-weight:700;color:#DC2626;margin-bottom:6px">Errores (' + results.fail + '):</div><div style="font-size:10px;color:#991B1B">' + results.errors.join('<br>') + '</div></div>' : ''
    var html = emailShell(
      '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:20px;font-weight:800">ðŸ“Š Reporte de envÃ­o â€” Elena</div>',
      '<div style="display:flex;gap:12px;flex-wrap:wrap;margin-bottom:16px">' +
      '<div style="flex:1;min-width:80px;padding:12px;background:#F0FDF4;border-radius:8px;text-align:center"><div style="font-size:22px;font-weight:800;color:#059669">' + results.ok + '</div><div style="font-size:9px;color:#6B7BA8">Enviados</div></div>' +
      '<div style="flex:1;min-width:80px;padding:12px;background:#F0F4FC;border-radius:8px;text-align:center"><div style="font-size:22px;font-weight:800;color:#0A4FBF">' + results.skip + '</div><div style="font-size:9px;color:#6B7BA8">Ya enviados</div></div>' +
      '<div style="flex:1;min-width:80px;padding:12px;background:' + (results.fail > 0 ? '#FEF2F2' : '#F0FDF4') + ';border-radius:8px;text-align:center"><div style="font-size:22px;font-weight:800;color:' + (results.fail > 0 ? '#DC2626' : '#059669') + '">' + results.fail + '</div><div style="font-size:9px;color:#6B7BA8">Fallidos</div></div>' +
      '<div style="flex:1;min-width:80px;padding:12px;background:#F8FAFF;border-radius:8px;text-align:center"><div style="font-size:22px;font-weight:800;color:#071D4A">' + totalData + '</div><div style="font-size:9px;color:#6B7BA8">Total</div></div>' +
      '</div>' +
      '<p style="font-size:13px;color:#475569"><b>Tipo:</b> ' + template + ' Â· <b>Hora:</b> ' + new Date(Date.now() + (-5*60)*60000).toISOString().replace('T', ' ').slice(11,19) + ' Lima</p>' +
      errorList
    )
    fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + RESEND_KEY_AG, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: 'ClÃ­nica Zi Vital <info@zivital.pe>', to: [adminEmail], subject: subject, html: html })
    }).catch(function(e) { console.log('[CARTERO] Error reporte admin: ' + e.message) })
  }

  // â”€â”€â”€ CARTERO: enviar emails reales â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'recordatorio_manana') {
    var emails = data.filter(function(c) { return c.correo }).map(function(cita) {
      return {
        email: cita.correo,
        sendFn: function() {
          var html = buildEmailRecordatorio(cita.nombre, cita.tratamiento, cita.hora_cita, cita.sede, cita.fecha_cita, true)
          return sendAgentEmail(cita.correo, 'Tu cita de maÃ±ana en Zi Vital â€” ' + cita.hora_cita, html, 'recordatorio_manana', cita.correo + '_' + cita.fecha_cita)
            .then(function(r) {
              if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Recordatorio maÃ±ana â†’ ' + cita.nombre, { correo: cita.correo, tratamiento: cita.tratamiento })
              return r
            })
        }
      }
    })
    return sendInBatches(emails, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸ“§ ' + results.ok + '/' + emails.length + ' recordatorios maÃ±ana âœ“' })
      sendAdminReport(agent, 'recordatorio_manana', results, data.length)
    })
  }

  if (accion === 'send_email' && template === 'recordatorio_hoy') {
    var emails2 = data.filter(function(c) { return c.correo }).map(function(cita) {
      return {
        email: cita.correo,
        sendFn: function() {
          var html = buildEmailRecordatorio(cita.nombre, cita.tratamiento, cita.hora_cita, cita.sede, cita.fecha_cita, false)
          return sendAgentEmail(cita.correo, 'Â¡Tu cita es hoy! ' + cita.hora_cita + ' â€” Zi Vital', html, 'recordatorio_hoy', cita.correo + '_' + cita.fecha_cita)
            .then(function(r) {
              if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Recordatorio hoy â†’ ' + cita.nombre, { correo: cita.correo })
              return r
            })
        }
      }
    })
    return sendInBatches(emails2, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸ“§ ' + results.ok + '/' + emails2.length + ' recordatorios hoy âœ“' })
      sendAdminReport(agent, 'recordatorio_hoy', results, data.length)
    })
  }

  if (accion === 'send_email' && template === 'bienvenida') {
    var sends3 = data.map(function(p) {
      if (!p['Email'] && !p.email) return Promise.resolve()
      var email = p['Email'] || p.email
      var nombre = p['Nombres'] || p.nombre || 'Paciente'
      var html = buildEmailBienvenida(nombre)
      return sendAgentEmail(email, 'Â¡Bienvenida a Zi Vital, ' + nombre.split(' ')[0] + '! âœ¨', html, 'bienvenida', p.numero_limpio || email)
        .then(function(r) {
          if (r.ok) logAction(agent.id, 'email_enviado', 'Email bienvenida â†’ ' + nombre, { email: email })
        })
    })
    return Promise.all(sends3)
  }

  // â”€â”€â”€ CARTERO: comprobante de ventas del dÃ­a (11pm) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'recibo_venta') {
    var emails4 = data.filter(function(v) { return v.correo }).map(function(venta) {
      return {
        email: venta.correo,
        sendFn: function() {
          var nombre = (venta.nombres || '') + ' ' + (venta.apellidos || '')
          var items = [{ nombre: venta.detalle_items || 'Servicios del dÃ­a', cantidad: 1, subtotal: venta.total }]
          var html = buildEmailReciboVenta(nombre, items, venta.total, 'PEN', '', venta.sede || '', venta.fecha || '', '')
          return sendAgentEmail(venta.correo, 'ðŸ§¾ Tu comprobante de hoy â€” Zi Vital', html, 'recibo_venta', venta.correo + '_' + venta.fecha)
            .then(function(r) {
              if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Comprobante venta â†’ ' + nombre.trim(), { correo: venta.correo, total: venta.total })
              return r
            })
        }
      }
    })
    return sendInBatches(emails4, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸ§¾ ' + results.ok + '/' + emails4.length + ' comprobantes âœ“' })
      sendAdminReport(agent, 'recibo_venta', results, data.length)
    })
  }

  // â”€â”€â”€ CARTERO: agradecimiento post-visita â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'agradecimiento_visita') {
    var emails5 = data.filter(function(v) { return v.correo }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var html = buildEmailAgradecimiento(p.nombre, p.tratamiento, p.sede, p.fecha)
        return sendAgentEmail(p.correo, 'ðŸŒŸ Â¡Gracias por tu visita! â€” Zi Vital', html, 'agradecimiento_visita', p.correo + '_' + (p.fecha || ''))
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Agradecimiento â†’ ' + p.nombre, { correo: p.correo }); return r })
      }}
    })
    return sendInBatches(emails5, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸŒŸ ' + results.ok + ' agradecimientos âœ“' })
      sendAdminReport(agent, 'agradecimiento_visita', results, data.length)
    })
  }

  // â”€â”€â”€ CARTERO: saldos pendientes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'saldo_pendiente') {
    var emails6 = data.filter(function(v) { return v.correo }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var items = [{ tratamiento: p.tratamiento || '', pagado: p.pagado || 0, saldo: p.saldo || 0 }]
        var html = buildEmailSaldoPendiente(p.nombre, items)
        return sendAgentEmail(p.correo, 'ðŸ’³ Saldo pendiente â€” Zi Vital', html, 'saldo_pendiente', p.correo + '_saldo_semanal')
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Saldo pendiente â†’ ' + p.nombre, { correo: p.correo, saldo: p.saldo }); return r })
      }}
    })
    return sendInBatches(emails6, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸ’³ ' + results.ok + ' recordatorios saldo âœ“' })
      sendAdminReport(agent, 'saldo_pendiente', results, data.length)
    })
  }

  // â”€â”€â”€ CARTERO: cumpleaÃ±os â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'cumpleanos') {
    var emails7 = data.filter(function(v) { return v.correo }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var html = buildEmailCumpleanos(p.nombre)
        return sendAgentEmail(p.correo, 'ðŸŽ‚ Â¡Feliz cumpleaÃ±os! â€” Zi Vital', html, 'cumpleanos', p.correo + '_cumple_' + new Date().getFullYear())
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'CumpleaÃ±os â†’ ' + p.nombre, { correo: p.correo }); return r })
      }}
    })
    return sendInBatches(emails7, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸŽ‚ ' + results.ok + ' cumpleaÃ±os âœ“' })
      sendAdminReport(agent, 'cumpleanos', results, data.length)
    })
  }

  // â”€â”€â”€ CARTERO: reactivaciÃ³n â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'reactivacion') {
    var emails8 = data.filter(function(v) { return v.correo }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var html = buildEmailReactivacion(p.nombre, p.ultimo_tratamiento, p.dias_sin_visita)
        return sendAgentEmail(p.correo, 'ðŸ’š Te extraÃ±amos â€” Zi Vital', html, 'reactivacion', p.correo + '_reactiv_' + new Date().toISOString().slice(0,7))
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'ReactivaciÃ³n â†’ ' + p.nombre, { correo: p.correo, dias: p.dias_sin_visita }); return r })
      }}
    })
    return sendInBatches(emails8, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸ’š ' + results.ok + ' reactivaciones âœ“' })
      sendAdminReport(agent, 'reactivacion', results, data.length)
    })
  }

  // â”€â”€â”€ CARTERO: no asistiÃ³ â€” reprogramar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'no_asistencia') {
    var emails9 = data.filter(function(v) { return v.correo && validarEmail(v.correo) }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var html = buildEmailNoAsistencia(p.nombre, p.tratamiento, p.fecha, p.hora, p.sede)
        return sendAgentEmail(p.correo, 'ðŸ˜” Lamentamos que no hayas podido asistir â€” Zi Vital', html, 'no_asistencia', p.correo + '_noasist_' + (p.fecha || ''))
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'No asistiÃ³ â†’ ' + p.nombre, { correo: p.correo }); return r })
      }}
    })
    return sendInBatches(emails9, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸ˜” ' + results.ok + ' no asistencia âœ“' })
      sendAdminReport(agent, 'no_asistencia', results, data.length)
    })
  }

  // â”€â”€â”€ CARTERO: seguimiento 7d post-procedimiento â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'seguimiento') {
    var emails10 = data.filter(function(v) { return v.correo && validarEmail(v.correo) }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var html = buildEmailSeguimiento(p.nombre, p.tratamiento, 7)
        return sendAgentEmail(p.correo, 'ðŸ’†â€â™€ï¸ Â¿CÃ³mo te fue con tu ' + (p.tratamiento || 'tratamiento') + '? â€” Zi Vital', html, 'seguimiento', p.correo + '_seg_' + (p.fecha || ''))
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Seguimiento 7d â†’ ' + p.nombre, { correo: p.correo, tratamiento: p.tratamiento }); return r })
      }}
    })
    return sendInBatches(emails10, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸ’† ' + results.ok + ' seguimientos âœ“' })
      sendAdminReport(agent, 'seguimiento', results, data.length)
    })
  }

  // â”€â”€â”€ CARTERO: reposiciÃ³n de productos de receta â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'reposicion_producto') {
    var emails11 = data.filter(function(v) { return v.correo && validarEmail(v.correo) }).map(function(p) {
      // Verificar quÃ© productos estÃ¡n por acabarse
      var items = []
      try {
        var receta = typeof p.receta_items === 'string' ? JSON.parse(p.receta_items) : (p.receta_items || [])
        var fechaReceta = new Date(p.fecha_receta)
        receta.forEach(function(it) {
          var diasRestantes = (it.dias || 30) - Math.floor((Date.now() - fechaReceta.getTime()) / 86400000)
          if (diasRestantes <= 5 && diasRestantes >= -5) items.push(it)
        })
      } catch(e) {}
      if (!items.length) return null
      return { email: p.correo, sendFn: function() {
        var prods = items.map(function(it) { return it.nombre }).join(', ')
        var html = emailShell('Tu producto estÃ¡ por terminarse',
          '<p>Hola <b>' + p.nombre + '</b>,</p>' +
          '<p>Tu tratamiento con <b>' + prods + '</b> estÃ¡ por completarse.</p>' +
          '<p>Para continuar con los resultados, te recomendamos renovar a tiempo. Puedes pedirlo en tu prÃ³xima visita o contactarnos por WhatsApp.</p>' +
          '<p style="text-align:center;margin-top:16px"><a href="https://wa.me/51922028889" style="background:#00C9A7;color:#fff;padding:10px 24px;border-radius:8px;text-decoration:none;font-weight:700">ðŸ“± Pedir por WhatsApp</a></p>')
        return sendAgentEmail(p.correo, 'ðŸ’Š Tu ' + items[0].nombre + ' estÃ¡ por terminarse â€” Zi Vital', html, 'reposicion_producto', p.correo + '_repos_' + p.fecha_receta)
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'ReposiciÃ³n â†’ ' + p.nombre + ': ' + prods, { correo: p.correo }); return r })
      }}
    }).filter(Boolean)
    return sendInBatches(emails11, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸ’Š ' + results.ok + ' reposiciones âœ“' })
      sendAdminReport(agent, 'reposicion_producto', results, data.length)
    })
  }

  // â”€â”€â”€ CARTERO: sesiones por vencer (>90 dÃ­as sin usar) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'sesion_por_vencer') {
    var emails12 = data.filter(function(v) { return v.correo && validarEmail(v.correo) }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var html = emailShell('Tienes una sesiÃ³n pendiente',
          '<p>Hola <b>' + p.nombre + '</b>,</p>' +
          '<p>Tienes una sesiÃ³n de <b>' + (p.tratamiento || '') + '</b> (' + (p.sesion || '') + ') pagada hace ' + (p.dias || 90) + ' dÃ­as que aÃºn no has utilizado.</p>' +
          '<p>No queremos que pierdas tu inversiÃ³n. Agenda tu sesiÃ³n lo antes posible.</p>' +
          '<p style="text-align:center;margin-top:16px"><a href="https://wa.me/51922028889" style="background:#0A4FBF;color:#fff;padding:10px 24px;border-radius:8px;text-decoration:none;font-weight:700">ðŸ“… Agendar mi sesiÃ³n</a></p>')
        return sendAgentEmail(p.correo, 'â° Tu sesiÃ³n de ' + (p.tratamiento || 'tratamiento') + ' estÃ¡ por vencer â€” Zi Vital', html, 'sesion_por_vencer', p.correo + '_vencer_' + p.fecha_compra)
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'SesiÃ³n por vencer â†’ ' + p.nombre + ': ' + p.tratamiento, { correo: p.correo, dias: p.dias }); return r })
      }}
    })
    return sendInBatches(emails12, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'â° ' + results.ok + ' sesiones vencer âœ“' })
      sendAdminReport(agent, 'sesion_por_vencer', results, data.length)
    })
  }

  // â”€â”€â”€ CARTERO: predicciÃ³n de recompra â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'prediccion_recompra') {
    var emails13 = data.filter(function(v) { return v.correo && validarEmail(v.correo) }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var vars = { nombre: p.nombre || '', tratamiento: p.tratamiento || 'tratamiento', ciclo: p.ciclo || '45' }
        var html = buildFromTemplate('prediccion_recompra', vars, function() {
          return emailShell('Es hora de tu prÃ³xima sesiÃ³n',
            '<p>Hola <b>' + (p.nombre||'') + '</b>, basÃ¡ndonos en tu historial, es buen momento para tu prÃ³xima sesiÃ³n de <b>' + (p.tratamiento||'') + '</b>.</p>' +
            '<p style="text-align:center;margin-top:16px"><a href="https://wa.me/51960618468" style="background:#cea14a;color:#fff;padding:10px 24px;border-radius:8px;text-decoration:none;font-weight:700">ðŸ“… Agendar</a></p>')
        })
        return sendAgentEmail(p.correo, 'ðŸ’† ' + (p.nombre||'').split(' ')[0] + ', es hora de tu prÃ³xima sesiÃ³n â€” Zi Vital', html, 'prediccion_recompra', p.correo + '_recompra_' + new Date().toISOString().slice(0,7))
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Recompra â†’ ' + p.nombre, { correo: p.correo }); return r })
      }}
    })
    return sendInBatches(emails13, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸ”„ ' + results.ok + ' recompra âœ“' })
      sendAdminReport(agent, 'prediccion_recompra', results, data.length)
      // Marcar predicciones como procesadas
      sbFetch('/rest/v1/rpc/aos_marcar_predicciones_procesadas', { method: 'POST', body: JSON.stringify({ p_tipo: 'recompra' }) }).catch(function(){})
    })
  }

  // â”€â”€â”€ CARTERO: riesgo de abandono â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'riesgo_abandono') {
    var emails14 = data.filter(function(v) { return v.correo && validarEmail(v.correo) }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var vars = { nombre: p.nombre || '' }
        var html = buildFromTemplate('riesgo_abandono', vars, function() {
          return emailShell('Queremos escucharte',
            '<p>Hola <b>' + (p.nombre||'') + '</b>, notamos que no has podido asistir Ãºltimamente. Estamos aquÃ­ para ayudarte a reprogramar.</p>' +
            '<p style="text-align:center;margin-top:16px"><a href="https://wa.me/51960618468" style="background:#cea14a;color:#fff;padding:10px 24px;border-radius:8px;text-decoration:none;font-weight:700">ðŸ’¬ Conversemos</a></p>')
        })
        return sendAgentEmail(p.correo, (p.nombre||'').split(' ')[0] + ', queremos escucharte â€” Zi Vital', html, 'riesgo_abandono', p.correo + '_abandono_' + new Date().toISOString().slice(0,7))
          .then(function(r) {
            if (r && r.ok && !r.skip) {
              logAction(agent.id, 'email_enviado', 'Abandono â†’ ' + p.nombre, { correo: p.correo, cancelaciones: p.cancelaciones })
              // Alerta interna a CÃ©sar
              notifyAdmin('âš ï¸ Riesgo de abandono: ' + p.nombre, p.cancelaciones + ' cancelaciones recientes. Email enviado.', 'PACIENTE', 'ALTA')
            }
            return r
          })
      }}
    })
    return sendInBatches(emails14, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'âš ï¸ ' + results.ok + ' abandono âœ“' })
      sendAdminReport(agent, 'riesgo_abandono', results, data.length)
      sbFetch('/rest/v1/rpc/aos_marcar_predicciones_procesadas', { method: 'POST', body: JSON.stringify({ p_tipo: 'abandono' }) }).catch(function(){})
    })
  }

  // â”€â”€â”€ CARTERO: cross-sell inteligente â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'send_email' && template === 'crosssell') {
    var emails15 = data.filter(function(v) { return v.correo && validarEmail(v.correo) }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var vars = { nombre: p.nombre || '', tratamientos_actuales: p.tratamientos_actuales || '', sugerencia: p.sugerencia || 'nuevo tratamiento' }
        var html = buildFromTemplate('crosssell', vars, function() {
          return emailShell('Descubre un nuevo tratamiento',
            '<p>Hola <b>' + (p.nombre||'') + '</b>, basÃ¡ndonos en tu experiencia, te recomendamos conocer nuestro tratamiento de <b>' + (p.sugerencia||'') + '</b>.</p>' +
            '<p style="text-align:center;margin-top:16px"><a href="https://wa.me/51960618468" style="background:#cea14a;color:#fff;padding:10px 24px;border-radius:8px;text-decoration:none;font-weight:700">ðŸ“‹ MÃ¡s info</a></p>')
        })
        return sendAgentEmail(p.correo, 'âœ¨ ' + (p.nombre||'').split(' ')[0] + ', descubre un tratamiento complementario â€” Zi Vital', html, 'crosssell', p.correo + '_crosssell_' + new Date().toISOString().slice(0,7))
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Cross-sell â†’ ' + p.nombre + ': ' + p.sugerencia, { correo: p.correo }); return r })
      }}
    })
    return sendInBatches(emails15, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: 'âœ¨ ' + results.ok + ' cross-sell âœ“' })
      sendAdminReport(agent, 'crosssell', results, data.length)
      sbFetch('/rest/v1/rpc/aos_marcar_predicciones_procesadas', { method: 'POST', body: JSON.stringify({ p_tipo: 'crosssell' }) }).catch(function(){})
    })
  }

  // â”€â”€â”€ CARTERO: Motor flujos multi-paso â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'procesar_flujos') {
    // Buscar ejecuciones activas cuyo proximo_envio ya pasÃ³
    return sbFetch('/rest/v1/aos_email_flujo_ejecuciones?estado=eq.activo&flujo_id=not.is.null&proximo_envio=lte.' + new Date().toISOString() + '&select=*&limit=20')
      .then(function(ejecuciones) {
        if (!ejecuciones || !ejecuciones.length) {
          console.log('[FLUJOS] Sin ejecuciones pendientes')
          return
        }
        console.log('[FLUJOS] Procesando ' + ejecuciones.length + ' ejecuciones pendientes')
        var chain = Promise.resolve()
        ejecuciones.forEach(function(ej) {
          chain = chain.then(function() {
            return _procesarPasoFlujo(agent, ej)
          }).then(function() {
            return new Promise(function(res) { setTimeout(res, 1000) })
          })
        })
        return chain.then(function() {
          sbPatchAgent(agent.id, { bubble_text: 'ðŸ”„ ' + ejecuciones.length + ' flujos procesados âœ“' })
        })
      }).catch(function(e) {
        console.error('[FLUJOS] Error:', e.message)
      })
  }

  // â”€â”€â”€ CARTERO: reintentar emails fallidos del dÃ­a â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (accion === 'reintentar_fallidos') {
    if (!data.length) { console.log('[CARTERO] Sin errores que reintentar'); return Promise.resolve() }
    console.log('[CARTERO] Reintentando ' + data.length + ' emails fallidos...')
    var retries = data.map(function(err) {
      // Extraer email del destinatario de los datos de la alerta
      var email = (err.destinatario || '').split('_')[0]
      if (!email || email.indexOf('@') < 0) return Promise.resolve()
      return new Promise(function(resolve) {
        // Buscar el template original y los datos del paciente
        var tipo = err.template || 'recordatorio_hoy'
        // Marcar alerta como leÃ­da (procesada)
        sbPost('/rest/v1/aos_email_alertas?id=eq.' + err.id, { leido: true }, 'PATCH').catch(function(){})
        // Reenviar usando el endpoint send-template con datos mÃ­nimos
        var body = JSON.stringify({ to: email, template: tipo, nombre: 'Paciente', tratamiento: '', hora: '', sede: '', fecha: '' })
        var url = new URL(SB_URL.replace('supabase.co', '') + '') // dummy
        // Usar el endpoint local
        var reqData = JSON.stringify({ to: email, template: tipo, nombre: 'Paciente' })
        fetch('https://ascenda-os-production.up.railway.app/api/send-template', {
          method: 'POST', headers: { 'Content-Type': 'application/json' }, body: reqData
        }).then(function(r) { return r.json() }).then(function(d) {
          if (d && (d.ok || d.id)) {
            console.log('[CARTERO] âœ“ Reintento exitoso: ' + email)
            logAction(agent.id, 'email_reintento', 'Reintento exitoso â†’ ' + email, { template: tipo })
          } else {
            console.log('[CARTERO] âœ• Reintento fallido: ' + email)
          }
          resolve()
        }).catch(function() { resolve() })
      })
    })
    // Secuencial con delay
    var chain = Promise.resolve()
    retries.forEach(function(r, i) {
      chain = chain.then(function() { return r }).then(function() {
        if (i < retries.length - 1) return new Promise(function(res) { setTimeout(res, 2000) })
      })
    })
    return chain.then(function() {
      sbPatchAgent(agent.id, { bubble_text: 'ðŸ”„ ' + data.length + ' reintentos procesados' })
    })
  }

  return Promise.resolve()
}
// â•â•â• MOTOR FLUJOS MULTI-PASO â€” procesa un paso de un flujo activo â•â•â•
// â•â•â• DISPARAR FLUJO â€” crea ejecuciÃ³n cuando se cumple un trigger â•â•â•
// Mapeo: template de email â†’ trigger_tipo del flujo
var FLUJO_TRIGGERS = {
  'confirmacion_cita': 'cita_confirmada',
  'recibo_venta': 'post_compra',
  'confirmacion_pago': 'post_compra',
  'bienvenida': 'bienvenida'
}

function _dispararFlujo(triggerTipo, email, pacienteId, variables) {
  if (!email || !validarEmail(email)) return
  // Buscar flujo activo con ese trigger
  sbFetch('/rest/v1/aos_email_flujos?trigger_tipo=eq.' + triggerTipo + '&activo=eq.true&select=id,pasos&limit=1')
    .then(function(flujos) {
      if (!flujos || !flujos.length) return
      var flujo = flujos[0]
      var pasos = flujo.pasos || []
      if (!pasos.length) return
      // Verificar que no exista ya una ejecuciÃ³n activa de este flujo para este paciente
      sbFetch('/rest/v1/aos_email_flujo_ejecuciones?flujo_id=eq.' + flujo.id + '&email=eq.' + encodeURIComponent(email) + '&estado=eq.activo&select=id&limit=1')
        .then(function(existing) {
          if (existing && existing.length > 0) {
            console.log('[FLUJOS] Ya existe ejecuciÃ³n activa de ' + triggerTipo + ' para ' + email)
            return
          }
          // El paso 1 se ejecuta inmediato (delay 0), asÃ­ que avanzamos a paso 2
          // El paso 1 ya se enviÃ³ como el email que disparÃ³ este trigger
          var paso2 = pasos.find(function(p) { return p.paso === 2 })
          if (!paso2) return // Flujo de 1 solo paso, ya se ejecutÃ³
          var delayMs = (paso2.delay_minutos || 0) * 60000
          var proximoEnvio = new Date(Date.now() + delayMs).toISOString()
          sbPost('/rest/v1/aos_email_flujo_ejecuciones', {
            flujo_id: flujo.id,
            email: email,
            paciente_id: pacienteId || email,
            numero_limpio: pacienteId || '',
            paso_actual: 2,
            total_pasos: pasos.length,
            proximo_envio: proximoEnvio,
            estado: 'activo',
            variables: variables || {}
          }).then(function() {
            console.log('[FLUJOS] âœ“ Disparado ' + triggerTipo + ' â†’ paso 2 en ' + (paso2.delay_minutos || 0) + 'min para ' + email)
            // Incrementar total_ejecutados
            sbFetch('/rest/v1/aos_email_flujos?id=eq.' + flujo.id + '&select=total_ejecutados').then(function(f) {
              if (f && f[0]) sbPost('/rest/v1/aos_email_flujos?id=eq.' + flujo.id, { total_ejecutados: (f[0].total_ejecutados || 0) + 1 }, 'PATCH').catch(function(){})
            }).catch(function(){})
          }).catch(function(e) { console.error('[FLUJOS] Error disparando:', e.message) })
        }).catch(function(){})
    }).catch(function(e) { console.error('[FLUJOS] Error buscando flujo:', e.message) })
}

function _procesarPasoFlujo(agent, ej) {
  // Defensa adicional: una ejecuciÃ³n activa sin flujo padre es invÃ¡lida.
  if (!ej || !ej.flujo_id) {
    console.warn('[FLUJOS] EjecuciÃ³n invÃ¡lida sin flujo_id; se omite:', ej && ej.id ? ej.id : 'sin-id')
    return Promise.resolve()
  }
  // Cargar flujo padre para obtener pasos
  return sbFetch('/rest/v1/aos_email_flujos?id=eq.' + ej.flujo_id + '&select=nombre,pasos')
    .then(function(flujos) {
      if (!flujos || !flujos.length) {
        // Flujo eliminado â€” cancelar ejecuciÃ³n
        return sbPost('/rest/v1/aos_email_flujo_ejecuciones?id=eq.' + ej.id, { estado: 'cancelado', updated_at: new Date().toISOString() }, 'PATCH')
      }
      var flujo = flujos[0]
      var pasos = flujo.pasos || []
      var pasoActual = pasos.find(function(p) { return p.paso === ej.paso_actual })
      if (!pasoActual) {
        // Paso no existe â€” completar
        return sbPost('/rest/v1/aos_email_flujo_ejecuciones?id=eq.' + ej.id, { estado: 'completado', updated_at: new Date().toISOString() }, 'PATCH')
      }

      console.log('[FLUJOS] ' + flujo.nombre + ' â€” paso ' + ej.paso_actual + '/' + pasos.length + ' para ' + (ej.email || ej.numero_limpio))

      if (pasoActual.tipo === 'esperar') {
        // Paso de espera: avanzar al siguiente paso con delay
        return _avanzarPasoFlujo(ej, pasos, pasoActual)
      }

      if (pasoActual.tipo === 'condicion') {
        // Por ahora skip condiciones complejas â€” avanzar
        return _avanzarPasoFlujo(ej, pasos, pasoActual)
      }

      if (pasoActual.tipo === 'email') {
        // Buscar plantilla por ID
        var tplId = pasoActual.plantilla_id
        if (!tplId) return _avanzarPasoFlujo(ej, pasos, pasoActual)
        return sbFetch('/rest/v1/aos_email_plantillas?id=eq.' + tplId + '&select=tipo,asunto,html_body&activo=eq.true')
          .then(function(tpls) {
            if (!tpls || !tpls.length) {
              console.log('[FLUJOS] Plantilla ' + tplId + ' no encontrada, skip')
              return _avanzarPasoFlujo(ej, pasos, pasoActual)
            }
            var tpl = tpls[0]
            var emailTo = ej.email || ''
            if (!emailTo || !validarEmail(emailTo)) {
              console.log('[FLUJOS] Email invÃ¡lido: ' + emailTo)
              return _avanzarPasoFlujo(ej, pasos, pasoActual)
            }
            // Reemplazar variables
            var vars = ej.variables || {}
            var body = tpl.html_body || ''
            var asunto = tpl.asunto || ''
            Object.keys(vars).forEach(function(k) {
              body = body.replace(new RegExp('\\{\\{' + k + '\\}\\}', 'g'), vars[k] || '')
              asunto = asunto.replace(new RegExp('\\{\\{' + k + '\\}\\}', 'g'), vars[k] || '')
            })
            var html = emailShell(
              '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">' + asunto + '</div>',
              body
            )
            var tipoFlujo = 'flujo_' + (tpl.tipo || 'email') + '_p' + ej.paso_actual
            return sendAgentEmail(emailTo, asunto, html, tipoFlujo, (ej.paciente_id || ej.numero_limpio || emailTo) + '_flujo_' + ej.flujo_id)
              .then(function(r) {
                if (r && r.ok) {
                  logAction(agent.id, 'flujo_email', flujo.nombre + ' paso ' + ej.paso_actual + ' â†’ ' + emailTo, { flujo: flujo.nombre, paso: ej.paso_actual })
                }
                return _avanzarPasoFlujo(ej, pasos, pasoActual)
              })
          })
      }

      // Tipo desconocido â€” avanzar
      return _avanzarPasoFlujo(ej, pasos, pasoActual)
    })
}

function _avanzarPasoFlujo(ej, pasos, pasoActual) {
  var siguientePasoNum = ej.paso_actual + 1
  var siguientePaso = pasos.find(function(p) { return p.paso === siguientePasoNum })
  if (!siguientePaso) {
    // Flujo completado
    return sbPost('/rest/v1/aos_email_flujo_ejecuciones?id=eq.' + ej.id, {
      estado: 'completado', paso_actual: ej.paso_actual,
      ultimo_envio: new Date().toISOString(), updated_at: new Date().toISOString()
    }, 'PATCH').then(function() {
      // Incrementar contador del flujo
      sbFetch('/rest/v1/aos_email_flujos?id=eq.' + ej.flujo_id + '&select=total_completados').then(function(f) {
        if (f && f[0]) sbPost('/rest/v1/aos_email_flujos?id=eq.' + ej.flujo_id, { total_completados: (f[0].total_completados || 0) + 1 }, 'PATCH').catch(function(){})
      }).catch(function(){})
    })
  }
  // Calcular prÃ³ximo envÃ­o basado en delay del siguiente paso
  var delayMs = (siguientePaso.delay_minutos || 0) * 60000
  var proximoEnvio = new Date(Date.now() + delayMs).toISOString()
  return sbPost('/rest/v1/aos_email_flujo_ejecuciones?id=eq.' + ej.id, {
    paso_actual: siguientePasoNum, proximo_envio: proximoEnvio,
    ultimo_envio: new Date().toISOString(), updated_at: new Date().toISOString()
  }, 'PATCH')
}

function executeRpcAction(agent, rpcName, result) {
  if (!result) return Promise.resolve()

  // â”€â”€â”€ BRUNO (guardian): alertas reales al CRM â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (agent.id === 'guardian' && rpcName === 'aos_inventario_alertas') {
    var agotados = (result.agotados || []).slice(0, 5)
    if (!agotados.length) return Promise.resolve()
    var lista = agotados.map(function(p){ return 'â€¢ ' + p.nombre_producto + ' (' + p.sede + ')' }).join('\n')
    return notifyAdmin(
      'âš  Bruno: ' + agotados.length + ' productos agotados',
      'Productos sin stock:\n' + lista + (result.agotados.length > 5 ? '\n...y ' + (result.agotados.length-5) + ' mÃ¡s.' : ''),
      'ALERTA', 'ALTA'
    ).then(function() {
      logAction(agent.id, 'notificacion_crm', agotados.length + ' alertas de inventario enviadas al CRM', { total: result.agotados.length })
      sbPatchAgent(agent.id, { bubble_text: 'âš  ' + result.agotados.length + ' productos agotados â€” CRM notificado' })
    })
  }

  // â”€â”€â”€ BRUNO: alertas de venta â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (agent.id === 'guardian' && rpcName === 'aos_alertas_venta') {
    var alertas = result.alertas || result || []
    if (!Array.isArray(alertas) || !alertas.length) return Promise.resolve()
    return notifyAdmin(
      'ðŸ’° Bruno: ' + alertas.length + ' alertas de ventas',
      alertas.slice(0,3).map(function(a){ return 'â€¢ ' + (a.descripcion || JSON.stringify(a).substring(0,60)) }).join('\n'),
      'ALERTA', 'MEDIA'
    )
  }

  // â”€â”€â”€ LEÃ“N (monitor): detectar anomalÃ­as en KPIs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  if (agent.id === 'monitor' && rpcName === 'aos_kpis_dashboard') {
    var kpis = result
    var anomalias = []
    if (kpis.llamHoy !== undefined && kpis.llamHoy < 50) {
      var hora = new Date(Date.now() + (-5*60)*60000).getHours()
      if (hora >= 10 && hora <= 18) anomalias.push('Llamadas bajas hoy: ' + kpis.llamHoy + ' (hora: ' + hora + ':00)')
    }
    if (kpis.citasHoy !== undefined && kpis.citasHoy === 0) {
      anomalias.push('Sin citas registradas para hoy')
    }
    if (!anomalias.length) return Promise.resolve()
    // Solo notificar 1 vez por dÃ­a â€” anti-spam
    return sbFetch('/rest/v1/aos_agente_acciones?agente_id=eq.monitor&tipo_accion=eq.alerta_kpi&created_at=gte.' + limaDateStr() + 'T00:00:00-05:00&limit=1')
      .then(function(rows) {
        if (rows && rows.length > 0) return // ya alertÃ³ hoy
        return notifyAdmin('ðŸ“Š LeÃ³n: anomalÃ­a detectada', anomalias.join('\n'), 'ALERTA', 'MEDIA')
          .then(function() { logAction(agent.id, 'alerta_kpi', anomalias.join(' | '), { kpis: kpis }) })
      })
  }

  // â”€â”€â”€ DANTE (centinela): detectar leads sin contactar â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // El sql_query ya devuelve los datos â€” esto se maneja en executeAction
  // Pero si viene de estado_bases, notificar si hay muchas vÃ­rgenes
  if (agent.id === 'centinela' && rpcName === 'aos_estado_bases') {
    var bases = result
    var virgenes = 0
    if (Array.isArray(bases)) {
      bases.forEach(function(b) { virgenes += (b.virgenes || b.sin_contactar || 0) })
    } else if (bases && bases.virgenes !== undefined) {
      virgenes = bases.virgenes
    }
    if (virgenes > 20) {
      return notifyAdmin(
        'ðŸ“‹ Dante: ' + virgenes + ' leads sin contactar',
        'Hay ' + virgenes + ' leads que nunca han sido contactados. Revisar distribuciÃ³n.',
        'ALERTA', 'MEDIA'
      ).then(function() {
        sbPatchAgent(agent.id, { bubble_text: 'ðŸ“‹ ' + virgenes + ' leads vÃ­rgenes â€” equipo notificado' })
      })
    }
  }

  return Promise.resolve()
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// RESOLVER DE PLACEHOLDERS â€” inyecta datos reales en prompts AI
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

// Utilidades de fecha Lima
function limaDateStr() {
  var d = new Date(Date.now() + (-5 * 60) * 60000)
  return d.toISOString().split('T')[0]
}
function limaFirstOfMonth() {
  return limaDateStr().slice(0, 8) + '01'
}

// Resumen de ventas de la semana para SofÃ­a (analista)
function fetchVentasData() {
  var lunes = new Date(Date.now() + (-5 * 60) * 60000)
  lunes.setDate(lunes.getDate() - lunes.getDay() + 1)
  var lunesStr = lunes.toISOString().split('T')[0]
  return sbFetch('/rest/v1/aos_ventas?fecha=gte.' + lunesStr + '&select=tratamiento,monto,numero_limpio,fecha,asesor&order=fecha.desc&limit=200')
    .then(function(rows) {
      if (!rows || !rows.length) return 'Sin ventas registradas esta semana.'
      var totalMonto = rows.reduce(function(s, r) { return s + parseFloat(r.monto || 0) }, 0)
      var byTrat = {}
      rows.forEach(function(r) {
        byTrat[r.tratamiento] = (byTrat[r.tratamiento] || 0) + 1
      })
      var top = Object.entries(byTrat).sort(function(a,b){return b[1]-a[1]}).slice(0,5)
        .map(function(e){ return e[0] + '(' + e[1] + ')' }).join(', ')
      var unicos = new Set(rows.map(function(r){return r.numero_limpio})).size
      return 'Semana del ' + lunesStr + '. Ventas: ' + rows.length + '. Facturado: S/' + totalMonto.toFixed(0) + '. Ticket promedio: S/' + (totalMonto/rows.length).toFixed(0) + '. Pacientes Ãºnicos: ' + unicos + '. Top tratamientos: ' + top + '.'
    }).catch(function(){ return 'Error al cargar ventas.' })
}

// Leads recientes sin contactar para Nico (clasificador)
function fetchLeadsData() {
  return sbFetch('/rest/v1/aos_leads?fecha=gte.' + new Date(Date.now() - 3*86400000).toISOString().split('T')[0] + '&select=celular,tratamiento,anuncio,fecha,hora_ingreso,numero_limpio&order=fecha.desc&limit=20')
    .then(function(leads) {
      if (!leads || !leads.length) return 'Sin leads nuevos en los Ãºltimos 3 dÃ­as.'
      // Enriquecer con estado de contacto
      var nums = leads.map(function(l){ return l.numero_limpio }).filter(Boolean).join(',')
      return sbFetch('/rest/v1/aos_llamadas?numero_limpio=in.(' + nums + ')&select=numero_limpio,estado&order=fecha.desc')
        .then(function(llams) {
          var llamSet = {}
          ;(llams||[]).forEach(function(l){ llamSet[l.numero_limpio] = l.estado })
          return leads.map(function(l) {
            return 'Tratamiento:' + l.tratamiento + '|Anuncio:' + (l.anuncio||'orgÃ¡nico') + '|Fecha:' + l.fecha + '|Estado:' + (llamSet[l.numero_limpio] || 'SIN CONTACTAR')
          }).join('\n')
        })
    }).catch(function(){ return 'Error al cargar leads.' })
}

// Mensajes pendientes de agentes predecesores (cadenas)
function fetchPendingMessages(agentId) {
  return sbFetch('/rest/v1/aos_agente_mensajes?para_agente_id=eq.' + agentId + '&leido=eq.false&order=created_at.desc&limit=3')
    .then(function(msgs) {
      if (!msgs || !msgs.length) return null
      // Marcar como leÃ­dos
      msgs.forEach(function(m) {
        sbPatch('/rest/v1/aos_agente_mensajes?id=eq.' + m.id, { leido: true }).catch(function(){})
      })
      return msgs.map(function(m){ return m.de_agente_id + ': ' + m.mensaje.substring(0, 1000) }).join('\n\n---\n\n')
    }).catch(function(){ return null })
}

// FunciÃ³n principal: resuelve todos los placeholders del template
function resolvePlaceholders(agent, task, template) {
  var promises = []
  var keys = []

  // Detectar quÃ© placeholders hay en el template
  if (template.indexOf('{ventas_data}') >= 0) {
    keys.push('ventas_data')
    promises.push(fetchVentasData())
  }
  if (template.indexOf('{leads_data}') >= 0) {
    keys.push('leads_data')
    promises.push(fetchLeadsData())
  }
  if (template.indexOf('{insights}') >= 0) {
    // Camila (creador) recibe de SofÃ­a (analista) vÃ­a mensajes
    keys.push('insights')
    promises.push(fetchPendingMessages(agent.id).then(function(msg) {
      if (msg) return msg
      // Fallback: Ãºltimos KPIs reales si no hay mensaje de SofÃ­a
      return sbFetch('/rest/v1/aos_agente_logs?agente_id=eq.analista&exitoso=eq.true&order=created_at.desc&limit=1&select=output_resumen')
        .then(function(rows) {
          if (!rows || !rows[0]) return 'Sin insights disponibles aÃºn.'
          return rows[0].output_resumen ? rows[0].output_resumen.substring(0, 800) : 'Sin insights disponibles.'
        }).catch(function(){ return 'Sin insights disponibles.' })
    }))
  }
  if (template.indexOf('{tarea}') >= 0) {
    // KronIA â€” revisar si hay mensajes pendientes de agentes o usar cola de leads como contexto
    keys.push('tarea')
    promises.push(
      sbFetch('/rest/v1/aos_agente_mensajes?para_agente_id=eq.kronia&leido=eq.false&order=created_at.desc&limit=1')
        .then(function(msgs) {
          if (msgs && msgs[0]) {
            sbPatch('/rest/v1/aos_agente_mensajes?id=eq.' + msgs[0].id, { leido: true }).catch(function(){})
            return 'Mensaje de ' + msgs[0].de_agente_id + ': ' + msgs[0].mensaje.substring(0, 400)
          }
          // Sin mensajes â€” KronIA hace revisiÃ³n del estado global
          return 'RevisiÃ³n diaria del estado del equipo: verificar agentes bloqueados, leads sin contactar, y prÃ³ximas citas del dÃ­a.'
        }).catch(function(){ return 'RevisiÃ³n general del equipo.' })
    )
  }
  if (template.indexOf('{chat_history}') >= 0) {
    keys.push('chat_history')
    promises.push(Promise.resolve('Sin conversaciones de WhatsApp disponibles â€” API pendiente de configuraciÃ³n.'))
  }
  if (template.indexOf('{kpis_data}') >= 0) {
    // Luna (resumidor) â€” KPIs reales del dÃ­a
    keys.push('kpis_data')
    promises.push(
      sbFetch('/rest/v1/rpc/aos_kpis_dashboard', {
        method: 'POST', body: JSON.stringify({
          p_hoy: limaDateStr(),
          p_ayer: new Date(Date.now() + (-5*60)*60000 - 86400000).toISOString().split('T')[0],
          p_mes_inicio: limaFirstOfMonth()
        })
      }).then(function(r) {
        if (!r) return 'Sin datos de KPIs disponibles.'
        return 'Citas hoy: ' + (r.citasHoy||0) + '. Llamadas hoy: ' + (r.llamHoy||0) + '. Ventas hoy: ' + (r.nVentasHoy||0) + '. Facturado hoy: S/' + (r.factHoy||0) + '. Leads este mes: ' + (r.leadsMes||0) + '.'
      }).catch(function(){ return 'Error al cargar KPIs.' })
    )
  }

  if (promises.length === 0) return Promise.resolve(template)

  return Promise.all(promises).then(function(values) {
    var resolved = template
    keys.forEach(function(key, i) {
      resolved = resolved.replace(new RegExp('\{' + key + '\}', 'g'), values[i] || '[sin datos]')
    })
    console.log('[RESOLVE] ' + agent.nombre + ' â€” placeholders: ' + keys.join(', ') + ' | chars: ' + resolved.length)
    return resolved
  })
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// AGENTS THINK-LOOP ENGINE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

var GROQ_KEY = ''
var GEMINI_KEY = ''

// Load AI keys from Supabase on startup
function loadAIKeys() {
  sbFetch('/rest/v1/aos_integraciones?select=tipo,api_key&tipo=in.(groq,gemini)').then(function(rows) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].tipo === 'groq') GROQ_KEY = rows[i].api_key || ''
      if (rows[i].tipo === 'gemini') GEMINI_KEY = rows[i].api_key || ''
    }
    console.log('[AGENTS] Keys loaded â€” Groq:', GROQ_KEY ? 'YES' : 'NO', '| Gemini:', GEMINI_KEY ? 'YES' : 'NO')
  }).catch(function(e) { console.error('[AGENTS] Key load error:', e.message) })
}

function sbFetch(endpoint) {
  try { f16RequireEmailBackend(endpoint) } catch (e) { return Promise.reject(e) }
  return new Promise(function(resolve, reject) {
    var url = new URL(SB_URL + endpoint)
    var dbKey = f16DbKey(endpoint)
    https.get({
      hostname: url.hostname, path: url.pathname + url.search,
      headers: f16SupabaseHeaders(dbKey)
    }, function(res) {
      var d = ''; res.on('data', function(c) { d += c }); res.on('end', function() {
        try { resolve(JSON.parse(d)) } catch(e) { reject(e) }
      })
    }).on('error', reject)
  })
}

function sbPatchAgent(agentId, data) {
  return new Promise(function(resolve, reject) {
    var url = new URL(SB_URL + '/rest/v1/aos_agentes?id=eq.' + agentId)
    var body = JSON.stringify(data)
    var req = https.request({
      hostname: url.hostname, path: url.pathname + url.search, method: 'PATCH',
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(body) }
    }, function(res) { var d = ''; res.on('data', function(c) { d += c }); res.on('end', function() { resolve(res.statusCode) }) })
    req.on('error', reject); req.write(body); req.end()
  })
}

function sbRpc(rpcName, params) {
  return new Promise(function(resolve, reject) {
    var url = new URL(SB_URL + '/rest/v1/rpc/' + rpcName)
    var body = JSON.stringify(params || {})
    var req = https.request({
      hostname: url.hostname, path: url.pathname, method: 'POST',
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
    }, function(res) {
      var d = ''; res.on('data', function(c) { d += c }); res.on('end', function() {
        try { resolve(JSON.parse(d)) } catch(e) { resolve(d) }
      })
    })
    req.on('error', reject); req.write(body); req.end()
  })
}

function logAgent(agentId, tareaId, accion, input, output, motor, modelo, tokIn, tokOut, costo, durMs, ok, err) {
  var body = JSON.stringify({
    agente_id: agentId, tarea_id: tareaId || null, accion: accion,
    input_resumen: (input || '').substring(0, 500),
    output_resumen: (output || '').substring(0, 2000),
    resultado: typeof output === 'object' ? output : {},
    motor_usado: motor || 'script', modelo_usado: modelo || '',
    tokens_input: tokIn || 0, tokens_output: tokOut || 0,
    costo_usd: costo || 0, duracion_ms: durMs || 0,
    exitoso: ok !== false, error: err || ''
  })
  var url = new URL(SB_URL + '/rest/v1/aos_agente_logs')
  var req = https.request({
    hostname: url.hostname, path: url.pathname, method: 'POST',
    headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(body) }
  }, function() {})
  req.on('error', function() {})
  req.write(body); req.end()
}

// Call Groq API
function callGroq(systemPrompt, userPrompt, model) {
  return new Promise(function(resolve, reject) {
    if (!GROQ_KEY) { reject(new Error('No Groq key')); return }
    var body = JSON.stringify({
      model: model || 'llama-3.3-70b-versatile',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.7, max_tokens: 1024
    })
    var req = https.request({
      hostname: 'api.groq.com', path: '/openai/v1/chat/completions', method: 'POST',
      headers: { 'Authorization': 'Bearer ' + GROQ_KEY, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
    }, function(res) {
      var d = ''; res.on('data', function(c) { d += c }); res.on('end', function() {
        try {
          var r = JSON.parse(d)
          if (r.choices && r.choices[0]) {
            resolve({
              text: r.choices[0].message.content,
              tokens_in: r.usage ? r.usage.prompt_tokens : 0,
              tokens_out: r.usage ? r.usage.completion_tokens : 0
            })
          } else { reject(new Error(d.substring(0, 200))) }
        } catch(e) { reject(e) }
      })
    })
    req.on('error', reject); req.write(body); req.end()
  })
}

// â•â•â• CONTEXTO REAL PARA CHAT â€” SNAPSHOT CENTRALIZADO â•â•â•
// Todos los agentes leen del mismo snapshot (se genera cada 5min)
var _cachedSnapshot = null
var _snapshotAge = 0

function getSnapshot() {
  // Cache local de 60s para no hammear Supabase
  if (_cachedSnapshot && (Date.now() - _snapshotAge) < 60000) return Promise.resolve(_cachedSnapshot)
  return sbRpc('aos_generar_snapshot', {})
    .then(function(snap) {
      _cachedSnapshot = snap
      _snapshotAge = Date.now()
      return snap
    }).catch(function() { return _cachedSnapshot || {} })
}

function buildChatContext(agentId) {
  return getSnapshot().then(function(s) {
    if (!s || !s.kpis) return ''
    var k = s.kpis || {}
    var t = s.totales || {}
    var parts = []

    // Contexto base para TODOS los agentes
    parts.push('DATOS REALES DEL SISTEMA (actualizados cada 5 min):')
    parts.push('KPIs HOY: ' + (k.llamadas_hoy||0) + ' llamadas, ' + (k.citas_hoy||0) + ' citas, S/' + (k.ventas_hoy||0) + ' facturado, ' + (k.leads_hoy||0) + ' leads nuevos.')
    parts.push('MES ACTUAL: S/' + (k.ventas_mes||0) + ' facturado, ' + (k.n_ventas_mes||0) + ' ventas, ' + (k.leads_mes||0) + ' leads, ' + (k.llamadas_mes||0) + ' llamadas.')
    parts.push('BASE TOTAL: ' + (t.pacientes||0) + ' pacientes (' + (t.pacientes_email||0) + ' con email), ' + (t.leads||0) + ' leads, ' + (t.ventas||0) + ' ventas.')

    // Contexto especÃ­fico por agente
    if (agentId === 'cartero') {
      var citasM = s.citas_manana_detalle || []
      var conEmail = citasM.filter(function(c) { return c.correo })
      var sinEmail = citasM.filter(function(c) { return !c.correo })
      parts.push('CITAS MAÃ‘ANA: ' + citasM.length + ' total, ' + conEmail.length + ' con email, ' + sinEmail.length + ' sin email.')
      parts.push('DETALLE CITAS MAÃ‘ANA:')
      citasM.forEach(function(c) {
        parts.push('  â€¢ ' + c.nombre + ' â€” ' + c.tratamiento + ' ' + c.hora + ' ' + c.sede + (c.correo ? ' âœ“' + c.correo : ' âœ—SIN EMAIL'))
      })
      var emailsHoy = s.emails_hoy || []
      parts.push('EMAILS ENVIADOS HOY: ' + emailsHoy.length + '.')
      emailsHoy.forEach(function(e) { parts.push('  â€¢ ' + e.desc) })
    }

    if (agentId === 'centinela') {
      var lsc = s.leads_sin_contactar || []
      parts.push('LEADS SIN CONTACTAR (3 dÃ­as): ' + lsc.length + '.')
      lsc.slice(0,10).forEach(function(l) {
        parts.push('  â€¢ ' + l.celular + ' â€” ' + l.tratamiento + ' (' + l.fecha + ')')
      })
      var seg = s.seguimientos_pendientes || []
      parts.push('SEGUIMIENTOS PENDIENTES: ' + seg.length + '.')
      seg.slice(0,5).forEach(function(s2) {
        parts.push('  â€¢ ' + s2.numero + ' â€” ' + s2.tratamiento + ' prog: ' + s2.fecha + ' asesor: ' + s2.asesor)
      })
    }

    if (agentId === 'guardian') {
      var inv = s.inventario_agotados || []
      parts.push('INVENTARIO AGOTADO: ' + inv.length + ' productos.')
      inv.slice(0,10).forEach(function(p) {
        parts.push('  â€¢ ' + p.producto + ' (' + p.sede + ', ' + p.categoria + ')')
      })
    }

    if (agentId === 'monitor' || agentId === 'analista' || agentId === 'analista_mkt') {
      var eq = s.equipo_hoy || []
      parts.push('EQUIPO HOY:')
      eq.forEach(function(e) {
        parts.push('  â€¢ ' + e.asesor + ': ' + e.llamadas + ' llamadas, ' + e.citas + ' citas')
      })
      var top = s.top_tratamientos || []
      parts.push('TOP TRATAMIENTOS MES:')
      top.forEach(function(t2) {
        parts.push('  â€¢ ' + t2.t + ': ' + t2.n + ' ventas, S/' + t2.m)
      })
    }

    if (agentId === 'kronia') {
      // KronIA ve todo
      var lsc2 = s.leads_sin_contactar || []
      var seg2 = s.seguimientos_pendientes || []
      var inv2 = s.inventario_agotados || []
      parts.push('ESTADO GLOBAL: ' + lsc2.length + ' leads sin contactar, ' + seg2.length + ' seguimientos vencidos, ' + inv2.length + ' productos agotados.')
    }

    parts.push('')
    parts.push('IMPORTANTE: Estos son datos reales de Supabase. Responde usando SOLO estos datos. Si te preguntan algo que no estÃ¡ arriba, di que necesitas que se actualice el snapshot o que ese dato especÃ­fico no estÃ¡ en tu contexto actual.')

    return parts.join('\n')
  })
}

// PERFORMANCE GUARD â€” trabajos background compartidos
var _bgFailures = 0
var _bgOpenUntil = 0
function bgCanRun() { return Date.now() >= _bgOpenUntil }
function bgOk() { _bgFailures = 0; _bgOpenUntil = 0 }
function bgFail() {
  _bgFailures++
  var wait = _bgFailures >= 3 ? 600000 : (_bgFailures === 2 ? 120000 : 30000)
  _bgOpenUntil = Math.max(_bgOpenUntil, Date.now() + wait)
  console.warn('[PERF-GUARD] background backoff', wait, 'ms; failures=', _bgFailures)
}

// Snapshot global: 30 min en background. getSnapshot() mantiene cache/on-demand.
var _snapshotJobRunning = false
function backgroundSnapshotRun() {
  if (_snapshotJobRunning || !bgCanRun()) return
  _snapshotJobRunning = true
  sbRpc('aos_generar_snapshot', {})
    .then(function(snap) { _cachedSnapshot = snap; _snapshotAge = Date.now(); bgOk(); console.log('[SNAPSHOT] Regenerado OK') })
    .catch(function(e) { bgFail(); console.error('[SNAPSHOT] Error:', e.message) })
    .finally(function() { _snapshotJobRunning = false })
}
setInterval(backgroundSnapshotRun, 1800000) // 30 min

// Call Groq with full message history (multi-turn DM chat from panel)
function callGroqChat(systemPrompt, messages, model) {
  return new Promise(function(resolve, reject) {
    if (!GROQ_KEY) { reject(new Error('No Groq key')); return }
    var msgs = [{ role: 'system', content: systemPrompt }].concat(messages)
    var body = JSON.stringify({ model: model || 'llama-3.3-70b-versatile', messages: msgs, temperature: 0.72, max_tokens: 512 })
    var req = https.request({
      hostname: 'api.groq.com', path: '/openai/v1/chat/completions', method: 'POST',
      headers: { 'Authorization': 'Bearer ' + GROQ_KEY, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
    }, function(res) {
      var d = ''; res.on('data', function(c) { d += c }); res.on('end', function() {
        try {
          var r = JSON.parse(d)
          if (r.choices && r.choices[0]) { resolve(r.choices[0].message.content) }
          else { reject(new Error(d.substring(0, 200))) }
        } catch(e) { reject(e) }
      })
    })
    req.on('error', reject); req.write(body); req.end()
  })
}

// Call Gemini API
function callGemini(systemPrompt, userPrompt, model) {
  return new Promise(function(resolve, reject) {
    if (!GEMINI_KEY) { reject(new Error('No Gemini key')); return }
    var body = JSON.stringify({
      system_instruction: { parts: [{ text: systemPrompt }] },
      contents: [{ parts: [{ text: userPrompt }] }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 1024 }
    })
    var mdl = model || 'gemini-2.0-flash'
    var req = https.request({
      hostname: 'generativelanguage.googleapis.com',
      path: '/v1beta/models/' + mdl + ':generateContent?key=' + GEMINI_KEY,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
    }, function(res) {
      var d = ''; res.on('data', function(c) { d += c }); res.on('end', function() {
        try {
          var r = JSON.parse(d)
          if (r.candidates && r.candidates[0] && r.candidates[0].content) {
            var text = r.candidates[0].content.parts.map(function(p) { return p.text || '' }).join('')
            resolve({
              text: text,
              tokens_in: r.usageMetadata ? r.usageMetadata.promptTokenCount : 0,
              tokens_out: r.usageMetadata ? r.usageMetadata.candidatesTokenCount : 0
            })
          } else { reject(new Error(d.substring(0, 200))) }
        } catch(e) { reject(e) }
      })
    })
    req.on('error', reject); req.write(body); req.end()
  })
}

// Execute a single task
function executeTask(agent, task) {
  var start = Date.now()
  var tipo = task.tipo
  var config = task.input_config || {}

  // Filtro por hora: si la tarea tiene hora_ejecucion, solo correr en esa hora Lima
  if (config.hora_ejecucion) {
    var _lh = new Date(Date.now() + (-5 * 60) * 60000)
    var limaHH = ('0' + _lh.getHours()).slice(-2) + ':00'
    if (limaHH !== config.hora_ejecucion) {
      return Promise.resolve() // No es la hora, skip silencioso
    }
    // Filtro por dÃ­a de semana (0=dom, 1=lun, 2=mar...)
    if (config.dia_semana !== undefined && config.dia_semana !== null) {
      if (_lh.getDay() !== parseInt(config.dia_semana)) {
        return Promise.resolve() // No es el dÃ­a, skip
      }
    }
  }

  // Update agent status to working
  sbPatchAgent(agent.id, { estado: 'working', bubble_text: task.nombre, bubble_type: 'thought', ultima_actividad: new Date().toISOString() })

  if (tipo === 'rpc_call') {
    var rpcName = config.rpc
    var params = config.params || {}
    // Replace dynamic params â€” FIX: usar timezone Lima (UTC-5) para evitar desfase nocturno
    var _limaOff = -5 * 60
    var _limaDate = new Date(Date.now() + _limaOff * 60000)
    var _limaYest = new Date(Date.now() + _limaOff * 60000 - 86400000)
    var _limaStr  = _limaDate.toISOString().split('T')[0]
    var _limaYStr = _limaYest.toISOString().split('T')[0]
    var _limaFMon = _limaStr.slice(0, 8) + '01'
    var _limaMon  = parseInt(_limaStr.split('-')[1], 10)
    var paramStr = JSON.stringify(params)
    paramStr = paramStr.replace(/\"CURRENT_DATE\"/g, '\"' + _limaStr + '\"')
    paramStr = paramStr.replace(/\"CURRENT_DATE-1\"/g, '\"' + _limaYStr + '\"')
    paramStr = paramStr.replace(/\"FIRST_OF_MONTH\"/g, '\"' + _limaFMon + '\"')
    paramStr = paramStr.replace(/\"CURRENT_MONTH\"/g, '' + _limaMon)
    try { params = JSON.parse(paramStr) } catch(e) {}

    return sbRpc(rpcName, params).then(function(result) {
      var dur = Date.now() - start
      logAgent(agent.id, task.id, 'execute', rpcName, JSON.stringify(result).substring(0, 2000), 'script', '', 0, 0, 0, dur, true, '')
      executeRpcAction(agent, rpcName, result).catch(function(e) { console.error('[RPC-ACTION]', e.message) })
      sbPatchAgent(agent.id, { estado: 'idle', bubble_text: task.nombre + ' âœ“', total_ejecuciones: (agent.total_ejecuciones || 0) + 1, ultima_actividad: new Date().toISOString() })
      return { ok: true, result: result, dur: dur }
    }).catch(function(e) {
      var dur = Date.now() - start
      logAgent(agent.id, task.id, 'error', rpcName, '', 'script', '', 0, 0, 0, dur, false, e.message)
      sbPatchAgent(agent.id, { estado: 'blocked', bubble_text: 'Error: ' + e.message.substring(0, 50), bubble_type: 'speech' })
      return { ok: false, error: e.message }
    })
  }

  if (tipo === 'sql_query') {
    var query = config.query || ''
    return sbRpc('aos_execute_agent_query', { p_query: query }).then(function(result) {
      var dur = Date.now() - start
      logAgent(agent.id, task.id, 'execute', query.substring(0, 100), JSON.stringify(result).substring(0, 2000), 'script', '', 0, 0, 0, dur, true, '')
      // Ejecutar acciÃ³n real si la tarea la tiene definida
      executeAction(agent, task, result).catch(function(e) { console.error('[ACTION] Error:', e.message) })
      sbPatchAgent(agent.id, { estado: 'idle', bubble_text: task.nombre + ' âœ“', total_ejecuciones: (agent.total_ejecuciones || 0) + 1, ultima_actividad: new Date().toISOString() })
      return { ok: true, result: result, dur: dur }
    }).catch(function(e) {
      var dur = Date.now() - start
      logAgent(agent.id, task.id, 'error', query.substring(0, 100), '', 'script', '', 0, 0, 0, dur, false, e.message)
      sbPatchAgent(agent.id, { estado: 'blocked', bubble_text: 'SQL: ' + (e.message || 'error').substring(0, 60), bubble_type: 'speech', ultimo_error: e.message || '' })
      return { ok: false, error: e.message }
    })
  }

  if (tipo === 'ai_prompt') {
    var promptTemplate = config.prompt_template || ''
    var motor = agent.motor_ai || 'groq'
    var modelo = agent.modelo || ''
    var sysPrompt = agent.system_prompt || ''
    var callFn = motor === 'gemini' ? callGemini : callGroq
    var fallbackFn = callGroq // Groq como fallback siempre

    // ===== RESOLVER PLACEHOLDERS con datos reales =====
    return resolvePlaceholders(agent, task, promptTemplate).then(function(resolvedPrompt) {
    // Intentar con motor principal, fallback a Groq si falla
    return callFn(sysPrompt, resolvedPrompt, modelo).catch(function(primaryErr) {
      if (motor !== 'gemini') throw primaryErr // solo hace fallback desde Gemini
      console.log('[FALLBACK] ' + agent.nombre + ' Gemini fallÃ³ (' + primaryErr.message.substring(0,50) + ') â†’ reintentando con Groq')
      sbPatchAgent(agent.id, { bubble_text: 'âš¡ Gemini no disponible â†’ usando Groq' })
      return fallbackFn(sysPrompt, resolvedPrompt, 'llama-3.3-70b-versatile')
    }).then(function(aiResult) {
      var dur = Date.now() - start
      logAgent(agent.id, task.id, 'think', promptTemplate.substring(0, 200), aiResult.text.substring(0, 2000), motor, modelo, aiResult.tokens_in, aiResult.tokens_out, 0, dur, true, '')
      // Track costos reales
      trackCost(agent.id, motor, modelo, aiResult.tokens_in, aiResult.tokens_out, task.nombre)
      // Guardar contenido generado segÃºn agente
      var contentType = agent.id === 'analista' ? 'insight' : agent.id === 'creador' ? 'copy_ig' : agent.id === 'clasificador' ? 'clasificacion' : agent.id === 'resumidor' ? 'reporte' : agent.id === 'planificador' ? 'calendario' : agent.id === 'kronia' ? 'dispatch' : 'analisis'
      saveContent(agent.id, contentType, task.nombre, aiResult.text, { tokens: aiResult.tokens_in + aiResult.tokens_out, motor: motor, modelo: modelo })
      sbPatchAgent(agent.id, {
        estado: 'idle', bubble_text: '', 
        total_ejecuciones: (agent.total_ejecuciones || 0) + 1,
        total_tokens_usados: (agent.total_tokens_usados || 0) + (aiResult.tokens_in || 0) + (aiResult.tokens_out || 0),
        ultima_actividad: new Date().toISOString()
      })

      // Chain: if task has siguiente_agente_id, pass output
      if (task.siguiente_agente_id) {
        console.log('[CHAIN] ' + agent.nombre + ' â†’ ' + task.siguiente_agente_id + ' | ' + aiResult.text.substring(0, 80))
        // Create a message between agents
        sbPost('/rest/v1/aos_agente_mensajes', {
          de_agente_id: agent.id, para_agente_id: task.siguiente_agente_id,
          mensaje: aiResult.text.substring(0, 4000), tipo: 'handoff',
          metadata: { from_task: task.nombre, from_agent: agent.nombre }
        }).catch(function() {})
      }
      return { ok: true, text: aiResult.text, tokens: aiResult.tokens_in + aiResult.tokens_out, dur: dur }
    }) // fin .then(aiResult)
    .catch(function(e) {
      var dur = Date.now() - start
      logAgent(agent.id, task.id, 'error', promptTemplate.substring(0, 200), '', motor, modelo, 0, 0, 0, dur, false, e.message)
      sbPatchAgent(agent.id, { estado: 'blocked', bubble_text: 'Error AI: ' + e.message.substring(0, 40), bubble_type: 'speech' })
      return { ok: false, error: e.message }
    })
    }) // fin resolvePlaceholders
  }

  // Unknown type
  sbPatchAgent(agent.id, { estado: 'idle', bubble_text: '' })
  return Promise.resolve({ ok: false, error: 'Unknown task type: ' + tipo })
}

// Auto-tick: check which cron agents need to run
function autoTick() {
  sbFetch('/rest/v1/aos_agentes?select=id,nombre,emoji,cron_intervalo,ultima_actividad,system_prompt,motor_ai,modelo&activo=eq.true&tipo_ejecucion=eq.cron').then(function(agents) {
    if (!agents || !agents.length) return
    var now = new Date()
    agents.forEach(function(agent) {
      if (!shouldRunCron(agent.cron_intervalo, now, agent.ultima_actividad)) return
      console.log('[TICK] ' + agent.emoji + ' ' + agent.nombre + ' (' + agent.id + ') â€” running cron')
      // Get tasks for this agent
      sbFetch('/rest/v1/aos_agente_tareas?agente_id=eq.' + agent.id + '&activa=eq.true&order=prioridad').then(function(tasks) {
        if (!tasks || !tasks.length) return
        // Ejecutar todas las tareas en secuencia con 2s de delay entre ellas
        tasks.reduce(function(chain, task, idx) {
          return chain.then(function() {
            return new Promise(function(res) { setTimeout(res, idx === 0 ? 0 : 2000) })
              .then(function() { return executeTask(agent, task) })
          })
        }, Promise.resolve())
      })
    })
  }).catch(function(e) { bgFail(); console.error('[TICK] Error:', e.message) })
}

function shouldRunCron(cronStr, now, lastRun) {
  if (!cronStr) return false
  var last = lastRun ? new Date(lastRun) : new Date(0)
  var diffMin = (now - last) / 60000

  // Usar hora Lima para crons diarios (Railway corre en UTC)
  var limaHour = new Date(Date.now() + (-5 * 60) * 60000).getHours()
  var limaMin  = new Date(Date.now() + (-5 * 60) * 60000).getMinutes()
  var limaDay  = new Date(Date.now() + (-5 * 60) * 60000).getDay()

  if (cronStr === '*/30 * * * *') return diffMin >= 30
  if (cronStr === '0 * * * *')    return diffMin >= 60 && limaMin < 5
  if (cronStr === '0 */2 * * *')  return diffMin >= 120 && limaMin < 5
  if (cronStr === '0 */4 * * *')  return diffMin >= 240 && limaMin < 5
  if (cronStr === '0 */3 * * *')  return diffMin >= 180 && limaMin < 5
  if (cronStr.match(/^0 [\d,]+ \* \* \*/)) {
    var hours = cronStr.split(' ')[1].split(',').map(Number)
    return hours.indexOf(limaHour) >= 0 && limaMin < 5 && diffMin >= 55
  }
  if (cronStr.match(/^0 \d+ \* \* \d$/)) {
    var hour2 = parseInt(cronStr.split(' ')[1])
    var dow   = parseInt(cronStr.split(' ')[4])
    return limaDay === dow && limaHour === hour2 && limaMin < 5 && diffMin >= 1440
  }
  if (cronStr.match(/^0 \d+ \* \* \*/)) {
    var hour3 = parseInt(cronStr.split(' ')[1])
    return limaHour === hour3 && limaMin < 5 && diffMin >= 60
  }
  return false
}

// Manual tick endpoint (POST /api/agents/tick)
function agentTick(req, res) {
  var body = ''
  req.on('data', function(c) { body += c })
  req.on('end', function() {
    autoTick()
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ ok: true, msg: 'Tick executed' }))
  })
}

// Run single agent (POST /api/agents/run {agent_id, task_id?})
function agentRunSingle(req, res) {
  var body = ''
  req.on('data', function(c) { body += c })
  req.on('end', function() {
    try {
      var d = JSON.parse(body)
      if (!d.agent_id) { res.writeHead(400); res.end('{"error":"agent_id required"}'); return }
      sbFetch('/rest/v1/aos_agentes?id=eq.' + d.agent_id).then(function(agents) {
        if (!agents || !agents[0]) { res.writeHead(404); res.end('{"error":"Agent not found"}'); return }
        var agent = agents[0]
        var taskFilter = d.task_id ? '&id=eq.' + d.task_id : '&order=prioridad&limit=1'
        sbFetch('/rest/v1/aos_agente_tareas?agente_id=eq.' + agent.id + '&activa=eq.true' + taskFilter).then(function(tasks) {
          if (!tasks || !tasks[0]) { res.writeHead(404); res.end('{"error":"No active tasks"}'); return }
          console.log('[RUN] ' + agent.emoji + ' ' + agent.nombre + ' â†’ ' + tasks[0].nombre)
          executeTask(agent, tasks[0]).then(function(result) {
            res.writeHead(200, { 'Content-Type': 'application/json' })
            res.end(JSON.stringify({ ok: true, agent: agent.nombre, task: tasks[0].nombre, result: result }))
          })
        })
      })
    } catch(e) { res.writeHead(400); res.end(JSON.stringify({ error: e.message })) }
  })
}

// Agent status endpoint
function agentStatus(res) {
  sbFetch('/rest/v1/aos_agentes?select=id,nombre,emoji,area,cargo,motor_ai,estado,bubble_text,ultima_actividad,total_ejecuciones,total_tokens_usados,activo&order=area,nombre').then(function(agents) {
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ ok: true, agents: agents, timestamp: new Date().toISOString() }))
  }).catch(function(e) {
    res.writeHead(500, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ error: e.message }))
  })
}

// Load keys on startup
setTimeout(loadAIKeys, 2000)

// â•â•â• STUDIO CRON SCHEDULER â•â•â•
// Revisa cada 60 segundos si hay contenido programado que deba publicarse
function studioSchedulerRun() {
  var now = new Date().toISOString()
  https.get({
    hostname: 'ituyqwstonmhnfshnaqz.supabase.co',
    path: '/rest/v1/aos_studio_contenido?estado=eq.PROGRAMADO&fecha_programada=lte.' + now + '&limit=3&order=fecha_programada.asc',
    headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }
  }, function(res) {
    var data = ''; res.on('data', function(c) { data += c }); res.on('end', function() {
      try {
        var items = JSON.parse(data)
        if (!items || !items.length) return
        console.log('[STUDIO-CRON] ' + items.length + ' contenidos para publicar')
        items.forEach(function(item) {
          /* FIX: Marcar como EN_PROCESO primero para evitar duplicados */
          var lockBody = JSON.stringify({ estado: 'EN_PROCESO', updated_at: new Date().toISOString() })
          var lockReq = https.request({
            hostname: 'ituyqwstonmhnfshnaqz.supabase.co',
            path: '/rest/v1/aos_studio_contenido?id=eq.' + item.id + '&estado=eq.PROGRAMADO',
            method: 'PATCH',
            headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(lockBody) }
          }, function(lockRes) {
            /* Solo publicar si el lock tuvo Ã©xito (estado era PROGRAMADO) */
            var plats = item.plataformas || ['instagram']
            var pubDone = 0; var pubSuccess = 0; var pubTotal = plats.length
            plats.forEach(function(plat) {
              studioPublishToNetwork(plat, item, function(success, result) {
                if(success) pubSuccess++
                pubDone++
                /* Registrar publicaciÃ³n */
                var pubBody = JSON.stringify({
                  contenido_id: item.id, plataforma: plat,
                  post_id_externo: (result && (result.media_id || result.post_id)) || '',
                  estado: success ? 'PUBLICADO' : 'ERROR',
                  error_detalle: success ? null : (result && result.error) || 'Unknown',
                  publicado_at: success ? new Date().toISOString() : null
                })
                var pReq = https.request({
                  hostname: 'ituyqwstonmhnfshnaqz.supabase.co', path: '/rest/v1/aos_studio_publicaciones', method: 'POST',
                  headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(pubBody) }
                }, function() {}); pReq.on('error', function() {}); pReq.write(pubBody); pReq.end()
                console.log('[STUDIO-CRON] ' + plat + ': ' + (success ? 'OK' : 'FAIL') + ' - ' + (item.titulo || '').substring(0, 30))
                
                /* FIX: Solo marcar PUBLICADO cuando TODAS las redes terminaron */
                if(pubDone === pubTotal) {
                  var finalEstado = pubSuccess > 0 ? 'PUBLICADO' : 'ERROR_PUBLICACION'
                  var upBody = JSON.stringify({ estado: finalEstado, updated_at: new Date().toISOString() })
                  var uReq = https.request({
                    hostname: 'ituyqwstonmhnfshnaqz.supabase.co', path: '/rest/v1/aos_studio_contenido?id=eq.' + item.id, method: 'PATCH',
                    headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(upBody) }
                  }, function() {}); uReq.on('error', function() {}); uReq.write(upBody); uReq.end()
                }
              })
            })
          })
          lockReq.on('error', function() {})
          lockReq.write(lockBody); lockReq.end()
        })
      } catch(e) { /* silent */ }
    })
  }).on('error', function() {})
}

function studioPublishToNetwork(plat, item, callback) {
  if (plat === 'instagram') {
    var IG_TOKEN = process.env.INSTAGRAM_ACCESS_TOKEN
    var IG_USER_ID = process.env.INSTAGRAM_USER_ID
    if (!IG_TOKEN || !IG_USER_ID || !item.imagen_url) { callback(false, {error: 'Not configured or no image'}); return }
    var containerData = 'image_url=' + encodeURIComponent(item.imagen_url) + '&caption=' + encodeURIComponent(item.copy_principal || '') + '&access_token=' + encodeURIComponent(IG_TOKEN)
    var containerReq = https.request({
      hostname: 'graph.facebook.com', path: '/v22.0/' + IG_USER_ID + '/media?' + containerData, method: 'POST', headers: { 'Content-Length': 0 }
    }, function(cRes) {
      var cData = ''; cRes.on('data', function(c) { cData += c }); cRes.on('end', function() {
        try {
          var container = JSON.parse(cData)
          if (!container.id) { callback(false, {error: 'Container failed'}); return }
          var pubReq = https.request({
            hostname: 'graph.facebook.com', path: '/v22.0/' + IG_USER_ID + '/media_publish?creation_id=' + container.id + '&access_token=' + encodeURIComponent(IG_TOKEN), method: 'POST', headers: { 'Content-Length': 0 }
          }, function(pRes) {
            var pData = ''; pRes.on('data', function(c2) { pData += c2 }); pRes.on('end', function() {
              try { var pub = JSON.parse(pData); callback(!!pub.id, {media_id: pub.id}) } catch(e) { callback(false, {error: 'Parse error'}) }
            })
          })
          pubReq.on('error', function(e) { callback(false, {error: e.message}) })
          pubReq.end()
        } catch(e) { callback(false, {error: 'Container parse error'}) }
      })
    })
    containerReq.on('error', function(e) { callback(false, {error: e.message}) })
    containerReq.end()
  } else if (plat === 'facebook') {
    var FB_TOKEN = process.env.FACEBOOK_ACCESS_TOKEN
    var FB_PAGE_ID = process.env.FACEBOOK_PAGE_ID
    if (!FB_TOKEN || !FB_PAGE_ID) { callback(false, {error: 'Not configured'}); return }
    var postData = JSON.stringify({ message: item.copy_principal || '', url: item.imagen_url || '', access_token: FB_TOKEN })
    var endpoint = item.imagen_url ? '/' + FB_PAGE_ID + '/photos' : '/' + FB_PAGE_ID + '/feed'
    var fbReq = https.request({
      hostname: 'graph.facebook.com', path: '/v22.0' + endpoint, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(postData) }
    }, function(fbRes) {
      var fbData = ''; fbRes.on('data', function(c) { fbData += c }); fbRes.on('end', function() {
        try { var r = JSON.parse(fbData); callback(!!r.id, {post_id: r.id}) } catch(e) { callback(false, {error: 'Parse error'}) }
      })
    })
    fbReq.on('error', function(e) { callback(false, {error: e.message}) })
    fbReq.write(postData); fbReq.end()
  } else if (plat === 'linkedin') {
    var LI_TOKEN = process.env.LINKEDIN_ACCESS_TOKEN
    if (!LI_TOKEN) { callback(false, {error: 'Not configured'}); return }
    var LI_ORG = process.env.LINKEDIN_ORG_ID
    var author = LI_ORG ? 'urn:li:organization:' + LI_ORG : 'urn:li:person:me'
    var liData = JSON.stringify({ author: author, commentary: item.copy_principal || '', visibility: 'PUBLIC', distribution: { feedDistribution: 'MAIN_FEED' }, lifecycleState: 'PUBLISHED' })
    var liReq = https.request({
      hostname: 'api.linkedin.com', path: '/rest/posts', method: 'POST',
      headers: { 'Authorization': 'Bearer ' + LI_TOKEN, 'Content-Type': 'application/json', 'X-Restli-Protocol-Version': '2.0.0', 'LinkedIn-Version': '202508', 'Content-Length': Buffer.byteLength(liData) }
    }, function(liRes) {
      var ld = ''; liRes.on('data', function(c) { ld += c }); liRes.on('end', function() {
        callback(liRes.statusCode === 201, {post_id: liRes.headers['x-restli-id'] || ''})
      })
    })
    liReq.on('error', function(e) { callback(false, {error: e.message}) })
    liReq.write(liData); liReq.end()
  } else {
    callback(false, {error: 'Platform not supported: ' + plat})
  }
}

// PERFORMANCE GUARD v1.2 â€” Studio background hibernado por defecto.
// El panel, tablas, assets y funciones de Studio permanecen intactos.
// ReactivaciÃ³n controlada: AOS_STUDIO_BACKGROUND_ENABLED=true + redeploy.
var STUDIO_BACKGROUND_ENABLED = /^(1|true|yes|on)$/i.test(String(process.env.AOS_STUDIO_BACKGROUND_ENABLED || 'false'))
var _studioSchedulerRunning = false
function guardedStudioSchedulerRun() {
  if (!STUDIO_BACKGROUND_ENABLED || _studioSchedulerRunning || !bgCanRun()) return
  _studioSchedulerRunning = true
  try { studioSchedulerRun() } catch(e) { bgFail(); console.error('[STUDIO-CRON] Guard error:', e.message) }
  setTimeout(function(){ _studioSchedulerRunning = false }, 45000)
}
if (STUDIO_BACKGROUND_ENABLED) {
  setInterval(guardedStudioSchedulerRun, 120000)
  setTimeout(guardedStudioSchedulerRun, 10000)
  console.log('[STUDIO-CRON] ACTIVE â€” revisiÃ³n protegida cada 120s')
} else {
  console.log('[STUDIO-CRON] HIBERNATED â€” background OFF; panel y datos preservados')
}
