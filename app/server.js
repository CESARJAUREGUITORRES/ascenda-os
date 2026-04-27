const http = require('http')
const https = require('https')
const fs   = require('fs')
const path = require('path')
const PORT = parseInt(process.env.PORT || '4173', 10)
// Servir siempre desde public/ (archivos HTML estáticos editados directamente)
// El build de vite no aplica a estos archivos
const PUB  = path.join(__dirname, 'public')
const MIME = {
  '.html':'text/html; charset=utf-8','.js':'application/javascript',
  '.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.ico':'image/x-icon'
}

// ═══ SUPABASE ═══
const SB_URL = 'https://ituyqwstonmhnfshnaqz.supabase.co'
const SB_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0'
const VERIFY_TOKEN = 'ascendaos_zivital_2026'

function sbPost(endpoint, body) {
  const url = new URL(SB_URL + endpoint)
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body)
    const req = https.request({
      hostname: url.hostname, path: url.pathname,
      method: 'POST',
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(data) }
    }, (res) => { let d = ''; res.on('data', c => d += c); res.on('end', () => resolve(res.statusCode)) })
    req.on('error', reject)
    req.write(data)
    req.end()
  })
}

// ═══ WEBHOOK VERIFY (GET) ═══
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

// ═══ WEBHOOK MESSAGE (POST) ═══
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

// ═══ STATIC ═══
function serve(f, res) {
  var mime = MIME[path.extname(f)] || 'text/plain'
  fs.stat(f, function(err, stat) {
    if (err) { res.writeHead(404); res.end('Not found'); return }
    res.writeHead(200, { 'Content-Type': mime, 'Content-Length': stat.size, 'Cache-Control': 'no-cache, no-store, must-revalidate' })
    fs.createReadStream(f).pipe(res)
  })
}

// ═══ SERVER ═══
http.createServer(function(req, res) {
  var p = req.url.split('?')[0]
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
  // ===== RESEND EMAIL API =====
  if (p === '/api/send-email' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        if (!d.to || !d.subject || !d.html) { res.writeHead(400); res.end(JSON.stringify({error:'Missing to, subject, or html'})); return }
        var RESEND_KEY = process.env.RESEND_API_KEY || 're_hMwhSNXd_4EobZ8KLvwWFQSg1P7SCpXtP'
        var emailData = JSON.stringify({
          from: d.from || 'Clínica Zi Vital <info@zivital.pe>',
          to: Array.isArray(d.to) ? d.to : [d.to],
          subject: d.subject,
          html: d.html,
          reply_to: d.reply_to || 'jaureguitorrescesar@gmail.com'
        })
        var rReq = https.request({
          hostname: 'api.resend.com', path: '/emails', method: 'POST',
          headers: { 'Authorization': 'Bearer ' + RESEND_KEY, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(emailData) }
        }, function(rRes) {
          var rData = ''; rRes.on('data', function(c) { rData += c }); rRes.on('end', function() {
            try {
              var result = JSON.parse(rData)
              // Log to Supabase
              var logData = JSON.stringify({
                destinatario_email: Array.isArray(d.to) ? d.to[0] : d.to,
                destinatario_nombre: d.nombre || '',
                destinatario_numero: d.numero || '',
                plantilla_id: d.plantilla_id || null,
                campania_id: d.campania_id || null,
                flujo_id: d.flujo_id || null,
                flujo_paso: d.flujo_paso || null,
                asunto: d.subject,
                variables_usadas: d.variables || {},
                estado: result.id ? 'enviado' : 'error',
                resend_id: result.id || null,
                error_msg: result.message || null,
                enviado_at: result.id ? new Date().toISOString() : null
              })
              var logReq = https.request({
                hostname: 'ituyqwstonmhnfshnaqz.supabase.co', path: '/rest/v1/aos_email_envios', method: 'POST',
                headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(logData) }
              }, function() {})
              logReq.on('error', function() {})
              logReq.write(logData); logReq.end()

              res.writeHead(result.id ? 200 : 400, { 'Content-Type': 'application/json' })
              res.end(JSON.stringify(result))
            } catch(e) { res.writeHead(500); res.end(JSON.stringify({error:'Parse error: ' + rData})) }
          })
        })
        rReq.on('error', function(e) { res.writeHead(500); res.end(JSON.stringify({error:e.message})) })
        rReq.write(emailData); rReq.end()
      } catch(e) { res.writeHead(400); res.end(JSON.stringify({error:'Invalid JSON'})) }
    }); return
  }
  if (p === '/api/send-email' && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }
  // ===== FIN RESEND =====
  // ===== 2FA CODE EMAIL =====
  if (p === '/api/send-2fa' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        if (!d.email || !d.code || !d.nombre) { res.writeHead(400); res.end('{"error":"missing fields"}'); return }
        var RESEND_KEY = process.env.RESEND_API_KEY || 're_hMwhSNXd_4EobZ8KLvwWFQSg1P7SCpXtP'
        var emailData = JSON.stringify({
          from: 'AscendaOS <info@zivital.pe>',
          to: [d.email],
          subject: '🔐 Código de verificación — AscendaOS',
          html: '<div style="font-family:Arial;max-width:400px;margin:0 auto;text-align:center;"><div style="background:linear-gradient(135deg,#071D4A,#0A4FBF);padding:24px;border-radius:12px 12px 0 0;"><div style="color:#00E5A0;font-size:10px;font-weight:700;letter-spacing:2px;">ASCENDA OS</div><div style="color:#fff;font-size:18px;font-weight:800;margin-top:6px;">Código de Verificación</div></div><div style="background:#fff;padding:24px;border:1px solid #eee;border-radius:0 0 12px 12px;"><p>Hola <b>' + d.nombre + '</b>,</p><p style="font-size:13px;color:#6B7BA8;">Tu código de acceso es:</p><div style="background:#F0F4FC;border-radius:12px;padding:20px;margin:16px 0;"><div style="font-family:monospace;font-size:36px;font-weight:800;letter-spacing:8px;color:#0A4FBF;">' + d.code + '</div></div><p style="font-size:11px;color:#9AAAC8;">Este código expira en 5 minutos. Si no solicitaste este código, ignora este mensaje.</p></div></div>'
        })
        var rReq = https.request({
          hostname: 'api.resend.com', path: '/emails', method: 'POST',
          headers: { 'Authorization': 'Bearer ' + RESEND_KEY, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(emailData) }
        }, function(rRes) {
          var rData = ''; rRes.on('data', function(c) { rData += c }); rRes.on('end', function() {
            res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(rData)
          })
        })
        rReq.on('error', function(e) { res.writeHead(500); res.end('{"error":"' + e.message + '"}') })
        rReq.write(emailData); rReq.end()
      } catch(e) { res.writeHead(400); res.end('{"error":"Invalid JSON"}') }
    }); return
  }
  if (p === '/api/send-2fa' && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }
  // ===== FIN 2FA =====
  // ===== TEMPLATE EMAILS (confirmación cita, recibo venta, seguimiento) =====
  if (p === '/api/send-template' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
      try {
        var d = JSON.parse(body)
        if (!d.to || !d.template) { res.writeHead(400); res.end('{"error":"missing to/template"}'); return }
        var html = '', subject = '', tipo = d.template
        // Construir variables para la plantilla
        var vars = { nombre: d.nombre||'Paciente', tratamiento: d.tratamiento||'', fecha: d.fecha||'', hora: d.hora||'', sede: d.sede||'', fecha_cita: d.fecha||d.fecha_cita||'', hora_cita: d.hora||d.hora_cita||'', monto: d.monto ? parseFloat(d.monto).toFixed(2) : '', metodo_pago: d.metodo_pago||d.metodo||'', saldo_actual: d.saldo_actual ? parseFloat(d.saldo_actual).toFixed(2) : '0.00', ultimo_tratamiento: d.ultimo_tratamiento||'', dias: d.dias||'', dias_sin_visita: d.dias_sin_visita||d.dias||'', ultima_fecha: d.ultima_fecha||'', catalogo_items: d.catalogo_items||'', pagados: d.pagados||'', dni: d.dni||'', email: d.email||d.to||'', telefono: d.telefono||'', venta_id: d.venta_id||'' }
        
        if (tipo === 'confirmacion_cita') {
          subject = '✅ Cita confirmada — ' + (d.sede || '') + ' · ' + (d.hora || '') + ' — ' + BRAND.nombre_empresa
          html = buildFromTemplate('confirmacion_cita', vars, function() { return buildEmailConfirmacionCita(d.nombre||'Paciente', d.tratamiento||'Consulta', d.hora||'', d.sede||'', d.fecha||'', {dni: d.dni, email: d.email || d.to, telefono: d.telefono}) })
          html += emailFirmaMedica(d.doctora || d.atendio || '')
        } else if (tipo === 'recibo_venta') {
          subject = '🧾 Recibo de pago — ' + BRAND.nombre_empresa
          html = buildFromTemplate('recibo_venta', vars, function() { return buildEmailReciboVenta(d.nombre||'Cliente', d.items||[], d.total||0, d.moneda||'PEN', d.metodo||'', d.sede||'', d.fecha||'', d.venta_id||'') })
          html += emailFirmaMedica(d.doctora || d.atendio || '')
        } else if (tipo === 'cotizacion') {
          subject = '📋 Tu cotización — ' + BRAND.nombre_empresa
          html = buildFromTemplate('catalogo', vars, function() { return buildEmailReciboVenta(d.nombre||'Cliente', d.items||[], d.total||0, d.moneda||'PEN', '', d.sede||'', d.fecha||'', '') })
        } else if (tipo === 'seguimiento') {
          subject = '💆‍♀️ ¿Cómo te fue con tu tratamiento? — ' + BRAND.nombre_empresa
          html = buildFromTemplate('seguimiento', vars, function() { return buildEmailSeguimiento(d.nombre||'Paciente', d.tratamiento||'', d.dias||7) })
        } else if (tipo === 'recordatorio') {
          subject = d.es_manana ? 'Tu cita de mañana — ' + (d.hora||'') : '¡Tu cita es hoy! ' + (d.hora||'')
          var recTipo = d.es_manana ? 'recordatorio' : 'recordatorio_hoy'
          html = buildFromTemplate(recTipo, vars, function() { return buildEmailRecordatorio(d.nombre||'Paciente', d.tratamiento||'', d.hora||'', d.sede||'', d.fecha||'', !!d.es_manana) })
          html += emailFirmaMedica(d.doctora || d.atendio || '')
        } else if (tipo === 'bienvenida') {
          subject = '¡Bienvenida a ' + BRAND.nombre_empresa + '! ✨'
          html = buildFromTemplate('bienvenida', vars, function() { return buildEmailBienvenida(d.nombre||'Paciente') })
        } else if (tipo === 'agradecimiento_visita') {
          subject = '🌟 ¡Gracias por tu visita! — ' + BRAND.nombre_empresa
          html = buildFromTemplate('agradecimiento_visita', vars, function() { return buildEmailAgradecimiento(d.nombre||'Paciente', d.tratamiento||'', d.sede||'', d.fecha||'') })
        } else if (tipo === 'saldo_pendiente') {
          subject = '💳 Tienes un saldo pendiente — ' + BRAND.nombre_empresa
          html = buildFromTemplate('saldo_pendiente', vars, function() { return buildEmailSaldoPendiente(d.nombre||'Paciente', d.items||[]) })
        } else if (tipo === 'cumpleanos') {
          subject = '🎂 ¡Feliz cumpleaños, ' + (d.nombre||'').split(' ')[0] + '! — ' + BRAND.nombre_empresa
          html = buildFromTemplate('cumpleanos', vars, function() { return buildEmailCumpleanos(d.nombre||'Paciente') })
        } else if (tipo === 'reactivacion') {
          subject = '💚 Te extrañamos, ' + (d.nombre||'').split(' ')[0] + ' — ' + BRAND.nombre_empresa
          html = buildFromTemplate('reactivacion', vars, function() { return buildEmailReactivacion(d.nombre||'Paciente', d.ultimo_tratamiento||'', d.dias||60) })
        } else if (tipo === 'no_asistencia') {
          subject = '😔 Lamentamos que no hayas podido asistir — ' + BRAND.nombre_empresa
          html = buildFromTemplate('no_asistencia', vars, function() { return buildEmailNoAsistencia(d.nombre||'Paciente', d.tratamiento||'', d.fecha||'', d.hora||'', d.sede||'') })
        } else if (tipo === 'confirmacion_pago') {
          subject = '✅ Pago recibido — S/' + parseFloat(d.monto||0).toFixed(2) + ' — ' + BRAND.nombre_empresa
          html = buildFromTemplate('confirmacion_pago', vars, function() { return buildEmailConfirmacionPago(d.nombre||'Paciente', d.tratamiento||'', d.monto||0, d.saldo_actual||0, d.metodo_pago||'') })
          html += emailFirmaMedica(d.doctora || d.atendio || '')
        } else if (tipo === 'reprogramacion') {
          subject = '🔄 Tu cita ha sido reprogramada — ' + BRAND.nombre_empresa
          html = buildFromTemplate('reprogramacion', vars, function() { return buildEmailReprogramacion ? buildEmailReprogramacion(d.nombre||'Paciente', d.tratamiento||'', d.hora||'', d.sede||'', d.fecha||'') : emailShell('Cita reprogramada', '<p>Tu cita ha sido reprogramada.</p>') })
          html += emailFirmaMedica(d.doctora || d.atendio || '')
        } else {
          res.writeHead(400); res.end('{"error":"template no reconocido: ' + tipo + '"}'); return
        }
        sendAgentEmail(d.to, subject, html, tipo, d.destinatario_id || d.to)
          .then(function(r) { res.writeHead(200, {'Content-Type':'application/json'}); res.end(JSON.stringify(r)) })
          .catch(function(e) { res.writeHead(500); res.end('{"error":"' + e.message + '"}') })
      } catch(e) { res.writeHead(400); res.end('{"error":"Invalid JSON"}') }
    }); return
  }
  if (p === '/api/send-template' && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }
  // ===== FIN TEMPLATE EMAILS =====
  // ===== RESEND STATS — datos reales de emails enviados =====
  if (p === '/api/resend-stats' && req.method === 'GET') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    // Consultar TODAS las fuentes de emails en Supabase
    var hoy = new Date(Date.now() + (-5*60)*60000).toISOString().split('T')[0]
    var mesActual = hoy.slice(0, 7)
    Promise.all([
      sbFetch('/rest/v1/aos_emails_enviados?select=id,tipo,destinatario,email_destino,asunto,fecha_envio,resend_id,html_preview,created_at&order=created_at.desc&limit=200'),
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
        allEmails.push({ to: dest, subject: subj, status: e.resend_id ? 'delivered' : 'sent', created_at: e.created_at, tipo: tipoClean, origen: 'agente', html: e.html_preview || '' })
      })
      panel.forEach(function(e) {
        allEmails.push({ to: e.destinatario_email, subject: e.asunto, status: e.estado === 'enviado' ? 'delivered' : e.estado, created_at: e.enviado_at || e.created_at, tipo: 'manual', origen: 'panel' })
      })
      seguridad.forEach(function(e) {
        allEmails.push({ to: e.usuario, subject: '🔑 Código 2FA — Login', status: 'delivered', created_at: e.created_at, tipo: 'sistema', origen: 'sistema' })
      })
      // Ordenar por fecha desc
      allEmails.sort(function(a, b) { return (b.created_at || '') > (a.created_at || '') ? 1 : -1 })
      // Calcular métricas
      var totalHoy = 0, totalMes = 0, entregados = 0, porTipo = {}
      allEmails.forEach(function(e) {
        var fecha = (e.created_at || '').slice(0, 10)
        var mes = (e.created_at || '').slice(0, 7)
        if (fecha === hoy) totalHoy++
        if (mes === mesActual) totalMes++
        if (e.status === 'delivered' || e.status === 'enviado') entregados++
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
        rebotados: 0,
        abiertos: 0,
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

          // Cargar contexto real para que el agente sepa qué puede hacer
          return buildChatContext(agentId).then(function(ctx) {
            var sysPrompt = baseSysPrompt + '\n\n' + ctx
            return callGroqChat(sysPrompt, msgs, modelo)
          })
        }).then(function(reply) {
          res.writeHead(200, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify({ ok: true, reply: reply }))
        }).catch(function(e) {
          res.writeHead(200, { 'Content-Type': 'application/json' })
          res.end(JSON.stringify({ ok: false, reply: '⚠ ' + (e.message || 'error'), error: e.message }))
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
  // ===== FIN AGENTS =====
  var f = path.join(PUB, p.slice(1))
  if (fs.existsSync(f) && !fs.statSync(f).isDirectory()) { serve(f, res); return }
  serve(path.join(PUB, 'login.html'), res)
}).listen(PORT, '0.0.0.0', function() {
  console.log('AscendaOS http://0.0.0.0:' + PORT)
  console.log('Webhook: https://ascenda-os-production.up.railway.app/webhook')
  console.log('Agents: Think-loop ready on /api/agents/tick')
  // Auto-tick every 60 seconds for cron agents
  setInterval(function() { autoTick() }, 30000) // cada 30s — más visible
  console.log('Agents: Auto-tick every 60s started')
})



