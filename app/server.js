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
  if (p === '/agents') { serve(path.join(PUB, 'agents.html'), res); return }
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
  // ===== FIN AGENTS =====
  var f = path.join(PUB, p.slice(1))
  if (fs.existsSync(f) && !fs.statSync(f).isDirectory()) { serve(f, res); return }
  serve(path.join(PUB, 'login.html'), res)
}).listen(PORT, '0.0.0.0', function() {
  console.log('AscendaOS http://0.0.0.0:' + PORT)
  console.log('Webhook: https://ascenda-os-production.up.railway.app/webhook')
  console.log('Agents: Think-loop ready on /api/agents/tick')
  // Auto-tick every 60 seconds for cron agents
  setInterval(function() { autoTick() }, 60000)
  console.log('Agents: Auto-tick every 60s started')
})

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
      sbPatchAgent(agent.id, { estado: 'idle', bubble_text: '', total_ejecuciones: (agent.total_ejecuciones || 0) + 1, ultima_actividad: new Date().toISOString() })
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
      sbPatchAgent(agent.id, { estado: 'idle', bubble_text: '', total_ejecuciones: (agent.total_ejecuciones || 0) + 1, ultima_actividad: new Date().toISOString() })
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

    return callFn(sysPrompt, promptTemplate, modelo).then(function(aiResult) {
      var dur = Date.now() - start
      logAgent(agent.id, task.id, 'think', promptTemplate.substring(0, 200), aiResult.text.substring(0, 2000), motor, modelo, aiResult.tokens_in, aiResult.tokens_out, 0, dur, true, '')
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
    }).catch(function(e) {
      var dur = Date.now() - start
      logAgent(agent.id, task.id, 'error', promptTemplate.substring(0, 200), '', motor, modelo, 0, 0, 0, dur, false, e.message)
      sbPatchAgent(agent.id, { estado: 'blocked', bubble_text: 'Error AI: ' + e.message.substring(0, 40), bubble_type: 'speech' })
      return { ok: false, error: e.message }
    })
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
        // Execute first pending task
        executeTask(agent, tasks[0])
      })
    })
  }).catch(function(e) { console.error('[TICK] Error:', e.message) })
}

function shouldRunCron(cronStr, now, lastRun) {
  if (!cronStr) return false
  var last = lastRun ? new Date(lastRun) : new Date(0)
  var diffMin = (now - last) / 60000

  // Simple cron parser for common patterns
  if (cronStr === '*/30 * * * *') return diffMin >= 30
  if (cronStr === '0 * * * *') return diffMin >= 60 && now.getMinutes() < 5
  if (cronStr === '0 */2 * * *') return diffMin >= 120 && now.getMinutes() < 5
  if (cronStr.match(/^0 \d+,\d+ \* \* \*/)) {
    var hours = cronStr.split(' ')[1].split(',').map(Number)
    return hours.indexOf(now.getHours()) >= 0 && now.getMinutes() < 5 && diffMin >= 60
  }
  if (cronStr.match(/^0 \d+ \* \* \d$/)) {
    var hour = parseInt(cronStr.split(' ')[1])
    var dow = parseInt(cronStr.split(' ')[4])
    return now.getDay() === dow && now.getHours() === hour && now.getMinutes() < 5 && diffMin >= 1440
  }
  if (cronStr.match(/^0 \d+ \* \* \*/)) {
    var hour = parseInt(cronStr.split(' ')[1])
    return now.getHours() === hour && now.getMinutes() < 5 && diffMin >= 1440
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
