from pathlib import Path

ROOT=Path('.')

# Chrome content script must load the same K1 Auth V3 adapter as the popup.
p=ROOT/'chrome-extension/manifest.json'
s=p.read_text(encoding='utf-8')
old='"js": ["kronia-core.js", "content-script.js"]'
new='"js": ["kronia-core.js", "k1-extension-auth.js", "content-script.js"]'
if old in s:
    s=s.replace(old,new,1)
if new not in s:
    raise SystemExit('content script K1 auth adapter missing from manifest')
p.write_text(s,encoding='utf-8')

# Floating login requires password + optional 2FA, matching popup/Auth V3.
p=ROOT/'chrome-extension/content-script.js'
s=p.read_text(encoding='utf-8')
old="""  var loginUsuario = el('input', { type: 'text', placeholder: 'Tu usuario', autocomplete: 'username' });
  var btnPedirCodigo = el('button', { text: 'Enviar código a mi email' });
  var step1 = el('div', { class: 'kronia-login-step active' }, [
    el('label', { text: 'Usuario' }),
    loginUsuario,
    btnPedirCodigo
  ]);"""
new="""  var loginUsuario = el('input', { type: 'text', placeholder: 'Tu usuario', autocomplete: 'username' });
  var loginPassword = el('input', { type: 'password', placeholder: 'Tu contraseña', autocomplete: 'current-password' });
  var btnPedirCodigo = el('button', { text: 'Continuar' });
  var step1 = el('div', { class: 'kronia-login-step active' }, [
    el('label', { text: 'Usuario' }),
    loginUsuario,
    el('label', { text: 'Contraseña' }),
    loginPassword,
    btnPedirCodigo
  ]);"""
if old in s:
    s=s.replace(old,new,1)
if "var loginPassword = el('input'" not in s:
    raise SystemExit('floating password input missing')

old="""  btnPedirCodigo.addEventListener('click', function () {
    var u = loginUsuario.value.trim();
    if (!u) { loginErr.textContent = 'Ingresa tu usuario'; return; }
    loginErr.textContent = '';
    btnPedirCodigo.disabled = true;
    btnPedirCodigo.textContent = 'Enviando...';
    state.loginUsuario = u;
    core.loginRequest(u).then(function (r) {
      btnPedirCodigo.disabled = false;
      btnPedirCodigo.textContent = 'Enviar código a mi email';
      if (r && r.ok) {
        document.querySelector('.kronia-codigo-ok').textContent =
          '✓ Código enviado a ' + (r.email_oculto || 'tu email');
        step1.classList.remove('active');
        step2.classList.add('active');
        loginCodigo.focus();
      } else {
        loginErr.textContent = (r && r.error) || 'No se pudo enviar el código';
      }
    }).catch(function (e) {
      btnPedirCodigo.disabled = false;
      btnPedirCodigo.textContent = 'Enviar código a mi email';
      loginErr.textContent = 'Error de conexión';
    });
  });"""
new="""  btnPedirCodigo.addEventListener('click', function () {
    var u = loginUsuario.value.trim(), pw = loginPassword.value;
    if (!u || !pw) { loginErr.textContent = 'Ingresa usuario y contraseña'; return; }
    loginErr.textContent = '';
    btnPedirCodigo.disabled = true;
    btnPedirCodigo.textContent = 'Verificando...';
    state.loginUsuario = u;
    core.loginRequest(u, pw).then(function (r) {
      loginPassword.value = '';
      btnPedirCodigo.disabled = false;
      btnPedirCodigo.textContent = 'Continuar';
      if (r && r.ok && r.token) {
        state.authenticated = true;
        state.user = core.getUser();
        core.persist(chrome.storage.local);
        setStatus('· ' + ((state.user&&state.user.usuario)||u), '#fff');
        showLogin(false);
        welcomeMessage();
        return;
      }
      if (r && r.ok && r.require_2fa) {
        document.querySelector('.kronia-codigo-ok').textContent =
          '✓ Código enviado a ' + (r.email_masked || r.email_oculto || 'tu email');
        step1.classList.remove('active');
        step2.classList.add('active');
        loginCodigo.focus();
      } else {
        loginErr.textContent = (r && r.error) || 'No se pudo iniciar sesión';
      }
    }).catch(function () {
      loginPassword.value = '';
      btnPedirCodigo.disabled = false;
      btnPedirCodigo.textContent = 'Continuar';
      loginErr.textContent = 'Error de conexión';
    });
  });"""