// ═══ TRACKING DE COSTOS Y CONTENIDO ═══
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

// ═══════════════════════════════════════════════════════════════
// MOTOR DE ACCIONES — agentes actúan, no solo analizan
// ═══════════════════════════════════════════════════════════════

var RESEND_KEY_AG = process.env.RESEND_API_KEY || 're_hMwhSNXd_4EobZ8KLvwWFQSg1P7SCpXtP'

// ═══ BRANDING CACHE (se carga al inicio y refresca cada 30min) ═══
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
// Cargar al arrancar (con delay para que sbFetch esté listo)
setTimeout(loadBrand, 3000)
setInterval(loadBrand, 1800000) // refresh cada 30 min

// ═══ EMAIL TEMPLATE ENGINE — branding dinámico desde aos_configuracion ═══
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
    '<div style="background:' + hdrBg + ';padding:14px 32px;text-align:center;font-size:11px;color:' + BRAND.color_secundario + '">' + BRAND.nombre_empresa + ' · info@zivital.pe</div>' +
    '</div>'
}
function emailInfoBox(label, value) {
  return '<div style="margin-bottom:8px"><div style="font-size:11px;color:#94A3B8">' + label + '</div><div style="font-size:15px;font-weight:600;color:' + BRAND.color_secundario + '">' + value + '</div></div>'
}
function emailCard(content) {
  return '<div style="background:' + BRAND.color_primario + ';border-radius:10px;padding:18px 20px;border-left:4px solid ' + BRAND.color_secundario + ';margin-bottom:20px">' + content + '</div>'
}

