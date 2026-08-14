#!/usr/bin/env python3
"""Apply the F16 Email runtime migration deterministically.

This script intentionally fails closed if the expected legacy source shape changes.
It never embeds or prints secret values.
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SERVER = ROOT / "app/server.js"
ADMIN = ROOT / "app/public/admin-email.html"


def must_replace(text: str, old: str, new: str, label: str, count: int = 1) -> str:
    found = text.count(old)
    if found != count:
        raise RuntimeError(f"{label}: expected {count} exact occurrence(s), found {found}")
    return text.replace(old, new, count)


def must_sub(text: str, pattern: str, repl: str, label: str, count: int = 1, flags: int = 0) -> str:
    out, n = re.subn(pattern, repl, text, count=count, flags=flags)
    if n != count:
        raise RuntimeError(f"{label}: expected {count} regex replacement(s), found {n}")
    return out


def patch_server(text: str) -> str:
    if "createEmailGateway" not in text:
        text = must_replace(
            text,
            "const path = require('path')\n",
            "const path = require('path')\nconst { createEmailGateway } = require('./email-gateway')\nconst EMAIL_GATEWAY = createEmailGateway()\n",
            "server gateway import",
        )

    route_anchor = "http.createServer(function(req, res) {\n  var p = req.url.split('?')[0]\n"
    route_block = (
        "http.createServer(function(req, res) {\n"
        "  var p = req.url.split('?')[0]\n"
        "  // F16: all admin Email writes and provider webhooks enter through a server-authoritative boundary.\n"
        "  if (p === '/api/email-gateway') return EMAIL_GATEWAY.handleAdmin(req, res)\n"
        "  if (p === '/api/send-email') return EMAIL_GATEWAY.handleAdmin(req, res)\n"
        "  if (p === '/api/resend-webhook') return EMAIL_GATEWAY.handleWebhook(req, res)\n"
    )
    if "if (p === '/api/email-gateway')" not in text:
        text = must_replace(text, route_anchor, route_block, "server Email gateway routing")

    # Remove the now-unreachable permissive admin send implementation so it cannot regress by route reordering.
    if "// ===== RESEND EMAIL API =====" in text:
        text = must_sub(
            text,
            r"  // ===== RESEND EMAIL API =====\n.*?  // ===== FIN RESEND =====\n",
            "  // ===== F16 EMAIL ADMIN SEND =====\n  // Handled above by EMAIL_GATEWAY with authoritative admin session verification.\n",
            "remove permissive send-email block",
            flags=re.S,
        )

    # Remove the legacy unsigned webhook implementation. Signed raw-body verification is handled above.
    if "// ===== RESEND WEBHOOK — open/click/bounce tracking =====" in text:
        text = must_sub(
            text,
            r"  // ===== RESEND WEBHOOK — open/click/bounce tracking =====\n.*?(?=  // ===== RESEND STATS)",
            "  // ===== F16 RESEND WEBHOOK =====\n  // Handled above by EMAIL_GATEWAY with cryptographic signature + replay protection.\n\n",
            "remove unsigned webhook block",
            flags=re.S,
        )

    # Source-level provider credentials are prohibited. Replace every env||literal Resend fallback generically.
    text, fallback_count = re.subn(
        r"process\.env\.RESEND_API_KEY\s*\|\|\s*(['\"])re_[^'\"]+\1",
        "process.env.RESEND_API_KEY || ''",
        text,
    )
    if fallback_count < 1 and "process.env.RESEND_API_KEY || ''" not in text:
        raise RuntimeError("server Resend fallback: no governed env-only expression found")

    if re.search(r"(['\"])re_[A-Za-z0-9_-]{20,}\1", text):
        raise RuntimeError("server secret scan: source-level provider credential remains")
    if "Access-Control-Allow-Origin', '*'" in text and "/api/send-email" in text:
        # Other historical endpoints can still use CORS, but the removed /api/send-email block may not.
        legacy_section = text[text.find("/api/send-email") : text.find("/api/send-email") + 1800]
        if "Access-Control-Allow-Origin', '*'" in legacy_section:
            raise RuntimeError("server send-email CORS wildcard still reachable")
    return text


def patch_admin(text: str) -> str:
    text = must_sub(
        text,
        r"var SB='https://[^']+';\nvar SK='[^']+';\n",
        "",
        "remove browser Supabase constants",
    )

    old_helpers = (
        "function rpc(fn,params,cb){fetch(SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json'},body:JSON.stringify(params)}).then(function(r){return r.json();}).then(cb).catch(function(e){console.error(fn,e);});}\n"
        "function q(table,query,cb){fetch(SB+'/rest/v1/'+table+'?'+query,{headers:{'apikey':SK,'Authorization':'Bearer '+SK}}).then(function(r){return r.json();}).then(cb);}\n"
    )
    new_helpers = r"""function emSessionToken(){return sessionStorage.getItem('aos_si_token')||sessionStorage.getItem('aos_app_token')||'';}
