#!/usr/bin/env python3
"""Patch F16 Email gateway with Auth V3 app-session verification and fail-closed legacy marketing policy."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
GATEWAY = ROOT / "app/email-gateway.js"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise RuntimeError(f"{label}: expected 1 occurrence, found {n}")
    return text.replace(old, new, 1)


def main() -> int:
    text = GATEWAY.read_text(encoding="utf-8")
    before = text

    admin_block = """  async function verifyAdmin(token) {
    if (!serviceKey) return { ok: false, status: 503, error: 'SERVICE_ROLE_NOT_CONFIGURED' }
    if (!token || String(token).length < 32) return { ok: false, status: 401, error: 'UNAUTHORIZED' }
    var result = await rpc('aos_cia_verify_admin_session_v1', { p_token: String(token) })
    var body = result.body
    if (result.status >= 300 || !body || body.ok !== true || !body.user_id) return { ok: false, status: 401, error: 'UNAUTHORIZED' }
    return { ok: true, user_id: body.user_id, usuario: body.usuario || '' }
  }

"""
    if "async function verifyApp(token)" not in text:
        app_block = admin_block + """  async function verifyApp(token) {
    if (!serviceKey) return { ok: false, status: 503, error: 'SERVICE_ROLE_NOT_CONFIGURED' }
    if (!token || String(token).length < 32) return { ok: false, status: 401, error: 'UNAUTHORIZED' }
    var result = await rpc('aos_cia_verify_app_session_v1', { p_token: String(token) })
    var body = result.body
    if (result.status >= 300 || !body || body.ok !== true || !body.user_id) return { ok: false, status: 401, error: 'UNAUTHORIZED' }
    return {
      ok: true, user_id: body.user_id, nombre: body.nombre || '', rol: body.rol || '',
      assurance_level: body.assurance_level || '', expires_at: body.expires_at || null
    }
  }

"""
        text = replace_once(text, admin_block, app_block, "insert app-session verifier")

    legacy_anchor = """    if (!validEmail(to) || !subject || subject.length > 998 || !html || html.length > 500000 || clientRequestId.length < 8) {
      return { ok: false, status: 400, error: 'INVALID_SEND_INTENT' }
    }
    var idempotencyKey = 'f16-legacy-' + sha256([actor.user_id,to,subject,payload.plantilla_id || '',clientRequestId].join('|'))
"""
    if "GOVERNED_ACTIVATION_REQUIRED" not in text:
        legacy_policy = """    if (!validEmail(to) || !subject || subject.length > 998 || !html || html.length > 500000 || clientRequestId.length < 8) {
      return { ok: false, status: 400, error: 'INVALID_SEND_INTENT' }
    }
    if (!payload.plantilla_id) return { ok: false, status: 400, error: 'TEMPLATE_REQUIRED' }
    var templateMeta = await supabase('/rest/v1/aos_email_plantillas?select=id,tipo,activo&id=eq.' + encodeURIComponent(String(payload.plantilla_id)) + '&limit=1', 'GET')
    var templateRow = templateMeta.status < 300 && Array.isArray(templateMeta.body) ? templateMeta.body[0] : null
    if (!templateRow || templateRow.activo === false) return { ok: false, status: 400, error: 'TEMPLATE_NOT_ACTIVE' }
    var transactionalTypes = new Set([
      'agradecimiento','agradecimiento_visita','bienvenida','catalogo','comprobante','confirmacion_cita',
      'confirmacion_pago','no_asistencia','recibo_venta','recordatorio','recordatorio_hoy','reprogramacion',
      'saldo_pendiente','seguimiento'
    ])
    var templateType = String(templateRow.tipo || '').toLowerCase().trim()
    if (!transactionalTypes.has(templateType)) {
      return { ok: false, status: 403, error: 'GOVERNED_ACTIVATION_REQUIRED', template_type: templateType }
    }
    var idempotencyKey = 'f16-legacy-' + sha256([actor.user_id,to,subject,payload.plantilla_id || '',clientRequestId].join('|'))
"""
        text = replace_once(text, legacy_anchor, legacy_policy, "insert legacy marketing policy")

    return_anchor = """    handleWebhook: handleWebhook,
    verifyAdmin: verifyAdmin,
    dispatchRequest: dispatchRequest,
    configured: configured
"""
    if "verifyApp: verifyApp" not in text:
        return_block = """    handleWebhook: handleWebhook,
    verifyAdmin: verifyAdmin,
    verifyApp: verifyApp,
    dispatchRequest: dispatchRequest,
    configured: configured
"""
        text = replace_once(text, return_anchor, return_block, "export app verifier")

    if text == before:
        raise RuntimeError("no gateway policy changes applied")
    if "aos_cia_verify_app_session_v1" not in text or "GOVERNED_ACTIVATION_REQUIRED" not in text:
        raise RuntimeError("required F16 gateway controls absent")

    GATEWAY.write_text(text, encoding="utf-8")
    print("CIA_PHASE16_GATEWAY_POLICY_PATCH=PASS")
    print("LEGACY_MARKETING_FAIL_CLOSED=PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"CIA_PHASE16_GATEWAY_POLICY_PATCH=FAIL:{type(exc).__name__}:{exc}", file=sys.stderr)
        raise