// ═══ FIRMA MÉDICA CON CMP — se inyecta en recibos/confirmaciones cuando hay doctora ═══
var _cmpCache = {} // nombre → {cmp, nombre_completo}
function loadCmpCache() {
  sbFetch('/rest/v1/aos_usuarios?select=nombre,apellidos,cmp&area=eq.médica&cmp=neq.').then(function(rows) {
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

// Enviar email vía Resend (reutiliza la misma clave y from)
function sendAgentEmail(to, subject, html, tipo, destinatario_id) {
  return new Promise(function(resolve) {
    // Anti-duplicado: verificar si ya se envió hoy
    sbFetch('/rest/v1/aos_emails_enviados?tipo=eq.' + encodeURIComponent(tipo) + '&destinatario=eq.' + encodeURIComponent(destinatario_id) + '&fecha_envio=eq.' + limaDateStr())
      .then(function(rows) {
        if (rows && rows.length > 0) { resolve({ skip: true, reason: 'ya enviado hoy' }); return }
        var emailData = JSON.stringify({
          from: 'Clínica Zi Vital <info@zivital.pe>',
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
                // Registrar envío para anti-duplicado
                sbPost('/rest/v1/aos_emails_enviados', {
                  tipo: tipo, destinatario: destinatario_id,
                  fecha_envio: limaDateStr(), resend_id: r.id,
                  email_destino: to, asunto: subject,
                  html_preview: html.slice(0, 50000)
                }).catch(function(){})
                // Alerta en panel
                sbPost('/rest/v1/aos_email_alertas', {
                  tipo: 'exito', template: tipo,
                  titulo: '✅ ' + tipo + ' enviado',
                  detalle: subject,
                  destinatario: to, resend_id: r.id
                }).catch(function(){})
              } else {
                // Alerta de error en panel
                sbPost('/rest/v1/aos_email_alertas', {
                  tipo: 'error', template: tipo,
                  titulo: '❌ Error enviando ' + tipo,
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
      }).catch(function(e) { resolve({ ok: false, error: e.message }) })
  })
}

// Insertar notificación en el CRM (aparece en el panel de notificaciones)
function notifyAdmin(titulo, contenido, tipo, prioridad) {
  return sbPost('/rest/v1/aos_notificaciones', {
    titulo: titulo, contenido: contenido,
    tipo: tipo || 'ALERTA', de: 'AGENTES_AI',
    para: 'ADMIN', prioridad: prioridad || 'ALTA',
    expira_at: new Date(Date.now() + 24*60*60*1000).toISOString()
  }).catch(function(){})
}

// Registrar acción real del agente
function logAction(agentId, tipoAccion, descripcion, metadata) {
  return sbPost('/rest/v1/aos_agente_acciones', {
    agente_id: agentId, tipo_accion: tipoAccion,
    descripcion: descripcion, metadata: metadata || {}
  }).catch(function(){})
}

// ═══ CACHE DE PLANTILLAS — Lee de aos_email_plantillas para usar en emails reales ═══
var _tplCache = {} // tipo → html_body
function loadTplCache() {
  sbFetch('/rest/v1/aos_email_plantillas?select=tipo,html_body,asunto&activo=eq.true').then(function(rows) {
    if (!rows) return
    _tplCache = {}
    rows.forEach(function(r) { if (r.html_body && r.html_body.length > 10) _tplCache[r.tipo] = { body: r.html_body, asunto: r.asunto }; })
    console.log('[TPL] Cache cargado:', Object.keys(_tplCache).length, 'plantillas')
  }).catch(function(e) { console.log('[TPL] Error cargando cache:', e.message) })
}
setTimeout(loadTplCache, 4000)
setInterval(loadTplCache, 600000) // Recargar cada 10 min

// Construir email desde plantilla BD o fallback a función hardcodeada
function buildFromTemplate(tipo, vars, fallbackFn) {
  var tpl = _tplCache[tipo]
  if (tpl && tpl.body) {
    var body = tpl.body
    // Reemplazar variables {{var}} con valores reales
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
  // Fallback a función hardcodeada
  return fallbackFn()
}

// Template email recordatorio de cita — COMPLETO con dirección y estacionamiento
function buildEmailRecordatorio(nombre, tratamiento, hora, sede, fecha, esManana) {
  var titulo = esManana ? 'Te esperamos mañana' : '¡Tu cita es hoy!'
  var cuando = esManana ? 'mañana' : 'hoy'
  var esPL = sede && sede.toUpperCase().indexOf('PUEBLO') > -1
  var sedeNombre = esPL ? 'PUEBLO LIBRE' : 'SAN ISIDRO'
  var sedeDir = esPL ? 'Av. Brasil 1170, Pueblo Libre - Lima' : 'Av. Javier Prado Este 996 - Ofi 501 - Lima · Edificio Capricornio'
  var sedeMaps = esPL ? 'https://goo.gl/maps/Cw36T6YPudyRNmVe6' : 'https://maps.app.goo.gl/co7ch54zHCt1Nj6w5'

  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">' + titulo + ', ' + (nombre || '').split(' ')[0] + ' 👋</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 20px">Te recordamos que tienes una cita programada para <b>' + cuando + '</b>:</p>' +

    emailCard(
      '<div style="font-size:13px;font-weight:800;color:' + BRAND.color_secundario + ';margin-bottom:12px">📌 TU CITA DE ' + cuando.toUpperCase() + '</div>' +
      '<table style="width:100%;font-size:13px;border-collapse:collapse">' +
      '<tr><td style="padding:5px 0;color:#64748B;width:100px">Servicio:</td><td style="padding:5px 0;font-weight:700;color:' + BRAND.color_secundario + '">' + (tratamiento || '') + '</td></tr>' +
      (fecha ? '<tr><td style="padding:5px 0;color:#64748B">Día:</td><td style="padding:5px 0;font-weight:600;color:#071D4A">' + fecha + '</td></tr>' : '') +
      '<tr><td style="padding:5px 0;color:#64748B">Hora:</td><td style="padding:5px 0;font-weight:700;color:' + BRAND.color_secundario + '">' + (hora || '') + '</td></tr>' +
      '<tr><td style="padding:5px 0;color:#64748B">Sede:</td><td style="padding:5px 0;font-weight:800;color:' + BRAND.color_secundario + '">' + sedeNombre + '</td></tr>' +
      '</table>'
    ) +

    // Dirección
    '<div style="margin-top:12px;padding:14px;background:#F8FAFF;border-radius:10px;border:1px solid #E2E8F0">' +
    '<div style="font-size:11px;font-weight:700;color:#071D4A;margin-bottom:4px">📍 Sede ' + sedeNombre + '</div>' +
    '<div style="font-size:13px;color:#475569">' + sedeDir + '</div>' +
    '<a href="' + sedeMaps + '" style="display:inline-block;margin-top:6px;font-size:11px;color:' + BRAND.color_secundario + ';font-weight:600;text-decoration:none">Ver en Google Maps →</a>' +
    '</div>' +

    // Recomendaciones
    '<div style="margin-top:10px;padding:12px;background:#FFF7ED;border-radius:8px;border:1px solid #FED7AA">' +
    '<p style="color:#92400E;font-size:12px;margin:0">⏱️ Llegar <b>15 minutos antes</b> y presentar tu DNI en recepción.</p>' +
    '</div>' +

    '<p style="color:#94A3B8;font-size:12px;margin-top:20px">Si necesitas reprogramar, llámanos o escríbenos por WhatsApp.</p>' +
    '<p style="color:' + BRAND.color_secundario + ';font-size:14px;font-weight:700;text-align:center;margin-top:12px">¡TE ESPERAMOS! 🤗</p>'
  )
}

// Template email bienvenida paciente nuevo (branding dinámico)
function buildEmailBienvenida(nombre) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Bienvenida a ' + BRAND.nombre_empresa + ', ' + nombre.split(' ')[0] + ' ✨</div>',
    '<p style="color:#475569;font-size:15px">Nos alegra tenerte como parte de nuestra comunidad. En ' + BRAND.nombre_empresa + ' estamos comprometidos con tu bienestar y belleza.</p>' +
    '<p style="color:#475569;font-size:15px">Ante cualquier consulta sobre tus tratamientos o para agendar tu próxima cita, no dudes en escribirnos.</p>' +
    '<div style="margin-top:24px;text-align:center">' +
    '<a href="mailto:info@zivital.pe" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">Contáctanos</a>' +
    '</div>'
  )
}

// Template email confirmación de cita — COMPLETO con datos del paciente, dirección, estacionamiento
function buildEmailConfirmacionCita(nombre, tratamiento, hora, sede, fecha, datos) {
  var d = datos || {}
  var esPL = sede && sede.toUpperCase().indexOf('PUEBLO') > -1
  var sedeNombre = esPL ? 'PUEBLO LIBRE' : 'SAN ISIDRO'
  var sedeDir = esPL ? 'Av. Brasil 1170, Pueblo Libre - Lima' : 'Av. Javier Prado Este 996 - Ofi 501 - Lima · Edificio Capricornio'
  var sedeMaps = esPL ? 'https://goo.gl/maps/Cw36T6YPudyRNmVe6' : 'https://maps.app.goo.gl/co7ch54zHCt1Nj6w5'
  var sedeRef = esPL ? 'A 4 cuadras de la Rambla (en la misma recta)' : ''

  // Estacionamiento por sede
  var estacionamiento = ''
  if (esPL) {
    estacionamiento = '<div style="font-size:11px;font-weight:700;color:#071D4A;margin-bottom:6px">🚗 Estacionamiento</div>' +
      '<div style="font-size:11px;color:#475569;line-height:1.6">' +
      '✅ Frente a nuestra fachada (depende de la hora)<br>' +
      '✅ <a href="https://maps.app.goo.gl/6uVF3qf4MVbYjGkn9" style="color:' + BRAND.color_secundario + '">Univ. Alas Peruanas</a> — Jr. Pedro Ruiz Gallo 251<br>' +
      '✅ <a href="https://maps.app.goo.gl/aLcsQ2Pg1fmfZU3h6" style="color:' + BRAND.color_secundario + '">C.E.P. Santa María</a> — Jr. Pedro Ruiz Gallo 137<br>' +
      '✅ <a href="https://goo.gl/maps/yhwvXKMothFwQJoH6" style="color:' + BRAND.color_secundario + '">Playa Otorcuna</a> — Juan Pablo Fernandini 1255' +
      '</div>'
  } else {
    estacionamiento = '<div style="font-size:11px;font-weight:700;color:#071D4A;margin-bottom:6px">🚗 Estacionamiento</div>' +
      '<div style="font-size:11px;color:#475569;line-height:1.6">' +
      '✅ Frente al Edificio Capricornio (según disponibilidad)<br>' +
      '✅ <a href="https://maps.app.goo.gl/omT3RWCxVnrvg4MNA" style="color:' + BRAND.color_secundario + '">Gratuito (máx. 3h)</a> — Av. Aux. Rep. de Panamá<br>' +
      '✅ <a href="https://maps.app.goo.gl/bM6xMzotahK5BQPJ8" style="color:' + BRAND.color_secundario + '">Los Portales</a> — C. Ricardo Angulo 197<br>' +
      '✅ <a href="https://maps.app.goo.gl/YEfCyNqVS5imdkL89" style="color:' + BRAND.color_secundario + '">C.C. Santa Catalina</a> — Av. Carlos Villarán 500' +
      '</div>'
  }

  // Taxi info para San Isidro
  var taxiInfo = esPL ? '' :
    '<div style="margin-top:10px;padding:10px;background:#EBF5FF;border-radius:8px;border:1px solid #BFDBFE">' +
    '<div style="font-size:11px;font-weight:700;color:#1E40AF">🚖 Si vienes en taxi con app</div>' +
    '<div style="font-size:10px;color:#475569;margin-top:4px">Buscar: <b>Av. Javier Prado Este 996, San Isidro</b> o <b>ZI VITAL SAN ISIDRO</b><br>' +
    '⚠️ YANGO: usar <i>Av Pablo Carriquiry 106, San Isidro</i> (esquina del edificio)</div></div>'

  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Aquí te envío tu confirmación de cita ♥</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 6px">Hola <b>' + (nombre || '').split(' ')[0] + '</b>, tu cita ha sido registrada exitosamente.</p>' +
    '<p style="color:#475569;font-size:12px;margin:0 0 20px">Te saluda tu Asesora de salud de la Clínica Estética Zi Vital 🏥👩‍⚕️</p>' +

    // Card de datos de la cita
    emailCard(
      '<div style="font-size:13px;font-weight:800;color:' + BRAND.color_secundario + ';margin-bottom:12px">📌 CITA CONFIRMADA</div>' +
      '<table style="width:100%;font-size:13px;border-collapse:collapse">' +
      '<tr><td style="padding:6px 0;color:#64748B;width:130px">Nombre:</td><td style="padding:6px 0;font-weight:600;color:#071D4A">' + (nombre || '') + '</td></tr>' +
      (d.dni ? '<tr><td style="padding:6px 0;color:#64748B">DNI / C.E:</td><td style="padding:6px 0;font-weight:600;color:#071D4A">' + d.dni + '</td></tr>' : '') +
      (d.email ? '<tr><td style="padding:6px 0;color:#64748B">E-mail:</td><td style="padding:6px 0;color:#071D4A">' + d.email + '</td></tr>' : '') +
      (d.telefono ? '<tr><td style="padding:6px 0;color:#64748B">Teléfono:</td><td style="padding:6px 0;color:#071D4A">' + d.telefono + '</td></tr>' : '') +
      '<tr><td style="padding:6px 0;color:#64748B">Día:</td><td style="padding:6px 0;font-weight:700;color:' + BRAND.color_secundario + '">' + (fecha || '') + '</td></tr>' +
      '<tr><td style="padding:6px 0;color:#64748B">Horario:</td><td style="padding:6px 0;font-weight:700;color:' + BRAND.color_secundario + '">' + (hora || '') + '</td></tr>' +
      '<tr><td style="padding:6px 0;color:#64748B">Servicio:</td><td style="padding:6px 0;font-weight:700;color:' + BRAND.color_secundario + '">' + (tratamiento || '') + '</td></tr>' +
      '<tr><td style="padding:6px 0;color:#64748B">Sede:</td><td style="padding:6px 0;font-weight:800;color:' + BRAND.color_secundario + '">' + sedeNombre + '</td></tr>' +
      '</table>'
    ) +

    // Dirección con mapa
    '<div style="margin-top:16px;padding:14px;background:#F8FAFF;border-radius:10px;border:1px solid #E2E8F0">' +
    '<div style="font-size:11px;font-weight:700;color:#071D4A;margin-bottom:4px">📍 Sede ' + sedeNombre + '</div>' +
    '<div style="font-size:13px;color:#475569">' + sedeDir + '</div>' +
    (sedeRef ? '<div style="font-size:11px;color:#94A3B8;margin-top:2px">' + sedeRef + '</div>' : '') +
    '<a href="' + sedeMaps + '" style="display:inline-block;margin-top:8px;font-size:11px;color:' + BRAND.color_secundario + ';font-weight:600;text-decoration:none">📍 Ver en Google Maps →</a>' +
    '</div>' +

    // Recomendaciones
    '<div style="margin-top:12px;padding:14px;background:#FFF7ED;border-radius:8px;border:1px solid #FED7AA">' +
    '<p style="color:#92400E;font-size:12px;margin:0">⏱️ Llegar <b>15 minutos antes</b> y presentar su DNI en recepción.</p>' +
    '<p style="color:#92400E;font-size:11px;margin:6px 0 0">✔️ La consulta/tratamiento es personalizado. Puede haber tiempo de espera según la afluencia. Agradecemos su comprensión.</p>' +
    '</div>' +

    // Estacionamiento
    '<div style="margin-top:12px;padding:14px;background:#F0FDF4;border-radius:8px;border:1px solid #BBF7D0">' +
    estacionamiento +
    '</div>' +

    taxiInfo +

    '<p style="color:#94A3B8;font-size:11px;margin-top:20px;text-align:center">📱 Agréganos a tus contactos como <b>ZI VITAL</b> para recibir recordatorios y cupones de descuento.</p>' +
    '<p style="color:' + BRAND.color_secundario + ';font-size:14px;font-weight:700;text-align:center;margin-top:16px">¡TE ESPERAMOS! 🤗</p>'
  )
}

// Template email recibo de venta (nueva — branding dinámico)
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
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Recibo de pago 🧾</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 20px">Hola <b>' + nombre.split(' ')[0] + '</b>, aquí tienes el detalle de tu compra.</p>' +
    emailCard(
      '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">' +
      '<span style="font-size:11px;color:#94A3B8">Nro. Operación</span>' +
      '<span style="font-size:13px;font-weight:700;color:' + BRAND.color_secundario + '">' + (ventaId || '—') + '</span>' +
      '</div>' +
      '<div style="display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px">' +
      emailInfoBox('Fecha', fecha || '') + emailInfoBox('Sede', sede || '') + emailInfoBox('Método', metodoPago || '') +
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
    '<div style="font-size:8px;font-weight:700;color:#94A3B8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px">Términos y condiciones</div>' +
    '<div style="font-size:8px;color:#94A3B8;line-height:1.5">' +
    '• Algunas promociones aplican únicamente para pagos en efectivo, transferencia, Yape o Plin. No aplican con tarjeta de débito o crédito.<br>' +
    '• No se realizan devoluciones post pago. En caso de requerir cambio, se emitirá un cupón por servicios del mismo monto o mayor. No aplica para productos.<br>' +
    '• Las cotizaciones tienen validez de 7 días calendario. Posterior a ello, los precios están sujetos a cambios sin previo aviso.<br>' +
    '• Este recibo es un comprobante interno de ' + BRAND.nombre_empresa + '. No constituye factura ni boleta fiscal.' +
    '</div></div>'
  )
}

// Template email seguimiento post-tratamiento (nueva — branding dinámico)
function buildEmailSeguimiento(nombre, tratamiento, diasDesde) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">¿Cómo te fue con tu tratamiento? 💆‍♀️</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 20px">Hola <b>' + nombre.split(' ')[0] + '</b>, hace ' + diasDesde + ' días realizaste tu tratamiento de <b>' + tratamiento + '</b> y queremos saber cómo te sientes.</p>' +
    emailCard(
      '<div style="font-size:14px;color:#475569">Tu bienestar es nuestra prioridad. Si tienes alguna consulta sobre los resultados o cuidados posteriores, estamos aquí para ayudarte.</div>'
    ) +
    '<div style="margin-top:20px;text-align:center">' +
    '<a href="https://wa.me/51999999999?text=Hola%2C%20quiero%20consultar%20sobre%20mi%20tratamiento%20de%20' + encodeURIComponent(tratamiento) + '" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">Escríbenos por WhatsApp</a>' +
    '</div>' +
    '<p style="color:#94A3B8;font-size:12px;margin-top:20px;text-align:center">¿Lista para tu próxima sesión? Agenda tu cita respondiendo a este correo.</p>'
  )
}

// ═══ TEMPLATE: Agradecimiento post-visita ═══
function buildEmailAgradecimiento(nombre, tratamiento, sede, fecha) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">¡Gracias por tu visita! 🌟</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 16px">Hola <b>' + (nombre||'').split(' ')[0] + '</b>, fue un placer atenderte en tu tratamiento de <b>' + (tratamiento||'') + '</b>' + (sede ? ' en nuestra sede de <b>' + sede + '</b>' : '') + '.</p>' +
    emailCard(
      '<div style="font-size:14px;color:#475569;line-height:1.6">Tu bienestar y satisfacción son nuestra prioridad. Esperamos que los resultados superen tus expectativas. 💆‍♀️</div>' +
      '<div style="font-size:12px;color:#6B7BA8;margin-top:8px">Si tienes alguna consulta sobre los cuidados posteriores de tu tratamiento, no dudes en escribirnos.</div>'
    ) +
    '<div style="text-align:center;margin-top:20px">' +
    '<a href="https://wa.me/51960618468?text=Hola%2C%20quiero%20consultar%20sobre%20mi%20tratamiento" style="display:inline-block;background:#25D366;color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">💬 Escríbenos por WhatsApp</a>' +
    '</div>' +
    '<p style="color:' + BRAND.color_secundario + ';font-size:14px;font-weight:700;text-align:center;margin-top:20px">¡Nos vemos pronto! 🤗</p>'
  )
}