if old in s:
    s=s.replace(old,new,1)
if 'core.loginRequest(u, pw)' not in s:
    raise SystemExit('floating Auth V3 password request missing')

# Clear password on login-reset/back and support keyboard flow.
s=s.replace("      loginUsuario.value = '';\n      loginCodigo.value = '';", "      loginUsuario.value = '';\n      if (loginPassword) loginPassword.value = '';\n      loginCodigo.value = '';")
s=s.replace("    loginErr.textContent = '';\n    loginUsuario.focus();\n  });", "    loginErr.textContent = '';\n    loginPassword.value = '';\n    loginUsuario.focus();\n  });",1)
old_key="""  loginUsuario.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); btnPedirCodigo.click(); }
  });"""
new_key="""  loginUsuario.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); loginPassword.focus(); }
  });
  loginPassword.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); btnPedirCodigo.click(); }
  });"""
if old_key in s:
    s=s.replace(old_key,new_key,1)
if "loginPassword.addEventListener('keydown'" not in s:
    raise SystemExit('floating password keyboard flow missing')
p.write_text(s,encoding='utf-8')

# Persist only session authority/user metadata, not conversational business content.
p=ROOT/'chrome-extension/kronia-core.js'
s=p.read_text(encoding='utf-8')
old="""        var data = {
          token: state.token,
          user: state.user,
          historial: state.historial
        };"""
new="""        var data = {
          token: state.token,
          user: state.user
        };"""
if old in s:
    s=s.replace(old,new,1)
s=s.replace("            if (Array.isArray(data.historial)) state.historial = data.historial;\n",'')
if 'historial: state.historial' in s or 'data.historial' in s:
    raise SystemExit('persistent Chrome conversation history survived')
p.write_text(s,encoding='utf-8')

# Permanent runtime assertions.
p=ROOT/'ci/kronia-k1-phase2/runtime_contract.py'
s=p.read_text(encoding='utf-8')
anchor="apphtml=(app/'public/app.html').read_text(); brain=(app/'public/cerebro.html').read_text(); team=(app/'public/admin-team.html').read_text(); login=(app/'public/login.html').read_text(); popup=(root/'chrome-extension/popup.js').read_text(); extauth=(root/'chrome-extension/k1-extension-auth.js').read_text()\n"
replace="apphtml=(app/'public/app.html').read_text(); brain=(app/'public/cerebro.html').read_text(); team=(app/'public/admin-team.html').read_text(); login=(app/'public/login.html').read_text(); popup=(root/'chrome-extension/popup.js').read_text(); extauth=(root/'chrome-extension/k1-extension-auth.js').read_text(); extmanifest=(root/'chrome-extension/manifest.json').read_text(); extcontent=(root/'chrome-extension/content-script.js').read_text(); extcore=(root/'chrome-extension/kronia-core.js').read_text()\n"
if anchor in s:
    s=s.replace(anchor,replace,1)
checks=(
    "assert '\"js\": [\"kronia-core.js\", \"k1-extension-auth.js\", \"content-script.js\"]' in extmanifest\n"
    "assert 'core.loginRequest(u, pw)' in extcontent and \"var loginPassword = el('input'\" in extcontent\n"
    "assert 'historial: state.historial' not in extcore and 'data.historial' not in extcore\n"
)
assert_anchor="assert '/api/kronia/login-request' in extauth and '/api/kronia/login-verify' in extauth\n"
if checks not in s:
    if assert_anchor not in s:
        raise SystemExit('extension runtime assertion anchor missing')
    s=s.replace(assert_anchor,assert_anchor+checks,1)
p.write_text(s,encoding='utf-8')

print('KRONIA_K1_EXTENSION_AUTH_V3_HARDENING=PASS')
