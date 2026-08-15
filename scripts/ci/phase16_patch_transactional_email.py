#!/usr/bin/env python3
"""F16 deterministic patch for transactional Email auth and legacy marketing closure."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SERVER = ROOT / "app/server.js"
CONSUMERS = [
    ROOT / "app/public/attendance.html",
    ROOT / "app/public/agenda.js",
    ROOT / "app/public/calls.js",
    ROOT / "app/public/citas.html",
    ROOT / "app/public/caja.html",
    # CURRENT main serves the live Call Center directly from calls.html.
    ROOT / "app/public/calls.html",
]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise RuntimeError(f"{label}: expected 1 occurrence, found {n}")
    return text.replace(old, new, 1)


def sub_once(text: str, pattern: str, repl: str, label: str, flags: int = 0) -> str:
    out, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        raise RuntimeError(f"{label}: expected 1 replacement, found {n}")
    return out


def patch_server(text: str) -> str:
    # Retire legacy unauthenticated 2FA sender. Auth V3 delivers 2FA inside aos_login_v3.
    if "LEGACY_2FA_RETIRED" not in text:
        text = sub_once(
            text,
            r"  // ===== 2FA CODE EMAIL =====\n.*?  // ===== FIN 2FA =====\n",
            """  // ===== F16 LEGACY 2FA RETIRED =====
  // Current Auth V3 sends 2FA inside aos_login_v3. This legacy public provider path is closed.
  if (p === '/api/send-2fa') {
    res.writeHead(410, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' })
    res.end(JSON.stringify({ ok:false, error:'LEGACY_2FA_RETIRED' })); return
  }
  // ===== FIN F16 LEGACY 2FA =====
""",
            "retire legacy send-2fa",
            flags=re.S,
        )

    # Expand the explicit transactional allowlist; marketing classes must use governed activation.
    old_list = "var EMAILS_TRANSACCIONALES = ['confirmacion_cita', 'recibo_venta', 'recordatorio_hoy', 'recordatorio_manana', 'bienvenida', 'confirmacion_pago', 'cotizacion']"
    new_list = "var EMAILS_TRANSACCIONALES = ['confirmacion_cita','recibo_venta','recordatorio_hoy','recordatorio_manana','recordatorio','bienvenida','confirmacion_pago','cotizacion','catalogo','comprobante','agradecimiento','agradecimiento_visita','no_asistencia','reprogramacion','saldo_pendiente','seguimiento']"
    if old_list in text:
        text = replace_once(text, old_list, new_list, "expand transactional allowlist")
    elif new_list not in text:
        raise RuntimeError("transactional allowlist shape changed")

    send_anchor = """function sendAgentEmail(to, subject, html, tipo, destinatario_id) {
  return new Promise(function(resolve) {
    // Anti-duplicado: verificar si ya se envió hoy
"""
    send_hardened = """function sendAgentEmail(to, subject, html, tipo, destinatario_id) {
  return new Promise(function(resolve) {
    // F16: all marketing/reactivation/cross-sell agent sends require governed Audience activation + consent.
    if (EMAILS_TRANSACCIONALES.indexOf(String(tipo || '')) === -1) {
      resolve({ skip:true, reason:'F16_MARKETING_GOVERNED_ACTIVATION_REQUIRED', governed_activation_required:true }); return
    }
    // Anti-duplicado: verificar si ya se envió hoy
"""
    if "F16_MARKETING_GOVERNED_ACTIVATION_REQUIRED" not in text:
        text = replace_once(text, send_anchor, send_hardened, "block ungoverned agent marketing")

    # Require current Auth V3 app session before existing transactional send-template implementation.
    start = """  if (p === '/api/send-template' && req.method === 'POST') {
    res.setHeader('Access-Control-Allow-Origin', '*')
    var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
"""
    hardened_start = """  if (p === '/api/send-template' && req.method === 'POST') {
    var templateToken = String(req.headers['x-ascenda-session'] || '')
    EMAIL_GATEWAY.verifyApp(templateToken).then(function(templateAuth) {
      if (!templateAuth || templateAuth.ok !== true) {
        res.writeHead(401, { 'Content-Type':'application/json', 'Cache-Control':'no-store' })
        res.end(JSON.stringify({ok:false,error:'UNAUTHORIZED'})); return
      }
      var body = ''; req.on('data', function(c) { body += c }); req.on('end', function() {
"""
    if "var templateToken = String(req.headers['x-ascenda-session'] || '')" not in text:
        text = replace_once(text, start, hardened_start, "secure send-template start")

    type_anchor = "        var html = '', subject = '', tipo = d.template\n"
    type_policy = """        var html = '', subject = '', tipo = d.template
        // F16: template endpoint is transactional only. Marketing must use governed activation/consent.
        if (EMAILS_TRANSACCIONALES.indexOf(String(tipo || '')) === -1) {
          res.writeHead(403, { 'Content-Type':'application/json', 'Cache-Control':'no-store' })
          res.end(JSON.stringify({ok:false,error:'GOVERNED_ACTIVATION_REQUIRED',template:String(tipo||'')})); return
        }
"""
    if "template endpoint is transactional only" not in text:
        text = replace_once(text, type_anchor, type_policy, "send-template marketing policy")

    end = """      } catch(e) { res.writeHead(400); res.end('{\"error\":\"Invalid JSON\"}') }
    }); return
  }
  if (p === '/api/send-template' && req.method === 'OPTIONS') {
    res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'Content-Type' })
    res.end(); return
  }
  // ===== FIN TEMPLATE EMAILS =====
"""
    hardened_end = """      } catch(e) { res.writeHead(400); res.end('{\"error\":\"Invalid JSON\"}') }
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
"""
    if "send-template' && req.method === 'OPTIONS') {\n    res.writeHead(405" not in text:
        text = replace_once(text, end, hardened_end, "secure send-template end")

    if re.search(r"if \(p === '/api/send-template'.{0,250}Access-Control-Allow-Origin.{0,80}\*", text, flags=re.S):
        raise RuntimeError("send-template wildcard CORS remains")
    if "LEGACY_2FA_RETIRED" not in text or "F16_MARKETING_GOVERNED_ACTIVATION_REQUIRED" not in text:
        raise RuntimeError("transactional/2FA Email controls missing")
    return text


def patch_consumer(path: pathlib.Path) -> bool:
    text = path.read_text(encoding="utf-8")
    before = text
    pos = 0
    changes = 0
    while True:
        idx = text.find('/api/send-template', pos)
        if idx < 0:
            break
        window_end = min(len(text), idx + 700)
        window = text[idx:window_end]
        if "X-ASCENDA-Session" in window:
            pos = idx + 18
            continue
        candidates = [
            "headers:{'Content-Type':'application/json'}",
            'headers:{"Content-Type":"application/json"}',
            "headers: { 'Content-Type': 'application/json' }",
            'headers: { "Content-Type": "application/json" }',
        ]
        found = None
        for c in candidates:
            rel = window.find(c)
            if rel >= 0:
                found = (rel, c)
                break
        if not found:
            raise RuntimeError(f"{path.name}: send-template caller lacks expected JSON headers near offset {idx}")
        rel, old = found
        absolute = idx + rel
        quote = "'" if "'Content-Type'" in old else '"'
        new = "headers:{%sContent-Type%s:%sapplication/json%s,%sX-ASCENDA-Session%s:(sessionStorage.getItem('aos_app_token')||'')}" % (quote,quote,quote,quote,quote,quote)
        text = text[:absolute] + new + text[absolute + len(old):]
        changes += 1
        pos = absolute + len(new)
    if changes < 1:
        raise RuntimeError(f"{path.name}: no send-template caller patched")
    path.write_text(text, encoding="utf-8")
    return text != before


def main() -> int:
    server = SERVER.read_text(encoding="utf-8")
    patched = patch_server(server)
    SERVER.write_text(patched, encoding="utf-8")

    changed = ["app/server.js"]
    for path in CONSUMERS:
        if patch_consumer(path):
            changed.append(str(path.relative_to(ROOT)))

    expected = sorted(["app/server.js"] + [str(p.relative_to(ROOT)) for p in CONSUMERS])
    if sorted(changed) != expected:
        raise RuntimeError(f"unexpected transactional Email patch scope: {changed}")
    print("CIA_PHASE16_TRANSACTIONAL_EMAIL_PATCH=PASS")
    print("TRANSACTIONAL_CALLERS_AUTH_HEADER=6")
    print("LEGACY_2FA_PUBLIC_SEND=RETIRED")
    print("UNGOVERNED_MARKETING_AGENT_SEND=BLOCKED")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"CIA_PHASE16_TRANSACTIONAL_EMAIL_PATCH=FAIL:{type(exc).__name__}:{exc}", file=sys.stderr)
        raise