// ═══ TEMPLATE: Recordatorio saldo pendiente ═══
function buildEmailSaldoPendiente(nombre, items) {
  var detalleHtml = (items||[]).map(function(it) {
    return '<tr><td style="padding:8px 12px;font-size:13px;font-weight:600;color:#334155">' + (it.tratamiento||'') + '</td>' +
      '<td style="padding:8px 12px;text-align:right;font-size:13px;color:#059669;font-weight:600">S/ ' + parseFloat(it.pagado||0).toFixed(2) + '</td>' +
      '<td style="padding:8px 12px;text-align:right;font-size:13px;color:#DC2626;font-weight:700">S/ ' + parseFloat(it.saldo||0).toFixed(2) + '</td></tr>'
  }).join('')
  var totalSaldo = (items||[]).reduce(function(s,it){return s+parseFloat(it.saldo||0)},0)
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Tienes un saldo pendiente 💳</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 16px">Hola <b>' + (nombre||'').split(' ')[0] + '</b>, te recordamos que tienes pagos pendientes por completar:</p>' +
    '<table style="width:100%;border-collapse:collapse;margin-bottom:16px">' +
    '<thead><tr style="background:' + BRAND.color_primario + '"><th style="padding:8px 12px;text-align:left;font-size:10px;font-weight:700;color:#64748B;text-transform:uppercase">Tratamiento</th><th style="padding:8px 12px;text-align:right;font-size:10px;font-weight:700;color:#64748B">Pagado</th><th style="padding:8px 12px;text-align:right;font-size:10px;font-weight:700;color:#64748B">Pendiente</th></tr></thead>' +
    '<tbody>' + detalleHtml + '</tbody>' +
    '<tfoot><tr style="background:' + BRAND.color_primario + '"><td style="padding:10px 12px;font-weight:700">TOTAL PENDIENTE</td><td></td><td style="padding:10px 12px;text-align:right;font-size:16px;font-weight:800;color:#DC2626">S/ ' + totalSaldo.toFixed(2) + '</td></tr></tfoot></table>' +
    '<p style="color:#475569;font-size:13px">Puedes acercarte a cualquiera de nuestras sedes para completar tu pago, o comunícate con nosotros para coordinar.</p>' +
    '<div style="text-align:center;margin-top:16px"><a href="https://wa.me/51960618468?text=Hola%2C%20quiero%20coordinar%20mi%20pago%20pendiente" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">Coordinar pago</a></div>'
  )
}

