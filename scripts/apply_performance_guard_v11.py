from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, got {n}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')
    print('patched:', label)


path = 'app/server.js'

replace_once(
    path,
    """function sbPost(endpoint, body) {
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
}""",
    """function sbPost(endpoint, body, method) {
  const url = new URL(SB_URL + endpoint)
  const httpMethod = String(method || 'POST').toUpperCase() === 'PATCH' ? 'PATCH' : 'POST'
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body)
    const req = https.request({
      hostname: url.hostname, path: url.pathname + url.search,
      method: httpMethod,
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(data) }
    }, (res) => { let d = ''; res.on('data', c => d += c); res.on('end', () => resolve(res.statusCode)) })
    req.on('error', reject)
    req.write(data)
    req.end()
  })
}""",
    'sbPost PATCH + query-string semantics'
)

replace_once(
    path,
    "return sbFetch('/rest/v1/aos_email_flujo_ejecuciones?estado=eq.activo&proximo_envio=lte.' + new Date().toISOString() + '&select=*&limit=20')",
    "return sbFetch('/rest/v1/aos_email_flujo_ejecuciones?estado=eq.activo&flujo_id=not.is.null&proximo_envio=lte.' + new Date().toISOString() + '&select=*&limit=20')",
    'email flow worker excludes invalid null-flow rows'
)

replace_once(
    path,
    """function _procesarPasoFlujo(agent, ej) {
  // Cargar flujo padre para obtener pasos""",
    """function _procesarPasoFlujo(agent, ej) {
  // Defensa adicional: una ejecución activa sin flujo padre es inválida.
  if (!ej || !ej.flujo_id) {
    console.warn('[FLUJOS] Ejecución inválida sin flujo_id; se omite:', ej && ej.id ? ej.id : 'sin-id')
    return Promise.resolve()
  }
  // Cargar flujo padre para obtener pasos""",
    'email flow null guard'
)

replace_once(
    path,
    "    sbFetch('/rest/v1/aos_email_alertas').catch(function(){}) // ensure table exists\n",
    "",
    'remove redundant email-alert table probe'
)

print('Performance Guard v1.1 patch applied.')
