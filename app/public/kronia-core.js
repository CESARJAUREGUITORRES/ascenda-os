/**
 * ═══════════════════════════════════════════════════════════════════
 *  KRONIA CORE — Módulo compartido
 *  Versión: 1.1.0 (K1, 2026-08-14)
 *
 *  Consumidores:
 *    1. Chat mayor de AscendaOS (app.html)
 *    2. Brain inmersivo (cerebro.html)
 *    3. Extensión Chrome (chrome-extension/)
 *
 *  K1: toda operación protegida usa un token opaco Bearer. `user` se conserva
 *  únicamente como contexto de UI; nunca como autoridad de identidad/rol/sede.
 * ═══════════════════════════════════════════════════════════════════
 */
(function (global) {
  'use strict';

  var DEFAULT_BASE_URL = (typeof location !== 'undefined' && location.origin && location.origin.indexOf('http') === 0)
    ? location.origin
    : 'https://ascenda-os-production.up.railway.app';

  function defaultWebStorage() {
    return typeof sessionStorage !== 'undefined' ? sessionStorage : null;
  }

  function initialToken(config) {
    if (config && config.token) return config.token;
    var s = defaultWebStorage();
    if (!s) return null;
    try { return s.getItem('aos_kronia_token') || null; } catch (e) { return null; }
  }

  function createKroniaCore(config) {
    config = config || {};
    var state = {
      baseUrl: (config.baseUrl || DEFAULT_BASE_URL).replace(/\/$/, ''),
      token: initialToken(config),
      user: config.user || null,
      historial: [],
      onError: config.onError || function () {}
    };

    function headers(extra) {
      var h = { 'Content-Type': 'application/json' };
      if (state.token) h['Authorization'] = 'Bearer ' + state.token;
      if (extra) for (var k in extra) h[k] = extra[k];
      return h;
    }

    function authedFetch(path, opts) {
      opts = opts || {};
      opts.headers = headers(opts.headers || {});
      return fetch(state.baseUrl + path, opts);
    }

    function pushHistorial(role, content) {
      state.historial.push({ role: role, content: String(content || '').slice(0, 2000) });
      if (state.historial.length > 16) state.historial = state.historial.slice(-16);
    }

    function historialParaEnvio() {
      return state.historial
        .filter(function (h) { return h && (h.role === 'user' || h.role === 'assistant') && h.content; })
        .slice(-8);
    }

    function rememberWebToken() {
      var s = defaultWebStorage();
      if (!s) return;
      try {
        if (state.token) s.setItem('aos_kronia_token', state.token);
        else s.removeItem('aos_kronia_token');
      } catch (e) { /* silent */ }
    }

    // ─── AUTH ──────────────────────────────────────────────────────
    function loginRequest(usuario) {
      return authedFetch('/api/kronia/login-request', {
        method: 'POST',
        body: JSON.stringify({ usuario: usuario })
      }).then(function (r) { return r.json(); });
    }

    function loginVerify(usuario, codigo, deviceInfo) {
      return authedFetch('/api/kronia/login-verify', {
        method: 'POST',
        body: JSON.stringify({
          usuario: usuario,
          codigo: codigo,
          device_info: deviceInfo || (typeof navigator !== 'undefined' ? navigator.userAgent : '')
        })
      }).then(function (r) { return r.json(); }).then(function (d) {
        if (d && d.ok && d.token) {
          state.token = d.token;
          state.user = { usuario: d.usuario, id_asesor: d.id_asesor, rol: d.rol, sede: d.sede };
          rememberWebToken();
        }
        return d;
      });
    }

    function verifyToken() {
      if (!state.token) return Promise.resolve({ ok: false, error: 'Sin token' });
      return authedFetch('/api/kronia/verify', { method: 'GET' })
        .then(function (r) { return r.json(); })
        .then(function (d) {
          if (d && d.ok) {
            state.user = { usuario: d.usuario, id_asesor: d.id_asesor, rol: d.rol, sede: d.sede };
          } else if (d && d.error) {
            state.token = null;
            rememberWebToken();
          }
          return d;
        });
    }

    function logout() {
      if (!state.token) return Promise.resolve({ ok: true });
      return authedFetch('/api/kronia/logout', { method: 'POST' })
        .then(function (r) { return r.json(); })
        .then(function (d) {
          state.token = null;
          state.user = null;
          state.historial = [];
          rememberWebToken();
          return d;
        });
    }

    function setToken(token, user) {
      state.token = token || null;
      if (user) state.user = user;
      rememberWebToken();
    }

    function setUser(user) {
      state.user = user || null;
    }

    function isAuthenticated() {
      return !!state.token;
    }

    function getUser() { return state.user; }

    // ─── CHAT ──────────────────────────────────────────────────────
    function chat(pregunta, opts) {
      opts = opts || {};
      if (!pregunta || !pregunta.trim()) return Promise.resolve({ ok: false, error: 'Pregunta vacía' });
      if (!state.token) return Promise.resolve({ ok: false, error: 'Sesión KronIA requerida', authExpired: true });

      var payload = {
        pregunta: pregunta.trim(),
        session_id: opts.session_id || ('ses_' + Date.now()),
        historial: opts.extraHistorial || historialParaEnvio()
      };

      return authedFetch('/api/kronia/chat', {
        method: 'POST',
        body: JSON.stringify(payload)
      }).then(function (r) {
        if (r.status === 401 || r.status === 403) {
          return r.json().then(function (d) {
            return { ok: false, error: (d && d.error) || 'No autorizado', authExpired: r.status === 401 };
          });
        }
        return r.json();
      }).then(function (d) {
        if (d && d.ok && d.respuesta) {
          pushHistorial('user', pregunta);
          pushHistorial('assistant', d.respuesta);
        }
        return d;
      }).catch(function (e) {
        state.onError(e);
        return { ok: false, error: 'Error de conexión: ' + (e.message || e) };
      });
    }

    // ─── VOZ ───────────────────────────────────────────────────────
    function whisper(blob) {
      if (!blob || !blob.size) return Promise.resolve({ ok: false, error: 'Audio vacío' });
      if (!state.token) return Promise.resolve({ ok: false, error: 'Sesión KronIA requerida', authExpired: true });
      return fetch(state.baseUrl + '/api/kronia/whisper', {
        method: 'POST',
        headers: { 'Content-Type': 'audio/webm', 'Authorization': 'Bearer ' + state.token },
        body: blob
      }).then(function (r) {
        if (r.status === 401 || r.status === 403) {
          return r.json().then(function (d) {
            return { ok: false, error: (d && d.error) || 'No autorizado', authExpired: r.status === 401 };
          });
        }
        return r.json();
      }).catch(function (e) {
        state.onError(e);
        return { ok: false, error: 'Error voz: ' + (e.message || e) };
      });
    }

    // ─── PERSISTENCIA ──────────────────────────────────────────────
    // Web: sessionStorage. Extensión: chrome.storage.local custom.
    function persist(storage) {
      var s = storage || defaultWebStorage();
      if (!s) return;
      try {
        var data = { token: state.token, user: state.user, historial: state.historial };
        if (s.setItem) {
          s.setItem('kronia_session', JSON.stringify(data));
          if (state.token) s.setItem('aos_kronia_token', state.token);
        } else if (s.set) {
          s.set({ kronia_session: data });
        }
      } catch (e) { /* silent */ }
    }

    function restore(storage) {
      var s = storage || defaultWebStorage();
      if (!s) return Promise.resolve(null);
      if (s.getItem) {
        try {
          var raw = s.getItem('kronia_session');
          if (raw) {
            var data = JSON.parse(raw);
            if (data.token) state.token = data.token;
            if (data.user) state.user = data.user;
            if (Array.isArray(data.historial)) state.historial = data.historial;
          } else {
            state.token = s.getItem('aos_kronia_token') || state.token;
          }
          return Promise.resolve(state.token ? state : null);
        } catch (e) { return Promise.resolve(null); }
      }
      return new Promise(function (resolve) {
        s.get(['kronia_session'], function (result) {
          var data = result && result.kronia_session;
          if (data) {
            if (data.token) state.token = data.token;
            if (data.user) state.user = data.user;
            if (Array.isArray(data.historial)) state.historial = data.historial;
            resolve(state);
          } else resolve(null);
        });
      });
    }

    function clearHistorial() { state.historial = []; }
    function getHistorial() { return state.historial.slice(); }

    return {
      version: '1.1.0',
      loginRequest: loginRequest,
      loginVerify: loginVerify,
      verifyToken: verifyToken,
      logout: logout,
      setToken: setToken,
      setUser: setUser,
      isAuthenticated: isAuthenticated,
      getUser: getUser,
      chat: chat,
      whisper: whisper,
      clearHistorial: clearHistorial,
      getHistorial: getHistorial,
      persist: persist,
      restore: restore,
      _state: state
    };
  }

  global.KroniaCore = { create: createKroniaCore, version: '1.1.0' };
  if (typeof module !== 'undefined' && module.exports) module.exports = global.KroniaCore;
})(typeof window !== 'undefined' ? window : (typeof self !== 'undefined' ? self : this));