// ═══ TEMPLATE: Cumpleaños ═══
function buildEmailCumpleanos(nombre) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">¡Feliz cumpleaños, ' + (nombre||'').split(' ')[0] + '! 🎂🎉</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 16px">En <b>' + BRAND.nombre_empresa + '</b> queremos celebrar contigo este día tan especial.</p>' +
    emailCard(
      '<div style="text-align:center">' +
      '<div style="font-size:40px;margin-bottom:8px">🎁</div>' +
      '<div style="font-size:18px;font-weight:800;color:' + BRAND.color_secundario + ';margin-bottom:4px">¡Te regalamos un 10% de descuento!</div>' +
      '<div style="font-size:13px;color:#6B7BA8">En tu próximo tratamiento este mes. Solo menciona este correo al momento de tu visita.</div>' +
      '</div>'
    ) +
    '<p style="color:#475569;font-size:13px;text-align:center">Agenda tu cita y disfruta de tu regalo de cumpleaños. 🥳</p>' +
    '<div style="text-align:center;margin-top:16px"><a href="https://wa.me/51960618468?text=Hola%2C%20quiero%20agendar%20mi%20cita%20de%20cumplea%C3%B1os" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">🎂 Agendar mi cita</a></div>'
  )
}

// ═══ TEMPLATE: Reactivación paciente inactivo ═══
function buildEmailReactivacion(nombre, ultimoTrat, diasSinVisita) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Te extrañamos, ' + (nombre||'').split(' ')[0] + ' 💚</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 16px">Han pasado <b>' + (diasSinVisita||'') + ' días</b> desde tu último tratamiento' + (ultimoTrat ? ' de <b>' + ultimoTrat + '</b>' : '') + ' en ' + BRAND.nombre_empresa + '.</p>' +
    emailCard(
      '<div style="font-size:14px;color:#475569;line-height:1.6">Tu piel y tu bienestar nos importan. Queremos que sigas disfrutando de los beneficios de nuestros tratamientos con las mejores condiciones.</div>'
    ) +
    '<div style="margin-top:16px;padding:16px;background:#F0FDF4;border-radius:10px;border:1px solid #BBF7D0;text-align:center">' +
    '<div style="font-size:16px;font-weight:800;color:#059669;margin-bottom:4px">🌿 Condiciones especiales para tu regreso</div>' +
    '<div style="font-size:13px;color:#475569">Agenda tu cita esta semana y recibe atención preferencial.</div>' +
    '</div>' +
    '<div style="text-align:center;margin-top:20px"><a href="https://wa.me/51960618468?text=Hola%2C%20quiero%20reagendar%20mi%20tratamiento" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">💬 Quiero volver</a></div>'
  )
}

// ═══ TEMPLATE: No asistencia ═══
function buildEmailNoAsistencia(nombre, tratamiento, fecha, hora, sede) {
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">Lamentamos que no hayas podido asistir 😔</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 16px">Hola <b>' + (nombre||'').split(' ')[0] + '</b>, notamos que no pudiste asistir a tu cita de <b>' + (tratamiento||'') + '</b> programada para el ' + (fecha||'') + ' a las ' + (hora||'') + '.</p>' +
    emailCard(
      '<div style="font-size:14px;color:#475569">Entendemos que pueden surgir imprevistos. Tu salud y bienestar siguen siendo nuestra prioridad, y queremos ayudarte a reprogramar tu cita sin ningún inconveniente.</div>'
    ) +
    '<div style="text-align:center;margin-top:20px"><a href="https://wa.me/51960618468?text=Hola%2C%20quiero%20reprogramar%20mi%20cita%20de%20' + encodeURIComponent(tratamiento||'') + '" style="display:inline-block;background:' + BRAND.color_secundario + ';color:#fff;font-weight:700;padding:12px 28px;border-radius:8px;text-decoration:none;font-size:14px">🔄 Reprogramar mi cita</a></div>' +
    '<p style="color:#94A3B8;font-size:12px;margin-top:16px;text-align:center">También puedes llamarnos o escribirnos por WhatsApp para coordinar una nueva fecha.</p>'
  )
}

// ═══ TEMPLATE: Confirmación de pago ═══
function buildEmailConfirmacionPago(nombre, tratamiento, monto, saldoActual, metodoPago) {
  var saldoHtml = parseFloat(saldoActual||0) > 0.01 ?
    '<div style="margin-top:16px;padding:14px;background:#FEF3C7;border-radius:10px;border:1px solid #FDE68A">' +
    '<div style="font-size:13px;color:#92400E;font-weight:700">💰 Saldo pendiente: S/ ' + parseFloat(saldoActual).toFixed(2) + '</div>' +
    '<div style="font-size:11px;color:#92400E;margin-top:4px">Puedes completar tu pago en tu próxima visita o comunicándote con nosotros.</div></div>' :
    '<div style="margin-top:16px;padding:14px;background:#F0FDF4;border-radius:10px;border:1px solid #BBF7D0;text-align:center">' +
    '<div style="font-size:16px;margin-bottom:4px">🎉</div>' +
    '<div style="font-size:14px;font-weight:700;color:#059669">Pago completo — Sin saldo pendiente</div></div>'
  return emailShell(
    '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:22px;font-weight:800">¡Pago recibido con éxito! ✅</div>',
    '<p style="color:#475569;font-size:15px;margin:0 0 20px">Hola <b>' + (nombre||'').split(' ')[0] + '</b>, muchas gracias por tu confianza. Confirmamos que hemos recibido tu pago:</p>' +
    // Card principal de pago
    '<div style="background:linear-gradient(135deg,' + BRAND.color_primario + ',' + BRAND.color_degradado2 + ');border-radius:14px;padding:24px;margin-bottom:16px;text-align:center">' +
    '<div style="font-size:11px;color:#6B7BA8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px">Monto recibido</div>' +
    '<div style="font-size:36px;font-weight:800;color:#059669;font-family:Exo 2,sans-serif">S/ ' + parseFloat(monto||0).toFixed(2) + '</div>' +
    '<div style="margin-top:12px;display:flex;justify-content:center;gap:20px;flex-wrap:wrap">' +
    emailInfoBox('Servicio', tratamiento||'') +
    (metodoPago ? emailInfoBox('Método', metodoPago) : '') +
    '</div></div>' +
    saldoHtml +
    // Agradecimiento
    '<p style="color:#475569;font-size:13px;margin-top:20px;text-align:center">Agradecemos tu preferencia. Tu bienestar es nuestra prioridad. 💆‍♀️</p>' +
    '<div style="text-align:center;margin-top:12px"><a href="https://wa.me/51960618468" style="display:inline-block;background:#25D366;color:#fff;font-weight:700;padding:10px 24px;border-radius:8px;text-decoration:none;font-size:13px">💬 ¿Consultas? Escríbenos</a></div>' +
    // Términos y condiciones
    '<div style="margin-top:24px;padding:14px;background:#F8FAFC;border-radius:8px;border:1px solid #E2E8F0">' +
    '<div style="font-size:8px;font-weight:700;color:#94A3B8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px">Términos y condiciones</div>' +
    '<div style="font-size:8px;color:#94A3B8;line-height:1.5">' +
    '• Algunas promociones aplican únicamente para pagos en efectivo, transferencia, Yape o Plin. No aplican con tarjeta de débito o crédito.<br>' +
    '• No se realizan devoluciones post pago. En caso de requerir cambio, se emitirá un cupón por servicios del mismo monto o mayor. No aplica para productos.<br>' +
    '• Las cotizaciones tienen validez de 7 días calendario. Posterior a ello, los precios están sujetos a cambios sin previo aviso.<br>' +
    '• Este comprobante es un documento interno de ' + BRAND.nombre_empresa + ' y no constituye boleta ni factura fiscal.' +
    '</div></div>'
  )
}

