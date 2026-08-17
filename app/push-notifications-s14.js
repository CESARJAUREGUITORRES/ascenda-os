'use strict'

const webpush = require('web-push')

function text(v, max) {
  return String(v == null ? '' : v).replace(/[\u0000-\u001f\u007f]+/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max || 160)
}
function digits(v) { return String(v || '').replace(/\D/g, '').slice(0, 20) }
function bool(v) { return v === true || String(v).toLowerCase() === 'true' }
function topic(v) { return text(v, 32).replace(/[^A-Za-z0-9_-]/g, '-').slice(0, 32) || 'ascenda' }

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

  function genericEnvelope(n) {
    const channel = text(n && n.channel, 32).toUpperCase() || 'SYSTEM'
    const entityId = text(n && n.entity_id, 180)
    const notificationId = text(n && n.id, 80)
    return {
      version: 'AOS_PUSH_V1',
      channel: channel,
      event_type: text(n && n.event_type, 80) || 'notification',
      title: text(n && n.title, 120) || 'ASCENDA',
      body: text(n && n.body, 320),
      icon: text(n && n.icon, 256) || '/icons/icon-192x192.png',
      badge: '/icons/icon-192x192.png',
      tag: 'aos-' + channel.toLowerCase() + '-' + (entityId || notificationId),
      route: text(n && n.route, 256) || '/app.html',
      entity_id: entityId || notificationId,
      dedupe_key: text(n && n.dedupe_key, 300) || ('notif:' + notificationId),
      created_at: n && n.created_at || new Date().toISOString(),
      data: { kind: 'AOS_PUSH', channel: channel, notificationId: notificationId, eventType: text(n && n.event_type, 80) }
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

  async function sendToSubscription(input) {
    const subscription = input.subscription
    const payload = input.payload
    const recipientUserId = text(input.recipientUserId, 80)
    const claim = await rpc('aos_push_dispatch_claim_v1', {
      subscription_id: subscription.id,
      recipient_user_id: recipientUserId,
      channel: input.channel,
      event_type: input.eventType,
      entity_id: input.entityId,
      dedupe_key: payload.dedupe_key
    })
    if (claim.claimed !== true || !claim.dispatch_id) return { skipped: true }
    const webSubscription = {
      endpoint: subscription.endpoint,
      keys: { p256dh: subscription.p256dh, auth: subscription.auth }
    }
    try {
      await webpush.sendNotification(webSubscription, JSON.stringify(payload), {
        TTL: Number(input.ttl || 300),
        urgency: input.urgency || 'normal',
        topic: topic(input.topic || (input.channel + '-' + input.entityId))
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

  async function deliverOne(target, subscription, payload) {
    return sendToSubscription({
      subscription: subscription,
      payload: payload,
      recipientUserId: target.owner_user_id,
      channel: 'WHATSAPP',
      eventType: 'message.inbound',
      entityId: target.conversation_id,
      ttl: 120,
      urgency: 'high',
      topic: 'wa-' + String(target.conversation_id || '')
    })
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

  async function finishNotification(notificationId, status, errorCode) {
    try {
      return await rpc('aos_notification_push_complete_v1', {
        notification_id: notificationId,
        status: status,
        error_code: text(errorCode, 160) || null
      })
    } catch (e) {
      logger.error('[S15] notification completion failed', e.message)
      return null
    }
  }

  async function dispatchPendingNotifications(limit) {
    await ensureVapid()
    const batch = await rpc('aos_notification_push_claim_v1', { limit: Math.max(1, Math.min(50, Number(limit || 20))) })
    const rows = Array.isArray(batch.rows) ? batch.rows : []
    const totals = { ok: true, claimed: rows.length, notifications: 0, delivered: 0, skipped: 0, failed: 0, partial: 0 }
    for (const n of rows) {
      const subs = Array.isArray(n.subscriptions) ? n.subscriptions : []
      if (!subs.length) {
        totals.skipped++
        await finishNotification(n.id, 'SKIPPED', 'NO_ACTIVE_PUSH_SUBSCRIPTION')
        continue
      }
      const payload = genericEnvelope(n)
      let delivered = 0, failed = 0, skipped = 0
      for (const sub of subs) {
        const recipient = text(sub && sub.user_id || n.recipient_user_id, 80)
        if (!recipient) { skipped++; continue }
        try {
          const pri = text(n.priority, 24).toUpperCase()
          const r = await sendToSubscription({
            subscription: sub,
            payload: payload,
            recipientUserId: recipient,
            channel: text(n.channel, 32).toUpperCase() || 'SYSTEM',
            eventType: text(n.event_type, 80) || 'notification',
            entityId: text(n.entity_id, 180) || text(n.id, 80),
            ttl: pri === 'URGENTE' || pri === 'ALTA' ? 600 : 300,
            urgency: pri === 'URGENTE' || pri === 'ALTA' ? 'high' : 'normal',
            topic: (text(n.channel, 24) || 'system') + '-' + (text(n.entity_id, 60) || text(n.id, 60))
          })
          if (r.delivered) delivered++
          else if (r.failed) failed++
          else skipped++
        } catch (e) {
          failed++
          logger.error('[S15] generic push dispatch failed', e.message)
        }
      }
      totals.notifications++
      totals.delivered += delivered
      totals.failed += failed
      totals.skipped += skipped
      if (delivered > 0 && failed === 0) await finishNotification(n.id, 'DELIVERED', null)
      else if (delivered > 0) { totals.partial++; await finishNotification(n.id, 'PARTIAL', 'PARTIAL_DELIVERY') }
      else if (failed > 0) await finishNotification(n.id, 'FAILED', 'WEB_PUSH_DELIVERY_FAILED')
      else await finishNotification(n.id, 'SKIPPED', 'NO_DELIVERY_TARGET')
    }
    return totals
  }

  function status() {
    return { version: 'AOS_PUSH_V1', configured: !!vapid, subject: vapidSubject }
  }

  return {
    publicConfig, subscribe, unsubscribe, dispatchWhatsAppEnvelope, dispatchPendingNotifications,
    ensureVapid, status, messagePreview, senderLabel, genericEnvelope
  }
}

module.exports = { createPushService }
