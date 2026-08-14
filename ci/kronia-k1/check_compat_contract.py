from pathlib import Path

failures = []

def txt(path):
    return Path(path).read_text(encoding='utf-8')

def require(body, needle, label):
    if needle not in body:
        failures.append('MISSING: ' + label)

def forbid(body, needle, label):
    if needle in body:
        failures.append('FORBIDDEN: ' + label)

login = txt('app/public/login.html')
core = txt('app/public/kronia-core.js')
app = txt('app/public/app.html')
brain = txt('app/public/cerebro.html')
sales = txt('app/public/admin-sales.html')
config = txt('app/public/admin-config.html')
ext_popup = txt('chrome-extension/popup.js')
ext_html = txt('chrome-extension/popup.html')
ext_core = txt('chrome-extension/kronia-core.js')
server = txt('app/server.js')

# Web login -> opaque session handoff.
require(login, '/api/auth/login', 'web login uses server auth')
require(login, '/api/auth/verify-2fa', 'web 2FA uses server auth')
require(login, "sessionStorage.setItem('aos_kronia_token'", 'web login stores KronIA bearer token')
forbid(login, '/rest/v1/rpc/aos_login_v2', 'browser calls raw login primitive')
forbid(login, '/rest/v1/rpc/aos_verificar_2fa', 'browser calls raw 2FA primitive')
forbid(login, 'res.code', 'browser sees generated 2FA code')

# Shared core -> bearer only.
require(core, "s.getItem('aos_kronia_token')", 'shared core reads canonical bearer')
require(core, "h['Authorization'] = 'Bearer ' + state.token", 'shared core sends bearer')
forbid(core, "payload.rol = state.user.rol", 'shared core sends role authority')
forbid(core, "X-AOS-User", 'shared core uses legacy identity header')

# Main embedded chat is a separate consumer and must share the same boundary.
require(app, "sessionStorage.getItem('aos_kronia_token')", 'main chat reads canonical bearer')
require(app, "'Authorization':'Bearer '+kTok", 'main text chat sends bearer')
require(app, "'Authorization':'Bearer '+(sessionStorage.getItem('aos_kronia_token')||'')", 'main Whisper sends bearer')
forbid(app, "'X-AOS-User'", 'main Whisper uses legacy identity header')
forbid(app, "var payload={pregunta:q,usuario:usuario,rol:rol,sede:sede", 'main chat sends forged identity claims')

# Brain must use the shared core, not a parallel raw transport.
require(brain, 'KroniaCore.create', 'Brain uses shared KroniaCore')
forbid(brain, "fetch('/api/kronia/chat'", 'Brain bypasses shared core chat')
forbid(brain, "X-AOS-User", 'Brain uses legacy identity header')

# Chrome extension: same core contract, password transient only.
require(ext_html, 'id="loginPass"', 'Chrome extension has password input for authoritative login')
require(ext_popup, 'CORE.loginRequest(u,', 'Chrome extension passes password to server login')
require(ext_core, 'pendingLoginPassword', 'extension core holds password only transiently')
forbid(ext_core, "payload.rol = state.user.rol", 'extension sends role authority')

# Native Sales editor -> same token boundary as KronIA.
require(sales, "sessionStorage.getItem('aos_kronia_token')", 'Sales editor reads secure session')
require(sales, "p_tool:'aos_editar_venta'", 'Sales editor routes through protected tool gateway')
forbid(sales, "/rest/v1/rpc/aos_editar_venta", 'Sales editor executes raw mutation RPC')

# Integration admin UI: metadata read, narrow admin write gateway.
require(config, 'aos_kronia_admin_desactivar_integracion', 'Integration UI uses narrow ADMIN gateway')
forbid(config, 'aos_integraciones?select=*', 'Integration UI selects secret columns')
forbid(config, "sbPatch('/rest/v1/aos_integraciones", 'Integration UI writes integration table directly')

# Whisper API remains backward compatible while normalizing new clients.
require(server, "{ok:true,text:j.text,texto:j.text}", 'Whisper returns both text and legacy texto')

if failures:
    print('KRONIA_K1_COMPATIBILITY_CONTRACT=FAIL')
    for f in failures:
        print(' -', f)
    raise SystemExit(1)

print('KRONIA_K1_COMPATIBILITY_CONTRACT=PASS')