// ═══════════════════════════════════════════════════════════════
// EJECUTOR DE ACCIONES — se llama después de sql_query si hay accion
// ═══════════════════════════════════════════════════════════════
function executeAction(agent, task, queryResult) {
  var accion = (task.input_config || {}).accion
  var template = (task.input_config || {}).template
  if (!accion) return Promise.resolve()

  var data = (queryResult && queryResult.data) ? queryResult.data : []
  if (!data.length) {
    console.log('[ACTION] ' + agent.nombre + ' — ' + accion + ': sin datos, nada que hacer')
    return Promise.resolve()
  }

  // ═══ ENVÍO EN LOTES — evitar rate limiting de Resend ═══
  // Envía de a 3 emails, espera 2 segundos entre lotes
  // Al final envía reporte al admin (César)
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
            if (r && r.skip) { results.skip++; console.log('[CARTERO] Skip ' + e.email + ' — ya enviado') }
            else if (r && r.ok) { results.ok++; console.log('[CARTERO] ✓ ' + e.email) }
            else { results.fail++; results.errors.push(e.email + ': respuesta inesperada'); console.log('[CARTERO] ⚠ ' + e.email + ' — sin confirmación') }
          }).catch(function(err) {
            results.fail++; results.errors.push(e.email + ': ' + (err.message || err))
            console.log('[CARTERO] ✕ ' + e.email + ' — ' + (err.message || err))
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
    sbFetch('/rest/v1/aos_email_alertas').catch(function(){}) // ensure table exists
    var body = JSON.stringify({ tipo: tipo, template: template, titulo: titulo, detalle: detalle || '', destinatario: destinatario || '', resend_id: resendId || '' })
    var url = new URL(SB_URL + '/rest/v1/aos_email_alertas')
    var req = https.request({ hostname: url.hostname, path: url.pathname, method: 'POST',
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(body) }
    }, function(){})
    req.on('error', function(){})
    req.write(body); req.end()
  }

  function sendAdminReport(agent, template, results, totalData) {
    var status = results.fail > 0 ? '⚠️' : '✅'
    var titulo = status + ' ' + template + ' — ' + results.ok + '/' + totalData + ' enviados'
    var detalle = 'OK:' + results.ok + ' Skip:' + results.skip + ' Fail:' + results.fail
    if (results.errors.length) detalle += ' | Errores: ' + results.errors.join(', ')

    // SIEMPRE guardar alerta en panel
    saveEmailAlerta(results.fail > 0 ? 'error' : 'exito', template, titulo, detalle)

    // Solo enviar reporte por email si son 3+ envíos
    if (totalData < 3) {
      console.log('[CARTERO] Reporte unitario, solo alerta panel: ' + titulo)
      return
    }

    var adminEmail = 'jaureguitorrescesar@gmail.com'
    var subject = status + ' Elena: ' + template + ' — ' + results.ok + '/' + totalData
    var errorList = results.errors.length ? '<div style="margin-top:12px;padding:12px;background:#FEF2F2;border-radius:8px;border:1px solid #FECACA"><div style="font-size:11px;font-weight:700;color:#DC2626;margin-bottom:6px">Errores (' + results.fail + '):</div><div style="font-size:10px;color:#991B1B">' + results.errors.join('<br>') + '</div></div>' : ''
    var html = emailShell(
      '<div style="color:' + (BRAND.color_header_texto || '#FFFFFF') + ';font-size:20px;font-weight:800">📊 Reporte de envío — Elena</div>',
      '<div style="display:flex;gap:12px;flex-wrap:wrap;margin-bottom:16px">' +
      '<div style="flex:1;min-width:80px;padding:12px;background:#F0FDF4;border-radius:8px;text-align:center"><div style="font-size:22px;font-weight:800;color:#059669">' + results.ok + '</div><div style="font-size:9px;color:#6B7BA8">Enviados</div></div>' +
      '<div style="flex:1;min-width:80px;padding:12px;background:#F0F4FC;border-radius:8px;text-align:center"><div style="font-size:22px;font-weight:800;color:#0A4FBF">' + results.skip + '</div><div style="font-size:9px;color:#6B7BA8">Ya enviados</div></div>' +
      '<div style="flex:1;min-width:80px;padding:12px;background:' + (results.fail > 0 ? '#FEF2F2' : '#F0FDF4') + ';border-radius:8px;text-align:center"><div style="font-size:22px;font-weight:800;color:' + (results.fail > 0 ? '#DC2626' : '#059669') + '">' + results.fail + '</div><div style="font-size:9px;color:#6B7BA8">Fallidos</div></div>' +
      '<div style="flex:1;min-width:80px;padding:12px;background:#F8FAFF;border-radius:8px;text-align:center"><div style="font-size:22px;font-weight:800;color:#071D4A">' + totalData + '</div><div style="font-size:9px;color:#6B7BA8">Total</div></div>' +
      '</div>' +
      '<p style="font-size:13px;color:#475569"><b>Tipo:</b> ' + template + ' · <b>Hora:</b> ' + new Date(Date.now() + (-5*60)*60000).toISOString().replace('T', ' ').slice(11,19) + ' Lima</p>' +
      errorList
    )
    fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + RESEND_KEY_AG, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: 'Clínica Zi Vital <info@zivital.pe>', to: [adminEmail], subject: subject, html: html })
    }).catch(function(e) { console.log('[CARTERO] Error reporte admin: ' + e.message) })
  }

  // ─── CARTERO: enviar emails reales ───────────────────────────
  if (accion === 'send_email' && template === 'recordatorio_manana') {
    var emails = data.filter(function(c) { return c.correo }).map(function(cita) {
      return {
        email: cita.correo,
        sendFn: function() {
          var html = buildEmailRecordatorio(cita.nombre, cita.tratamiento, cita.hora_cita, cita.sede, cita.fecha_cita, true)
          return sendAgentEmail(cita.correo, 'Tu cita de mañana en Zi Vital — ' + cita.hora_cita, html, 'recordatorio_manana', cita.correo + '_' + cita.fecha_cita)
            .then(function(r) {
              if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Recordatorio mañana → ' + cita.nombre, { correo: cita.correo, tratamiento: cita.tratamiento })
              return r
            })
        }
      }
    })
    return sendInBatches(emails, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: '📧 ' + results.ok + '/' + emails.length + ' recordatorios mañana ✓' })
      sendAdminReport(agent, 'recordatorio_manana', results, data.length)
    })
  }

  if (accion === 'send_email' && template === 'recordatorio_hoy') {
    var emails2 = data.filter(function(c) { return c.correo }).map(function(cita) {
      return {
        email: cita.correo,
        sendFn: function() {
          var html = buildEmailRecordatorio(cita.nombre, cita.tratamiento, cita.hora_cita, cita.sede, cita.fecha_cita, false)
          return sendAgentEmail(cita.correo, '¡Tu cita es hoy! ' + cita.hora_cita + ' — Zi Vital', html, 'recordatorio_hoy', cita.correo + '_' + cita.fecha_cita)
            .then(function(r) {
              if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Recordatorio hoy → ' + cita.nombre, { correo: cita.correo })
              return r
            })
        }
      }
    })
    return sendInBatches(emails2, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: '📧 ' + results.ok + '/' + emails2.length + ' recordatorios hoy ✓' })
      sendAdminReport(agent, 'recordatorio_hoy', results, data.length)
    })
  }

  if (accion === 'send_email' && template === 'bienvenida') {
    var sends3 = data.map(function(p) {
      if (!p['Email'] && !p.email) return Promise.resolve()
      var email = p['Email'] || p.email
      var nombre = p['Nombres'] || p.nombre || 'Paciente'
      var html = buildEmailBienvenida(nombre)
      return sendAgentEmail(email, '¡Bienvenida a Zi Vital, ' + nombre.split(' ')[0] + '! ✨', html, 'bienvenida', p.numero_limpio || email)
        .then(function(r) {
          if (r.ok) logAction(agent.id, 'email_enviado', 'Email bienvenida → ' + nombre, { email: email })
        })
    })
    return Promise.all(sends3)
  }

  // ─── CARTERO: comprobante de ventas del día (11pm) ───────────
  if (accion === 'send_email' && template === 'recibo_venta') {
    var emails4 = data.filter(function(v) { return v.correo }).map(function(venta) {
      return {
        email: venta.correo,
        sendFn: function() {
          var nombre = (venta.nombres || '') + ' ' + (venta.apellidos || '')
          var items = [{ nombre: venta.detalle_items || 'Servicios del día', cantidad: 1, subtotal: venta.total }]
          var html = buildEmailReciboVenta(nombre, items, venta.total, 'PEN', '', venta.sede || '', venta.fecha || '', '')
          return sendAgentEmail(venta.correo, '🧾 Tu comprobante de hoy — Zi Vital', html, 'recibo_venta', venta.correo + '_' + venta.fecha)
            .then(function(r) {
              if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Comprobante venta → ' + nombre.trim(), { correo: venta.correo, total: venta.total })
              return r
            })
        }
      }
    })
    return sendInBatches(emails4, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: '🧾 ' + results.ok + '/' + emails4.length + ' comprobantes ✓' })
      sendAdminReport(agent, 'recibo_venta', results, data.length)
    })
  }

  // ─── CARTERO: agradecimiento post-visita ───────────
  if (accion === 'send_email' && template === 'agradecimiento_visita') {
    var emails5 = data.filter(function(v) { return v.correo }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var html = buildEmailAgradecimiento(p.nombre, p.tratamiento, p.sede, p.fecha)
        return sendAgentEmail(p.correo, '🌟 ¡Gracias por tu visita! — Zi Vital', html, 'agradecimiento_visita', p.correo + '_' + (p.fecha || ''))
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Agradecimiento → ' + p.nombre, { correo: p.correo }); return r })
      }}
    })
    return sendInBatches(emails5, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: '🌟 ' + results.ok + ' agradecimientos ✓' })
      sendAdminReport(agent, 'agradecimiento_visita', results, data.length)
    })
  }

  // ─── CARTERO: saldos pendientes ───────────
  if (accion === 'send_email' && template === 'saldo_pendiente') {
    var emails6 = data.filter(function(v) { return v.correo }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var items = [{ tratamiento: p.tratamiento || '', pagado: p.pagado || 0, saldo: p.saldo || 0 }]
        var html = buildEmailSaldoPendiente(p.nombre, items)
        return sendAgentEmail(p.correo, '💳 Saldo pendiente — Zi Vital', html, 'saldo_pendiente', p.correo + '_saldo_semanal')
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Saldo pendiente → ' + p.nombre, { correo: p.correo, saldo: p.saldo }); return r })
      }}
    })
    return sendInBatches(emails6, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: '💳 ' + results.ok + ' recordatorios saldo ✓' })
      sendAdminReport(agent, 'saldo_pendiente', results, data.length)
    })
  }

  // ─── CARTERO: cumpleaños ───────────
  if (accion === 'send_email' && template === 'cumpleanos') {
    var emails7 = data.filter(function(v) { return v.correo }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var html = buildEmailCumpleanos(p.nombre)
        return sendAgentEmail(p.correo, '🎂 ¡Feliz cumpleaños! — Zi Vital', html, 'cumpleanos', p.correo + '_cumple_' + new Date().getFullYear())
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Cumpleaños → ' + p.nombre, { correo: p.correo }); return r })
      }}
    })
    return sendInBatches(emails7, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: '🎂 ' + results.ok + ' cumpleaños ✓' })
      sendAdminReport(agent, 'cumpleanos', results, data.length)
    })
  }

  // ─── CARTERO: reactivación ───────────
  if (accion === 'send_email' && template === 'reactivacion') {
    var emails8 = data.filter(function(v) { return v.correo }).map(function(p) {
      return { email: p.correo, sendFn: function() {
        var html = buildEmailReactivacion(p.nombre, p.ultimo_tratamiento, p.dias_sin_visita)
        return sendAgentEmail(p.correo, '💚 Te extrañamos — Zi Vital', html, 'reactivacion', p.correo + '_reactiv_' + new Date().toISOString().slice(0,7))
          .then(function(r) { if (r && r.ok && !r.skip) logAction(agent.id, 'email_enviado', 'Reactivación → ' + p.nombre, { correo: p.correo, dias: p.dias_sin_visita }); return r })
      }}
    })
    return sendInBatches(emails8, 3, 2000).then(function(results) {
      sbPatchAgent(agent.id, { bubble_text: '💚 ' + results.ok + ' reactivaciones ✓' })
      sendAdminReport(agent, 'reactivacion', results, data.length)
    })
  }

  // ─── CARTERO: reintentar emails fallidos del día ───────────
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
        // Marcar alerta como leída (procesada)
        sbPost('/rest/v1/aos_email_alertas?id=eq.' + err.id, { leido: true }, 'PATCH').catch(function(){})
        // Reenviar usando el endpoint send-template con datos mínimos
        var body = JSON.stringify({ to: email, template: tipo, nombre: 'Paciente', tratamiento: '', hora: '', sede: '', fecha: '' })
        var url = new URL(SB_URL.replace('supabase.co', '') + '') // dummy
        // Usar el endpoint local
        var reqData = JSON.stringify({ to: email, template: tipo, nombre: 'Paciente' })
        fetch('https://ascenda-os-production.up.railway.app/api/send-template', {
          method: 'POST', headers: { 'Content-Type': 'application/json' }, body: reqData
        }).then(function(r) { return r.json() }).then(function(d) {
          if (d && (d.ok || d.id)) {
            console.log('[CARTERO] ✓ Reintento exitoso: ' + email)
            logAction(agent.id, 'email_reintento', 'Reintento exitoso → ' + email, { template: tipo })
          } else {
            console.log('[CARTERO] ✕ Reintento fallido: ' + email)
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
      sbPatchAgent(agent.id, { bubble_text: '🔄 ' + data.length + ' reintentos procesados' })
    })
  }

  return Promise.resolve()
}
function executeRpcAction(agent, rpcName, result) {
  if (!result) return Promise.resolve()

  // ─── BRUNO (guardian): alertas reales al CRM ─────────────────
  if (agent.id === 'guardian' && rpcName === 'aos_inventario_alertas') {
    var agotados = (result.agotados || []).slice(0, 5)
    if (!agotados.length) return Promise.resolve()
    var lista = agotados.map(function(p){ return '• ' + p.nombre_producto + ' (' + p.sede + ')' }).join('\n')
    return notifyAdmin(
      '⚠ Bruno: ' + agotados.length + ' productos agotados',
      'Productos sin stock:\n' + lista + (result.agotados.length > 5 ? '\n...y ' + (result.agotados.length-5) + ' más.' : ''),
      'ALERTA', 'ALTA'
    ).then(function() {
      logAction(agent.id, 'notificacion_crm', agotados.length + ' alertas de inventario enviadas al CRM', { total: result.agotados.length })
      sbPatchAgent(agent.id, { bubble_text: '⚠ ' + result.agotados.length + ' productos agotados — CRM notificado' })
    })
  }

  // ─── BRUNO: alertas de venta ──────────────────────────────────
  if (agent.id === 'guardian' && rpcName === 'aos_alertas_venta') {
    var alertas = result.alertas || result || []
    if (!Array.isArray(alertas) || !alertas.length) return Promise.resolve()
    return notifyAdmin(
      '💰 Bruno: ' + alertas.length + ' alertas de ventas',
      alertas.slice(0,3).map(function(a){ return '• ' + (a.descripcion || JSON.stringify(a).substring(0,60)) }).join('\n'),
      'ALERTA', 'MEDIA'
    )
  }

  // ─── LEÓN (monitor): detectar anomalías en KPIs ───────────────
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
    // Solo notificar 1 vez por día — anti-spam
    return sbFetch('/rest/v1/aos_agente_acciones?agente_id=eq.monitor&tipo_accion=eq.alerta_kpi&created_at=gte.' + limaDateStr() + 'T00:00:00-05:00&limit=1')
      .then(function(rows) {
        if (rows && rows.length > 0) return // ya alertó hoy
        return notifyAdmin('📊 León: anomalía detectada', anomalias.join('\n'), 'ALERTA', 'MEDIA')
          .then(function() { logAction(agent.id, 'alerta_kpi', anomalias.join(' | '), { kpis: kpis }) })
      })
  }

  // ─── DANTE (centinela): detectar leads sin contactar ─────────
  // El sql_query ya devuelve los datos — esto se maneja en executeAction
  // Pero si viene de estado_bases, notificar si hay muchas vírgenes
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
        '📋 Dante: ' + virgenes + ' leads sin contactar',
        'Hay ' + virgenes + ' leads que nunca han sido contactados. Revisar distribución.',
        'ALERTA', 'MEDIA'
      ).then(function() {
        sbPatchAgent(agent.id, { bubble_text: '📋 ' + virgenes + ' leads vírgenes — equipo notificado' })
      })
    }
  }

  return Promise.resolve()
}

