'use strict'

const webpush = require('web-push')

function text(v, max) {
  return String(v == null ? '' : v).replace(/[\u0000-\u001f\u007f]+/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max || 160)
}
function digits(v) { return String(v || '').replace(/\D/g, '').slice(0, 20) }
function bool(v) { return v === true || String(v).toLowerCase() === 'true' }

function createPushService(opts) {
  const serviceRpc = opts && opts.serviceRpc
  const vapidSubject = text(opts && opts.vapidSubject, 220) || 'mailto:notifications@ascenda.local'
  const logger = opts && opts.logger || console
  if (typeof serviceRpc !== 'function') throw new Error('S14_SERVICE_RPC_REQUIRED')

  let vapid = null
  let vapidPromise = null

  async function rpc(name, payload) {
    const out = await serviceRpc(name, { p_payload: payload || {} })
    if (!out || out.ok !== true) throw Object.assign(new Error((out && out.error) || 'S14_RPC_REJECTED'), { status: 502 })
    return out
  }

  async function loadVapid() {
    const current = await rpc('aos_push_vapid_config_v1', {})
    if (current.configured === true && current.public_key && current.private_key) return current
    const generated = webpush.generateVAPIDKeys()
    const stored = await rpc('aos_push_vapid_store_v1', { public_key: generated.publicKey, private_key: generated.privateKey })
    if (!stored || stored.configured !== true || !stored.public_key || !stored.private_key) throw new Error('S14_VAPID_PROVISION_FAILED')
    return stored
  }

  function ensureVapid() {
    if (vapid) return Promise.resolve(vapid)
    if (vapidPromise) return vapidPromise
    vapidPromise = loadVapid().then(function(cfg) {
      webpush.setVapidDetails(vapidSubject, cfg.public_key, cfg.private_key)
      vapid = { publicKey: cfg.public_key, configured: true }
      return vapid
    }).finally(function() { vapidPromise = null })
    return vapidPromise
  }

  async function publicConfig() {
    const cfg = await ensureVapid()
    return { ok: true, version: 'AOS_PUSH_V1', configured: true, public_key: cfg.publicKey }
  }

  async function subscribe(actorId, body, userAgent) {
    const d = body || {}
    const sub = d.subscription || d
    const keys = sub && sub.keys || {}
    const endpoint = text(sub && sub.endpoint, 4096)
    const p256dh = text(keys.p256dh, 512)
    const auth = text(keys.auth, 256)
    if (!endpoint || !p256dh || !auth) throw Object.assign(new Error('INVALID_PUSH_SUBSCRIPTION'), { status: 400 })
    await ensureVapid()
    return rpc('aos_push_subscription_upsert_v1', {
      user_id: actorId,
      endpoint: endpoint,
      p256dh: p256dh,
      auth: auth,
      device_label: text(d.device_label, 160),
      user_agent: text(userAgent, 500)
    })
  }

  async function unsubscribe(actorId, body) {
    const endpoint = text(body && body.endpoint, 4096)
    if (!endpoint) throw Object.assign(new Error('PUSH_ENDPOINT_REQUIRED'), { status: 400 })
    return rpc('aos_push_subscription_disable_v1', { user_id: actorId, endpoint: endpoint })
  }

  function messagePreview(m) {
    const body = text(m && m.message_body, 140)
    if (body) return body
    const type = text(m && m.message_type, 32).toLowerCase()
    if (type === 'image') return '📷 Imagen recibida'
    if (type === 'audio') return '🎤 Audio recibido'
    if (type === 'video') return '🎥 Video recibido'
    if (type === 'document') return '📎 Documento recibido'
    if (type === 'sticker') return 'Sticker recibido'
    return 'Nuevo mensaje recibido'
  }

  function senderLabel(target, message) {
    const name = text(target && target.contact_name || message && message.contact_name, 72)
    if (name) return name
    const phone = digits(target && target.contact_number || message && message.from_number)
    return phone ? ('+' + phone) : 'Contacto WhatsApp'
  }

  function envelope(target, message) {
    const conversationId = text(target && target.conversation_id, 80)
    const providerId = text(message && message.provider_message_id, 256)
    const label = senderLabel(target, message)
    return {
      version: 'AOS_PUSH_V1',
      channel: 'WHATSAPP',
      event_type: 'message.inbound',
      title: 'WhatsApp · ' + label,
      body: messagePreview(message),
      icon: '/icons/channel-whatsapp.svg',
      badge: '/icons/icon-192x192.png',
      tag: 'aos-wa-human-' + conversationId,
      route: '/app.html#admin-whatsapp',
      entity_id: conversationId,
      dedupe_key: 'wa:' + providerId,
      created_at: new Date().toISOString(),
      data: { kind: 'AOS_PUSH', channel: 'WHATSAPP', conversationId: conversationId, view: 'admin-whatsapp' }
    }
  }

  async function complete(dispatchId, status, errorCode, terminal) {
    try {
      await rpc('aos_push_dispatch_complete_v1', {
        dispatch_id: dispatchId,
        status: status,
        error_code: text(errorCode, 160) || null,
        terminal: terminal === true
      })
    } catch (e) {
      logger.error('[S14] delivery ledger update failed', e.message)
    }
  }

  async function deliverOne(target, subscription, payload) {
    const claim = await rpc('aos_push_dispatch_claim_v1', {
      subscription_id: subscription.id,
      recipient_user_id: target.owner_user_id,
      channel: 'WHATSAPP',
      event_type: 'message.inbound',
      entity_id: target.conversation_id,
      dedupe_key: payload.dedupe_key
    })
    if (claim.claimed !== true || !claim.dispatch_id) return { skipped: true }
    const webSubscription = {
      endpoint: subscription.endpoint,
      keys: { p256dh: subscription.p256dh, auth: subscription.auth }
    }
    try {
      await webpush.sendNotification(webSubscription, JSON.stringify(payload), {
        TTL: 120,
        urgency: 'high',
        topic: ('wa-' + String(target.conversation_id || '')).slice(0, 32)
      })
      await complete(claim.dispatch_id, 'DELIVERED', null, false)
      return { delivered: true }
    } catch (e) {
      const code = Number(e && e.statusCode || 0)
      const gone = code === 404 || code === 410
      await complete(claim.dispatch_id, gone ? 'GONE' : 'FAILED', 'WEB_PUSH_' + (code || 'ERROR'), gone)
      return { failed: true, terminal: gone, statusCode: code }
    }
  }

  async function dispatchWhatsAppEnvelope(waEnvelope) {
    const input = waEnvelope || {}
    const messages = Array.isArray(input.messages) ? input.messages : []
    if (!messages.length) return { ok: true, inbound: 0, delivered: 0, skipped: 0, failed: 0 }
    await ensureVapid()
    const totals = { ok: true, inbound: messages.length, delivered: 0, skipped: 0, failed: 0 }
    for (const m of messages) {
      if (!m || String(m.direction || 'INBOUND').toUpperCase() !== 'INBOUND' || !m.provider_message_id) continue
      let target
      try {
        target = await rpc('aos_push_targets_for_wa_v1', {
          contact_number: digits(m.from_number),
          phone_number_id: text(m.phone_number_id, 128),
          provider_message_id: text(m.provider_message_id, 256)
        })
      } catch (e) {
        totals.failed++
        logger.error('[S14] target resolution failed', e.message)
        continue
      }
      if (!target.eligible || !target.owner_user_id || !Array.isArray(target.subscriptions) || !target.subscriptions.length) {
        totals.skipped++
        continue
      }
      const payload = envelope(target, m)
      for (const sub of target.subscriptions) {
        try {
          const r = await deliverOne(target, sub, payload)
          if (r.delivered) totals.delivered++
          else if (r.failed) totals.failed++
          else totals.skipped++
        } catch (e) {
          totals.failed++
          logger.error('[S14] push dispatch failed', e.message)
        }
      }
    }
    return totals
  }

  function status() {
    return { version: 'AOS_PUSH_V1', configured: !!vapid, subject: vapidSubject }
  }

  return { publicConfig, subscribe, unsubscribe, dispatchWhatsAppEnvelope, ensureVapid, status, messagePreview, senderLabel }
}

module.exports = { createPushService }
