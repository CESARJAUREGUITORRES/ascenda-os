/**
 * ═══════════════════════════════════════════════════════════════════
 *  KronIA Content Script
 *  Se inyecta en cualquier página web visitada (matches <all_urls>).
 *  Construye el botón flotante y el modal expandido del chat.
 *  Comparte lógica con AscendaOS via kronia-core.js.
 *
 *  Comunicación con background.js:
 *   - Para persistencia cross-tab usa chrome.storage.local
 *   - Para atajos de teclado escucha chrome.runtime.onMessage
 * ═══════════════════════════════════════════════════════════════════
 */
(function () {
  'use strict';

  // No duplicar si ya está inyectado (evita doble inyección en SPAs)
  if (window.__kroniaInjected) return;
  window.__kroniaInjected = true;

  // No inyectar en iframes
  if (window.self !== window.top) return;

  // Verificar que kronia-core.js esté cargado
  if (!window.KroniaCore || !window.KroniaCore.create) {
    console.warn('[KronIA] kronia-core.js no se cargó. Extensión deshabilitada.');
    return;
  }

  // ─── INSTANCIA CORE (sin token aún) ───────────────────────────────
  var BASE_URL = 'https://ascenda-os-production.up.railway.app';
  var core = window.KroniaCore.create({
    baseUrl: BASE_URL,
    onError: function (e) { console.warn('[KronIA] core error:', e); }
  });

  // ─── HELPERS DOM ─────────────────────────────────────────────────
  function el(tag, attrs, children) {
    var e = document.createElement(tag);
    if (attrs) {
      for (var k in attrs) {
        if (k === 'class') e.className = attrs[k];
        else if (k === 'text') e.textContent = attrs[k];
        else if (k === 'html') e.innerHTML = attrs[k];
        else if (k.indexOf('on') === 0) e.addEventListener(k.slice(2), attrs[k]);
        else e.setAttribute(k, attrs[k]);
      }
    }
    if (children) children.forEach(function (c) { e.appendChild(c); });
    return e;
  }

  // ─── ESTADO LOCAL ────────────────────────────────────────────────
  var state = {
    open: false,
    authenticated: false,
    user: null,
    sending: false,
    recording: false,
    mediaRec: null,
    audioChunks: [],
    loginUsuario: ''
  };

  // ─── CONSTRUIR DOM DEL WIDGET ────────────────────────────────────
  var root = el('div', { id: 'kronia-floating-root' });

  // Burbuja minimizada
  var bubble = el('div', {
    class: 'kronia-bubble',
    title: 'Abrir KronIA (Ctrl+K)',
    text: 'K'
  });
  var bubbleDot = el('div', { class: 'kronia-bubble-dot' });
  bubble.appendChild(bubbleDot);

  // Modal completo
  var modal = el('div', { class: 'kronia-modal' });

  // Header
  var headerIcon = el('div', { class: 'kronia-header-icon', text: 'K' });
  var headerTitle = el('div', { class: 'kronia-header-title', text: 'KronIA' });
  var headerStatus = el('div', { class: 'kronia-header-status', text: 'Conectando...' });
  var titleWrap = el('div', { class: 'kronia-header-titlewrap' }, [headerTitle, headerStatus]);
  titleWrap.style.flex = '1';
  var btnMin = el('button', { class: 'kronia-header-btn', title: 'Minimizar', html: '&#8211;' });
  var btnClose = el('button', { class: 'kronia-header-btn', title: 'Cerrar sesión', html: '&#x2715;' });
  btnClose.style.display = 'none'; // sólo aparece tras login
  var headerActions = el('div', { class: 'kronia-header-actions' }, [btnMin, btnClose]);
  var header = el('div', { class: 'kronia-header' }, [headerIcon, titleWrap, headerActions]);

  // Body (mensajes)
  var body = el('div', { class: 'kronia-body' });
  var typing = el('div', { class: 'kronia-typing' }, [
    el('div', { class: 'kronia-typing-dot' }),
    el('div', { class: 'kronia-typing-dot' }),
    el('div', { class: 'kronia-typing-dot' })
  ]);
  body.appendChild(typing);

  // Login overlay (oculto si ya hay sesión)
  var loginErr = el('div', { class: 'kronia-err' });
  var loginUsuario = el('input', { type: 'text', placeholder: 'Tu usuario', autocomplete: 'username' });
  var btnPedirCodigo = el('button', { text: 'Enviar código a mi email' });
  var step1 = el('div', { class: 'kronia-login-step active' }, [
    el('label', { text: 'Usuario' }),
    loginUsuario,
    btnPedirCodigo
  ]);

  var loginCodigo = el('input', { type: 'text', placeholder: '6 dígitos', maxlength: '6', autocomplete: 'one-time-code', inputmode: 'numeric' });
  var btnVerificar = el('button', { text: 'Ingresar' });
  var btnVolver = el('button', { text: '← Cambiar usuario' });
  btnVolver.style.background = 'transparent';
  btnVolver.style.color = '#0A4FBF';
  btnVolver.style.border = '1.5px solid rgba(10,79,191,0.16)';
  var step2 = el('div', { class: 'kronia-login-step' }, [
    el('p', { class: 'kronia-ok kronia-codigo-ok', text: '' }),
    el('label', { text: 'Código de 6 dígitos' }),
    loginCodigo,
    btnVerificar,
    btnVolver
  ]);

  var login = el('div', { class: 'kronia-login' }, [
    el('h3', { text: '👋 Bienvenido a KronIA' }),
    el('p', { text: 'Ingresa tu usuario de AscendaOS. Te enviaremos un código de verificación a tu email.' }),
    step1,
    step2,
    loginErr
  ]);

  // Input area
  var input = el('textarea', { class: 'kronia-input', placeholder: 'Pregunta a KronIA...', rows: '1' });
  var btnMic = el('button', { class: 'kronia-btn-mic', title: 'Grabar audio', html: '&#x1F3A4;' });
  var btnSend = el('button', { class: 'kronia-btn-send', title: 'Enviar', html: '&#x27A4;' });
  var inputArea = el('div', { class: 'kronia-input-area' }, [input, btnMic, btnSend]);

  modal.appendChild(header);
  modal.appendChild(body);
  modal.appendChild(inputArea);
  modal.appendChild(login); // login encima cuando hace falta

  root.appendChild(bubble);
  root.appendChild(modal);

  // Esperar que body esté disponible (en algunos sitios document.body tarda)
  function inject() {
    if (!document.body) { setTimeout(inject, 50); return; }
    document.body.appendChild(root);
    init();
  }
  inject();

  // ─── FUNCIONES UI ────────────────────────────────────────────────
  function setStatus(text, color) {
    headerStatus.textContent = text;
    if (color) headerStatus.style.color = color;
  }

  function addMsg(role, text) {
    var m = el('div', { class: 'kronia-msg ' + role, text: text });
    body.insertBefore(m, typing);
    body.scrollTop = body.scrollHeight;
    return m;
  }

  function showTyping(on) {
    if (on) typing.classList.add('show');
    else typing.classList.remove('show');
    body.scrollTop = body.scrollHeight;
  }

  function openModal() {
    modal.classList.add('open');
    bubble.classList.add('hidden');
    state.open = true;
    if (state.authenticated) input.focus();
    else loginUsuario.focus();
  }

  function closeModal() {
    modal.classList.remove('open');
    bubble.classList.remove('hidden');
    state.open = false;
  }

  function showLogin(show) {
    if (show) {
      login.classList.remove('hidden');
      step1.classList.add('active'); step2.classList.remove('active');
      loginUsuario.value = '';
      loginCodigo.value = '';
      loginErr.textContent = '';
      btnClose.style.display = 'none';
    } else {
      login.classList.add('hidden');
      btnClose.style.display = 'flex';
    }
  }

  function welcomeMessage() {
    body.querySelectorAll('.kronia-msg').forEach(function (n) { n.remove(); });
    var u = (state.user && state.user.usuario) || 'colega';
    addMsg('system', 'Hola ' + u + ' · KronIA listo. ¿En qué te ayudo?');
  }

  // ─── DRAG (mover burbuja arrastrando) ────────────────────────────
  var drag = { active: false, startX: 0, startY: 0, origX: 0, origY: 0, moved: false };
  bubble.addEventListener('mousedown', function (e) {
    drag.active = true; drag.moved = false;
    var r = bubble.getBoundingClientRect();
    drag.startX = e.clientX; drag.startY = e.clientY;
    drag.origX = r.left; drag.origY = r.top;
    bubble.classList.add('dragging');
    e.preventDefault();
  });
  document.addEventListener('mousemove', function (e) {
    if (!drag.active) return;
    var dx = e.clientX - drag.startX;
    var dy = e.clientY - drag.startY;
    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) drag.moved = true;
    bubble.style.left = (drag.origX + dx) + 'px';
    bubble.style.top = (drag.origY + dy) + 'px';
    bubble.style.right = 'auto'; bubble.style.bottom = 'auto';
  });
  document.addEventListener('mouseup', function () {
    if (drag.active) {
      bubble.classList.remove('dragging');
      if (drag.moved) {
        // Guardar posición
        try {
          chrome.storage.local.set({
            kronia_bubble_pos: { left: bubble.style.left, top: bubble.style.top }
          });
        } catch (e) {}
      }
      drag.active = false;
    }
  });
  // Click "limpio" (sin drag) abre el modal
  bubble.addEventListener('click', function (e) {
    if (drag.moved) { drag.moved = false; return; }
    openModal();
  });

  // ─── AUTH ────────────────────────────────────────────────────────
  function intentarRestaurar() {
    return core.restore(chrome.storage.local).then(function (restored) {
      if (restored && core.isAuthenticated()) {
        return core.verifyToken().then(function (v) {
          if (v && v.ok) {
            state.authenticated = true;
            state.user = core.getUser();
            setStatus('· ' + (state.user.usuario || ''), '#fff');
            showLogin(false);
            welcomeMessage();
            return true;
          }
          // token vencido o revocado
          state.authenticated = false;
          showLogin(true);
          setStatus('Sesión expirada');
          return false;
        });
      }
      showLogin(true);
      setStatus('Sin sesión');
      return false;
    });
  }

  btnPedirCodigo.addEventListener('click', function () {
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
        state.authenticated = true;
        state.user = core.getUser();
        core.persist(chrome.storage.local);
        setStatus('· ' + state.user.usuario, '#fff');
        showLogin(false);
        welcomeMessage();
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
    step2.classList.remove('active');
    step1.classList.add('active');
    loginErr.textContent = '';
    loginUsuario.focus();
  });

  loginCodigo.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); btnVerificar.click(); }
  });
  loginUsuario.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); btnPedirCodigo.click(); }
  });

  btnClose.addEventListener('click', function () {
    if (!confirm('¿Cerrar sesión de KronIA?')) return;
    core.logout().then(function () {
      state.authenticated = false;
      state.user = null;
      try { chrome.storage.local.remove(['kronia_session']); } catch (e) {}
      showLogin(true);
      setStatus('Sin sesión');
      body.querySelectorAll('.kronia-msg').forEach(function (n) { n.remove(); });
    });
  });

  btnMin.addEventListener('click', closeModal);

  // ─── CHAT ────────────────────────────────────────────────────────
  function enviar() {
    var q = input.value.trim();
    if (!q || state.sending) return;
    if (!state.authenticated) { showLogin(true); return; }
    input.value = '';
    input.style.height = 'auto';
    addMsg('user', q);
    state.sending = true;
    btnSend.disabled = true;
    showTyping(true);
    core.chat(q).then(function (d) {
      showTyping(false);
      state.sending = false;
      btnSend.disabled = false;
      if (d.ok && d.respuesta) {
        addMsg('ai', d.respuesta);
        core.persist(chrome.storage.local);
      } else if (d.authExpired) {
        addMsg('error', 'Sesión expirada. Vuelve a iniciar sesión.');
        state.authenticated = false;
        showLogin(true);
      } else {
        addMsg('error', d.error || 'Error desconocido');
      }
    });
  }

  btnSend.addEventListener('click', enviar);
  input.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      enviar();
    }
  });
  input.addEventListener('input', function () {
    input.style.height = 'auto';
    input.style.height = Math.min(input.scrollHeight, 100) + 'px';
  });

  // ─── VOZ ─────────────────────────────────────────────────────────
  btnMic.addEventListener('click', function () {
    if (state.recording) { detenerGrabacion(); return; }
    if (!navigator.mediaDevices || !window.MediaRecorder) {
      addMsg('error', 'Tu navegador no soporta grabación de audio');
      return;
    }
    if (!state.authenticated) { showLogin(true); return; }
    navigator.mediaDevices.getUserMedia({ audio: true }).then(function (stream) {
      state.audioChunks = [];
      var mr = new MediaRecorder(stream, { mimeType: 'audio/webm' });
      mr.ondataavailable = function (e) { if (e.data && e.data.size > 0) state.audioChunks.push(e.data); };
      mr.onstop = function () {
        stream.getTracks().forEach(function (t) { t.stop(); });
        btnMic.classList.remove('recording');
        btnMic.innerHTML = '&#x1F3A4;';
        state.recording = false;
        if (!state.audioChunks.length) return;
        var blob = new Blob(state.audioChunks, { type: 'audio/webm' });
        showTyping(true);
        core.whisper(blob).then(function (r) {
          showTyping(false);
          if (r.ok && r.texto) {
            input.value = r.texto;
            enviar();
          } else {
            addMsg('error', 'No pude transcribir el audio');
          }
        });
      };
      state.mediaRec = mr;
      state.recording = true;
      btnMic.classList.add('recording');
      btnMic.innerHTML = '&#x23F9;';
      mr.start();
      // máximo 30 segundos
      setTimeout(function () { if (state.recording) detenerGrabacion(); }, 30000);
    }).catch(function () {
      addMsg('error', 'Permiso de micrófono denegado');
    });
  });

  function detenerGrabacion() {
    if (state.mediaRec && state.recording) state.mediaRec.stop();
  }

  // ─── ATAJO Ctrl+K via background.js ──────────────────────────────
  chrome.runtime.onMessage.addListener(function (msg, sender, sendResp) {
    if (msg && msg.type === 'kronia-toggle') {
      if (state.open) closeModal(); else openModal();
      sendResp({ ok: true });
    }
    if (msg && msg.type === 'kronia-hide-bubble') {
      bubble.classList.toggle('hidden');
      sendResp({ ok: true });
    }
  });

  // ─── INIT ────────────────────────────────────────────────────────
  function init() {
    // Restaurar posición de la burbuja
    try {
      chrome.storage.local.get(['kronia_bubble_pos'], function (r) {
        if (r && r.kronia_bubble_pos) {
          if (r.kronia_bubble_pos.left) bubble.style.left = r.kronia_bubble_pos.left;
          if (r.kronia_bubble_pos.top) bubble.style.top = r.kronia_bubble_pos.top;
          if (r.kronia_bubble_pos.left || r.kronia_bubble_pos.top) {
            bubble.style.right = 'auto'; bubble.style.bottom = 'auto';
          }
        }
      });
    } catch (e) {}

    intentarRestaurar();
  }
})();