// ═══════════════════════════════════════════════
// RESOLVER DE PLACEHOLDERS — inyecta datos reales en prompts AI
// ═══════════════════════════════════════════════

// Utilidades de fecha Lima
function limaDateStr() {
  var d = new Date(Date.now() + (-5 * 60) * 60000)
  return d.toISOString().split('T')[0]
}
function limaFirstOfMonth() {
  return limaDateStr().slice(0, 8) + '01'
}

// Resumen de ventas de la semana para Sofía (analista)
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
      return 'Semana del ' + lunesStr + '. Ventas: ' + rows.length + '. Facturado: S/' + totalMonto.toFixed(0) + '. Ticket promedio: S/' + (totalMonto/rows.length).toFixed(0) + '. Pacientes únicos: ' + unicos + '. Top tratamientos: ' + top + '.'
    }).catch(function(){ return 'Error al cargar ventas.' })
}

// Leads recientes sin contactar para Nico (clasificador)
function fetchLeadsData() {
  return sbFetch('/rest/v1/aos_leads?fecha=gte.' + new Date(Date.now() - 3*86400000).toISOString().split('T')[0] + '&select=celular,tratamiento,anuncio,fecha,hora_ingreso,numero_limpio&order=fecha.desc&limit=20')
    .then(function(leads) {
      if (!leads || !leads.length) return 'Sin leads nuevos en los últimos 3 días.'
      // Enriquecer con estado de contacto
      var nums = leads.map(function(l){ return l.numero_limpio }).filter(Boolean).join(',')
      return sbFetch('/rest/v1/aos_llamadas?numero_limpio=in.(' + nums + ')&select=numero_limpio,estado&order=fecha.desc')
        .then(function(llams) {
          var llamSet = {}
          ;(llams||[]).forEach(function(l){ llamSet[l.numero_limpio] = l.estado })
          return leads.map(function(l) {
            return 'Tratamiento:' + l.tratamiento + '|Anuncio:' + (l.anuncio||'orgánico') + '|Fecha:' + l.fecha + '|Estado:' + (llamSet[l.numero_limpio] || 'SIN CONTACTAR')
          }).join('\n')
        })
    }).catch(function(){ return 'Error al cargar leads.' })
}

// Mensajes pendientes de agentes predecesores (cadenas)
function fetchPendingMessages(agentId) {
  return sbFetch('/rest/v1/aos_agente_mensajes?para_agente_id=eq.' + agentId + '&leido=eq.false&order=created_at.desc&limit=3')
    .then(function(msgs) {
      if (!msgs || !msgs.length) return null
      // Marcar como leídos
      msgs.forEach(function(m) {
        sbPatch('/rest/v1/aos_agente_mensajes?id=eq.' + m.id, { leido: true }).catch(function(){})
      })
      return msgs.map(function(m){ return m.de_agente_id + ': ' + m.mensaje.substring(0, 1000) }).join('\n\n---\n\n')
    }).catch(function(){ return null })
}

