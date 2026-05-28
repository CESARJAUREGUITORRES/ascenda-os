/**
 * ═══════════════════════════════════════════════════════════════════
 *  KronIA Popup Logic
 *  Comparte el core con el content script. UI más compacta y orientada
 *  a acciones rápidas y onboarding.
 * ═══════════════════════════════════════════════════════════════════
 */
(function () {
  'use strict';

  if (!window.KroniaCore) {
    document.body.innerHTML = '<div style="padding:30px;text-align:center;font-family:sans-serif;color:#B91C1C">Error: kronia-core.js no se cargó</div>';
    return;
  }

  var core = window.KroniaCore.create({
    baseUrl: 'https://ascenda-os-production.up.railway.app',
    onError: function (e) { console.warn('[KronIA popup]', e); }
  });

  // ─── DOM refs ────────────────────────────────────────────────────
  var $ = function (id) { return document.getElementById(id); };
  var welcome = $('welcome');
  var main = $('main');
  var loginView = $('login-view');
  var dashView = $('dashboard-view');
  var loginStep1 = $('login-step1');
  var loginStep2 = $('login-step2');
  var loginUsuario = $('login-usuario');
  var loginCodigo = $('login-codigo');
  var btnPedir = $('btn-pedir-codigo');
  var btnVerificar = $('btn-verificar');
  var btnVolver = $('btn-volver');
  var btnLogout = $('btn-logout');
  var status = $('status');
  var loginErr = $('login-err');
  var codigoOk = $('codigo-ok');
  var dashUser = $('dash-user');
  var quickQ = $('quick-q');
  var btnQuickSend = $('btn-quick-send');
  var quickResp = $('quick-resp');
  var btnEmpezar = $('btn-empezar');

  var state = { loginUsuario: '' };

  // ─── Helpers UI ──────────────────────────────────────────────────
  function setView(view) {
    [welcome, loginView, dashView].forEach(function (v) { if (v) v.classList.add('hidden'); });
    if (view === 'welcome') { welcome.classList.remove('hidden'); main.classList.add('hidden'); }
    else { main.classList.remove('hidden'); view.classList.remove('hidden'); }
  }

  function setStatus(text) { status.textContent = text; }

  // ─── Init ────────────────────────────────────────────────────────
  function init() {
    var params = new URLSearchParams(location.search);
    if (params.get('welcome') === '1') {
      setView('welcome');
      btnEmpezar.addEventListener('click', function () { iniciarFlujoLogin(); });
      return;
    }
    iniciarFlujoLogin();
  }

  function iniciarFlujoLogin() {
    setStatus('Verificando sesión...');
    core.restore(chrome.storage.local).then(function (restored) {
      if (restored && core.isAuthenticated()) {
        core.verifyToken().then(function (v) {
          if (v && v.ok) entrarDashboard();
          else mostrarLogin();
        });
      } else {
        mostrarLogin();
      }
    });
  }

  function mostrarLogin() {
    setStatus('Sin sesión');
    btnLogout.classList.add('hidden');
    setView(loginView);
    loginStep1.classList.add('active');
    loginStep2.classList.remove('active');
    setTimeout(function () { loginUsuario.focus(); }, 100);
  }

  function entrarDashboard() {
    var user = core.getUser();
    setStatus('· ' + (user && user.usuario || ''));
    btnLogout.classList.remove('hidden');
    dashUser.textContent = (user && user.usuario) || '';
    setView(dashView);
  }

  // ─── Login ───────────────────────────────────────────────────────
  btnPedir.addEventListener('click', function () {
    var u = loginUsuario.value.trim();
    if (!u) { loginErr.textContent = 'Ingresa tu usuario'; return; }
    loginErr.textContent = '';
    btnPedir.disabled = true;
    btnPedir.textContent = 'Enviando...';
    state.loginUsuario = u;
    core.loginRequest(u).then(function (r) {
      btnPedir.disabled = false;
      btnPedir.textContent = 'Enviar código a mi email';
      if (r && r.ok) {
        codigoOk.textContent = '✓ Código enviado a ' + (r.email_oculto || 'tu email');
        loginStep1.classList.remove('active');
        loginStep2.classList.add('active');
        loginCodigo.focus();
      } else {
        loginErr.textContent = (r && r.error) || 'No se pudo enviar el código';
      }
    }).catch(function () {
      btnPedir.disabled = false;
      btnPedir.textContent = 'Enviar código a mi email';
      loginErr.textContent = 'Error de conexión';
    });
  });

  btnVerificar.addEventListener('click', function () {
    var c = loginCodigo.value.trim();
    if (c.length !== 6) { loginErr.textContent = 'Código de 6 dígitos'; return; }
    loginErr.textContent = '';
    btnVerificar.disabled = true;
    btnVerificar.textContent = 'Verificando...';
    core.loginVerify(state.loginUsuario, c, navigator.userAgent.slice(0, 100)).then(function (r) {
      btnVerificar.disabled = false;
      btnVerificar.textContent = 'Ingresar';
      if (r && r.ok && r.token) {
        core.persist(chrome.storage.local);
        entrarDashboard();
      } else {
        loginErr.textContent = (r && r.error) || 'Código inválido';
      }
    }).catch(function () {
      btnVerificar.disabled = false;
      btnVerificar.textContent = 'Ingresar';
      loginErr.textContent = 'Error de conexión';
    });
  });

  btnVolver.addEventListener('click', function () {
    loginStep2.classList.remove('active');
    loginStep1.classList.add('active');
    loginErr.textContent = '';
    loginUsuario.focus();
  });

  loginUsuario.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); btnPedir.click(); }
  });
  loginCodigo.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); btnVerificar.click(); }
  });

  btnLogout.addEventListener('click', function () {
    if (!confirm('¿Cerrar sesión?')) return;
    core.logout().then(function () {
      try { chrome.storage.local.remove(['kronia_session']); } catch (e) {}
      mostrarLogin();
    });
  });

  // ─── Acciones rápidas ─────────────────────────────────────────────
  document.querySelectorAll('.action-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
      quickQ.value = btn.getAttribute('data-prompt');
      btnQuickSend.click();
    });
  });

  btnQuickSend.addEventListener('click', function () {
    var q = quickQ.value.trim();
    if (!q) return;
    btnQuickSend.disabled = true;
    btnQuickSend.textContent = 'Pensando...';
    quickResp.classList.add('hidden');
    core.chat(q).then(function (d) {
      btnQuickSend.disabled = false;
      btnQuickSend.textContent = 'Preguntar';
      if (d.ok && d.respuesta) {
        quickResp.textContent = d.respuesta;
        quickResp.classList.remove('hidden');
        core.persist(chrome.storage.local);
      } else if (d.authExpired) {
        mostrarLogin();
      } else {
        quickResp.textContent = '⚠ ' + (d.error || 'Error');
        quickResp.classList.remove('hidden');
      }
    });
  });

  init();
})();
