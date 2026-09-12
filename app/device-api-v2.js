'use strict'

// APP-PWA-V2 #517 — actor-bound device/presence API.
// This module is inert until wired by server-f17 in a dedicated integration gate.

function createDeviceApi(deps) {
  deps = deps || {}
  const verifyApp = deps.verifyApp
  const serviceRpc = deps.serviceRpc
  const writeJson = deps.writeJson
  const readRaw = deps.readRaw
  const parseJson = deps.parseJson

  if (![verifyApp, serviceRpc, writeJson, readRaw, parseJson].every(function(x){ return typeof x === 'function' })) {
    throw new Error('DEVICE_API_DEPENDENCIES_REQUIRED')
  }

  async function actor(req, res) {
    const a = await verifyApp(req.headers['x-aos-app-token'], false)
    if (!a || !a.ok) {
      writeJson(res, a && a.status || 403, { ok: false, error: 'DEVICE_APP_SESSION_REQUIRED' })
      return null
    }
    return a
  }

  async function body(req, res, maxBytes) {
    let raw
    try { raw = await readRaw(req, maxBytes || 64 * 1024) }
    catch (e) { writeJson(res, e.status || 400, { ok:false, error:e.message || 'INVALID_BODY' }); return null }
    const parsed = parseJson(raw.toString('utf8'))
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      writeJson(res, 400, { ok:false, error:'INVALID_JSON' }); return null
    }
    return parsed
  }

  async function register(req, res) {
    const a = await actor(req, res); if (!a) return
    const b = await body(req, res, 64 * 1024); if (!b) return
    b.user_id = a.actor_id
    try {
      const out = await serviceRpc('aos_device_upsert_v1', { p_payload:b })
      if (!out || out.ok !== true) return writeJson(res, 400, out || { ok:false, error:'DEVICE_REGISTER_REJECTED' })
      return writeJson(res, 200, out)
    } catch (e) {
      return writeJson(res, 503, { ok:false, error:'DEVICE_REGISTER_UNAVAILABLE' })
    }
  }

  async function list(req, res) {
    const a = await actor(req, res); if (!a) return
    try {
      const out = await serviceRpc('aos_devices_actor_v1', { p_payload:{ actor_id:a.actor_id } })
      if (!out || out.ok !== true) return writeJson(res, 403, out || { ok:false, error:'DEVICE_LIST_REJECTED' })
      return writeJson(res, 200, out)
    } catch (e) {
      return writeJson(res, 503, { ok:false, error:'DEVICE_LIST_UNAVAILABLE' })
    }
  }

  async function presence(req, res) {
    const a = await actor(req, res); if (!a) return
    const b = await body(req, res, 32 * 1024); if (!b) return
    b.user_id = a.actor_id
    try {
      const out = await serviceRpc('aos_app_presence_touch_v1', { p_payload:b })
      if (!out || out.ok !== true) return writeJson(res, 400, out || { ok:false, error:'PRESENCE_REJECTED' })
      return writeJson(res, 200, out)
    } catch (e) {
      return writeJson(res, 503, { ok:false, error:'PRESENCE_UNAVAILABLE' })
    }
  }

  async function mutate(req, res, rpcName) {
    const a = await actor(req, res); if (!a) return
    const b = await body(req, res, 32 * 1024); if (!b) return
    b.actor_id = a.actor_id
    try {
      const out = await serviceRpc(rpcName, { p_payload:b })
      if (!out || out.ok !== true) return writeJson(res, 400, out || { ok:false, error:'DEVICE_MUTATION_REJECTED' })
      return writeJson(res, 200, out)
    } catch (e) {
      return writeJson(res, 503, { ok:false, error:'DEVICE_MUTATION_UNAVAILABLE' })
    }
  }

  async function handle(req, res, url) {
    const p = url.pathname
    if (p === '/api/devices/health' && req.method === 'GET') return writeJson(res, 200, {ok:true,version:'APP-PWA-V2-517',auth:'actor-bound'})
    if (p === '/api/devices' && req.method === 'GET') return list(req,res)
    if (p === '/api/devices/register' && req.method === 'POST') return register(req,res)
    if (p === '/api/devices/presence' && req.method === 'POST') return presence(req,res)
    if (p === '/api/devices/preferences' && req.method === 'POST') return mutate(req,res,'aos_device_preferences_actor_v1')
    if (p === '/api/devices/rename' && req.method === 'POST') return mutate(req,res,'aos_device_rename_actor_v1')
    if (p === '/api/devices/disable' && req.method === 'POST') return mutate(req,res,'aos_device_disable_actor_v1')
    return false
  }

  return { handle, register, list, presence }
}

module.exports = { createDeviceApi }