// Función principal: resuelve todos los placeholders del template
function resolvePlaceholders(agent, task, template) {
  var promises = []
  var keys = []

  // Detectar qué placeholders hay en el template
  if (template.indexOf('{ventas_data}') >= 0) {
    keys.push('ventas_data')
    promises.push(fetchVentasData())
  }
  if (template.indexOf('{leads_data}') >= 0) {
    keys.push('leads_data')
    promises.push(fetchLeadsData())
  }
  if (template.indexOf('{insights}') >= 0) {
    // Camila (creador) recibe de Sofía (analista) vía mensajes
    keys.push('insights')
    promises.push(fetchPendingMessages(agent.id).then(function(msg) {
      if (msg) return msg
      // Fallback: últimos KPIs reales si no hay mensaje de Sofía
      return sbFetch('/rest/v1/aos_agente_logs?agente_id=eq.analista&exitoso=eq.true&order=created_at.desc&limit=1&select=output_resumen')
        .then(function(rows) {
          if (!rows || !rows[0]) return 'Sin insights disponibles aún.'
          return rows[0].output_resumen ? rows[0].output_resumen.substring(0, 800) : 'Sin insights disponibles.'
        }).catch(function(){ return 'Sin insights disponibles.' })
    }))
  }
  if (template.indexOf('{tarea}') >= 0) {
    // KronIA — revisar si hay mensajes pendientes de agentes o usar cola de leads como contexto
    keys.push('tarea')
    promises.push(
      sbFetch('/rest/v1/aos_agente_mensajes?para_agente_id=eq.kronia&leido=eq.false&order=created_at.desc&limit=1')
        .then(function(msgs) {
          if (msgs && msgs[0]) {
            sbPatch('/rest/v1/aos_agente_mensajes?id=eq.' + msgs[0].id, { leido: true }).catch(function(){})
            return 'Mensaje de ' + msgs[0].de_agente_id + ': ' + msgs[0].mensaje.substring(0, 400)
          }
          // Sin mensajes — KronIA hace revisión del estado global
          return 'Revisión diaria del estado del equipo: verificar agentes bloqueados, leads sin contactar, y próximas citas del día.'
        }).catch(function(){ return 'Revisión general del equipo.' })
    )
  }
  if (template.indexOf('{chat_history}') >= 0) {
    keys.push('chat_history')
    promises.push(Promise.resolve('Sin conversaciones de WhatsApp disponibles — API pendiente de configuración.'))
  }
  if (template.indexOf('{kpis_data}') >= 0) {
    // Luna (resumidor) — KPIs reales del día
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
    console.log('[RESOLVE] ' + agent.nombre + ' — placeholders: ' + keys.join(', ') + ' | chars: ' + resolved.length)
    return resolved
  })
}

// ═══════════════════════════════════════════════
// AGENTS THINK-LOOP ENGINE
// ═══════════════════════════════════════════════

var GROQ_KEY = ''
var GEMINI_KEY = ''

// Load AI keys from Supabase on startup
function loadAIKeys() {
  sbFetch('/rest/v1/aos_integraciones?select=tipo,api_key&tipo=in.(groq,gemini)').then(function(rows) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].tipo === 'groq') GROQ_KEY = rows[i].api_key || ''
      if (rows[i].tipo === 'gemini') GEMINI_KEY = rows[i].api_key || ''
    }
    console.log('[AGENTS] Keys loaded — Groq:', GROQ_KEY ? 'YES' : 'NO', '| Gemini:', GEMINI_KEY ? 'YES' : 'NO')
  }).catch(function(e) { console.error('[AGENTS] Key load error:', e.message) })
}

function sbFetch(endpoint) {
  return new Promise(function(resolve, reject) {
    var url = new URL(SB_URL + endpoint)
    https.get({
      hostname: url.hostname, path: url.pathname + url.search,
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }
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

// ═══ CONTEXTO REAL PARA CHAT — SNAPSHOT CENTRALIZADO ═══
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

    // Contexto específico por agente
    if (agentId === 'cartero') {
      var citasM = s.citas_manana_detalle || []
      var conEmail = citasM.filter(function(c) { return c.correo })
      var sinEmail = citasM.filter(function(c) { return !c.correo })
      parts.push('CITAS MAÑANA: ' + citasM.length + ' total, ' + conEmail.length + ' con email, ' + sinEmail.length + ' sin email.')
      parts.push('DETALLE CITAS MAÑANA:')
      citasM.forEach(function(c) {
        parts.push('  • ' + c.nombre + ' — ' + c.tratamiento + ' ' + c.hora + ' ' + c.sede + (c.correo ? ' ✓' + c.correo : ' ✗SIN EMAIL'))
      })
      var emailsHoy = s.emails_hoy || []
      parts.push('EMAILS ENVIADOS HOY: ' + emailsHoy.length + '.')
      emailsHoy.forEach(function(e) { parts.push('  • ' + e.desc) })
    }

    if (agentId === 'centinela') {
      var lsc = s.leads_sin_contactar || []
      parts.push('LEADS SIN CONTACTAR (3 días): ' + lsc.length + '.')
      lsc.slice(0,10).forEach(function(l) {
        parts.push('  • ' + l.celular + ' — ' + l.tratamiento + ' (' + l.fecha + ')')
      })
      var seg = s.seguimientos_pendientes || []
      parts.push('SEGUIMIENTOS PENDIENTES: ' + seg.length + '.')
      seg.slice(0,5).forEach(function(s2) {
        parts.push('  • ' + s2.numero + ' — ' + s2.tratamiento + ' prog: ' + s2.fecha + ' asesor: ' + s2.asesor)
      })
    }

    if (agentId === 'guardian') {
      var inv = s.inventario_agotados || []
      parts.push('INVENTARIO AGOTADO: ' + inv.length + ' productos.')
      inv.slice(0,10).forEach(function(p) {
        parts.push('  • ' + p.producto + ' (' + p.sede + ', ' + p.categoria + ')')
      })
    }

    if (agentId === 'monitor' || agentId === 'analista' || agentId === 'analista_mkt') {
      var eq = s.equipo_hoy || []
      parts.push('EQUIPO HOY:')
      eq.forEach(function(e) {
        parts.push('  • ' + e.asesor + ': ' + e.llamadas + ' llamadas, ' + e.citas + ' citas')
      })
      var top = s.top_tratamientos || []
      parts.push('TOP TRATAMIENTOS MES:')
      top.forEach(function(t2) {
        parts.push('  • ' + t2.t + ': ' + t2.n + ' ventas, S/' + t2.m)
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
    parts.push('IMPORTANTE: Estos son datos reales de Supabase. Responde usando SOLO estos datos. Si te preguntan algo que no está arriba, di que necesitas que se actualice el snapshot o que ese dato específico no está en tu contexto actual.')

    return parts.join('\n')
  })
}

// Regenerar snapshot cada 5 min en Railway
setInterval(function() {
  sbRpc('aos_generar_snapshot', {})
    .then(function(snap) { _cachedSnapshot = snap; _snapshotAge = Date.now(); console.log('[SNAPSHOT] Regenerado OK') })
    .catch(function(e) { console.error('[SNAPSHOT] Error:', e.message) })
}, 300000) // 5 min

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
    // Filtro por día de semana (0=dom, 1=lun, 2=mar...)
    if (config.dia_semana !== undefined && config.dia_semana !== null) {
      if (_lh.getDay() !== parseInt(config.dia_semana)) {
        return Promise.resolve() // No es el día, skip
      }
    }
  }

  // Update agent status to working
  sbPatchAgent(agent.id, { estado: 'working', bubble_text: task.nombre, bubble_type: 'thought', ultima_actividad: new Date().toISOString() })

  if (tipo === 'rpc_call') {
    var rpcName = config.rpc
    var params = config.params || {}
    // Replace dynamic params — FIX: usar timezone Lima (UTC-5) para evitar desfase nocturno
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
      sbPatchAgent(agent.id, { estado: 'idle', bubble_text: task.nombre + ' ✓', total_ejecuciones: (agent.total_ejecuciones || 0) + 1, ultima_actividad: new Date().toISOString() })
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
      // Ejecutar acción real si la tarea la tiene definida
      executeAction(agent, task, result).catch(function(e) { console.error('[ACTION] Error:', e.message) })
      sbPatchAgent(agent.id, { estado: 'idle', bubble_text: task.nombre + ' ✓', total_ejecuciones: (agent.total_ejecuciones || 0) + 1, ultima_actividad: new Date().toISOString() })
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
      console.log('[FALLBACK] ' + agent.nombre + ' Gemini falló (' + primaryErr.message.substring(0,50) + ') → reintentando con Groq')
      sbPatchAgent(agent.id, { bubble_text: '⚡ Gemini no disponible → usando Groq' })
      return fallbackFn(sysPrompt, resolvedPrompt, 'llama-3.3-70b-versatile')
    }).then(function(aiResult) {
      var dur = Date.now() - start
      logAgent(agent.id, task.id, 'think', promptTemplate.substring(0, 200), aiResult.text.substring(0, 2000), motor, modelo, aiResult.tokens_in, aiResult.tokens_out, 0, dur, true, '')
      // Track costos reales
      trackCost(agent.id, motor, modelo, aiResult.tokens_in, aiResult.tokens_out, task.nombre)
      // Guardar contenido generado según agente
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
        console.log('[CHAIN] ' + agent.nombre + ' → ' + task.siguiente_agente_id + ' | ' + aiResult.text.substring(0, 80))
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
  sbFetch('/rest/v1/aos_agentes?select=*&activo=eq.true&tipo_ejecucion=eq.cron').then(function(agents) {
    if (!agents || !agents.length) return
    var now = new Date()
    agents.forEach(function(agent) {
      if (!shouldRunCron(agent.cron_intervalo, now, agent.ultima_actividad)) return
      console.log('[TICK] ' + agent.emoji + ' ' + agent.nombre + ' (' + agent.id + ') — running cron')
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
  }).catch(function(e) { console.error('[TICK] Error:', e.message) })
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
          console.log('[RUN] ' + agent.emoji + ' ' + agent.nombre + ' → ' + tasks[0].nombre)
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
