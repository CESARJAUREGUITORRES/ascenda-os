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
          from: d.from || 'Clínica Zi Vital <onboarding@resend.dev>',
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
          from: 'AscendaOS <onboarding@resend.dev>',
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
  if (p === '/' || p === '/login') { serve(path.join(PUB, 'login.html'), res); return }
  if (p === '/app') { serve(path.join(PUB, 'app.html'), res); return }
  var f = path.join(PUB, p.slice(1))
  if (fs.existsSync(f) && !fs.statSync(f).isDirectory()) { serve(f, res); return }
  serve(path.join(PUB, 'login.html'), res)
}).listen(PORT, '0.0.0.0', function() {
  console.log('AscendaOS http://0.0.0.0:' + PORT)
  console.log('Webhook: https://ascenda-os-production.up.railway.app/webhook')
})