function emCall(action,payload){
  var token=emSessionToken();
  if(!token)return Promise.reject(new Error('Sesión administrativa requerida'));
  return fetch('/api/email-gateway',{method:'POST',headers:{'Content-Type':'application/json','X-ASCENDA-Session':token},body:JSON.stringify({action:action,payload:payload||{}})}).then(function(r){return r.json().then(function(b){if(!r.ok||!b||b.ok!==true)throw new Error((b&&b.error)||('HTTP '+r.status));return b;});});
}
function rpc(fn,params,cb){emCall('LEGACY_RPC',{name:fn,params:params||{}}).then(function(r){cb(r.data);}).catch(function(e){console.error(fn,e);showToast('Error de sesión/email',e.message,true);});}
function q(table,query,cb){emCall('LEGACY_READ',{table:table,query:query||''}).then(function(r){cb(r.data||[]);}).catch(function(e){console.error(table,e);showToast('Error de sesión/email',e.message,true);cb([]);});}
function emPatch(table,id,changes,cb){emCall('LEGACY_PATCH',{table:table,id:id,changes:changes||{}}).then(function(r){if(cb)cb(null,r);}).catch(function(e){if(cb)cb(e);else showToast('Error al guardar',e.message,true);});}
"""
    text = must_replace(text, old_helpers, new_helpers, "replace browser Supabase helpers")

    text = must_sub(
        text,
        r"function toggleFlujo\(id,activo\)\{\n.*?\n\}\n\nvar _tplMode",
        "function toggleFlujo(id,activo){\n  emPatch('aos_email_flujos',id,{activo:activo,updated_at:new Date().toISOString()},function(err){\n    if(err){showToast('Error al actualizar flujo',err.message,true);return;}\n    showToast('Flujo '+(activo?'Activado':'Desactivado'),'');\n    el('m-flujo').classList.remove('open');loadFlujos();loadDashboard();\n  });\n}\n\nvar _tplMode",
        "migrate flow PATCH",
        flags=re.S,
    )

    text = must_sub(
        text,
        r"function saveWaTpl\(id\)\{\n.*?\n\}\nfunction filtrarTpl",
        "function saveWaTpl(id){\n  var data={nombre:el('wa-nombre').value,cuerpo:el('wa-body').value,sede:el('wa-sede').value||null,updated_at:new Date().toISOString()};\n  emPatch('aos_plantillas_mensajes',id,data,function(err){if(err){showToast('Error',err.message,true);return;}showToast('Plantilla guardada',data.nombre);loadPlantillas();});\n}\nfunction filtrarTpl",
        "migrate WhatsApp template PATCH",
        flags=re.S,
    )

    text = must_sub(
        text,
        r"function savePlantilla\(id\)\{\n.*?\n\}\n\nfunction loadEnviados",
        "function savePlantilla(id){\n  var body=_htmlMode?el('tpl-html-raw').value:el('tpl-editor').innerHTML;\n  body=body.replace(/<span[^>]*>\\{\\{(\\w+)\\}\\}<\\/span>/g,'{{$1}}');\n  var data={nombre:el('tpl-nombre').value,asunto:el('tpl-asunto').value,html_body:body,updated_at:new Date().toISOString()};\n  emPatch('aos_email_plantillas',id,data,function(err){if(err){showToast('Error al guardar',err.message,true);return;}showToast('Plantilla guardada',''+data.nombre);loadPlantillas();});\n}\n\nfunction loadEnviados",
        "migrate Email template PATCH",
        flags=re.S,
    )

    text = must_sub(
        text,
        r"function doSendEmail\(email,nombre,numero\)\{\n.*?\n\}\n\nfunction loadDashboard",
        r"""var _sendClientRequestId='';
function doSendEmail(email,nombre,numero){
  var tplId=el('send-tpl').value;var asunto=el('send-asunto').value;
  if(!asunto){showToast('Error','Escribe un asunto',true);return;}
  if(!_sendClientRequestId)_sendClientRequestId=(window.crypto&&crypto.randomUUID)?crypto.randomUUID():('email-'+Date.now()+'-'+Math.random().toString(36).slice(2));
  q('aos_email_plantillas','select=html_body,variables&id=eq.'+tplId,function(rows){
    if(!rows||!rows[0])return;
    var htmlBody=rows[0].html_body.replace(/\{\{nombre\}\}/g,nombre).replace(/\{\{tratamiento\}\}/g,'').replace(/\{\{fecha_cita\}\}/g,'').replace(/\{\{hora_cita\}\}/g,'').replace(/\{\{sede\}\}/g,'').replace(/\{\{monto\}\}/g,'').replace(/\{\{fecha\}\}/g,'');
    emCall('LEGACY_SEND',{
      to:email,subject:asunto.replace(/\{\{nombre\}\}/g,nombre),html:htmlBody,
      nombre:nombre,numero:numero,plantilla_id:tplId,variables:{nombre:nombre},client_request_id:_sendClientRequestId
    }).then(function(res){
      showToast('Email Enviado','Correo enviado exitosamente a '+email);
      _sendClientRequestId='';
      el('m-send').classList.remove('open');
      if(numero)verContacto(numero);
    }).catch(function(e){showToast('Error al enviar',e.message,true);});
  });
}

function loadDashboard""",
        "migrate manual Email send",
        flags=re.S,
    )

    if "fetch(SB+" in text or "'apikey':SK" in text or "Bearer '+SK" in text:
        raise RuntimeError("admin-email direct Supabase access remains")
    if "fetch('/api/send-email'" in text:
        raise RuntimeError("admin-email direct legacy send remains")
    return text


def main() -> int:
    before_server = SERVER.read_text(encoding="utf-8")
    before_admin = ADMIN.read_text(encoding="utf-8")
    after_server = patch_server(before_server)
    after_admin = patch_admin(before_admin)

    SERVER.write_text(after_server, encoding="utf-8")
    ADMIN.write_text(after_admin, encoding="utf-8")

    changed = []
    if before_server != after_server:
        changed.append("app/server.js")
    if before_admin != after_admin:
        changed.append("app/public/admin-email.html")
    if changed != ["app/server.js", "app/public/admin-email.html"]:
        raise RuntimeError(f"unexpected changed-file set: {changed}")

    print("CIA_PHASE16_RUNTIME_PATCH=PASS")
    print("CHANGED_FILES=" + ",".join(changed))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"CIA_PHASE16_RUNTIME_PATCH=FAIL:{type(exc).__name__}:{exc}", file=sys.stderr)
        raise
