/**
 * ═══════════════════════════════════════════════════════════════════
 *  KRONIA CORE — Módulo compartido
 *  Versión: 1.0.0 (2026-05-28)
 *
 *  Es la lógica reutilizable de KronIA usada por TRES consumidores:
 *    1. Chat mayor de AscendaOS (app.html)
 *    2. Brain inmersivo (cerebro.html)
 *    3. Extensión Chrome (chrome-extension/)
 *
 *  Garantía: los tres tienen los mismos poderes (datos, ejecución, voz)
 *  porque comparten este archivo. La diferencia es solo de UI.
 *
 *  Modos de auth soportados:
 *    - LEGACY:   { usuario, id_asesor, rol, sede }    (chat mayor / Brain)
 *    - BEARER:   header Authorization: Bearer <token>  (extensión)
 * ═══════════════════════════════════════════════════════════════════
 */
(function (global) {
  'use strict';

  var DEFAULT_BASE_URL = (typeof location !== 'undefined' && location.origin && location.origin.indexOf('http') === 0)
    ? location.origin
    : 'https://ascenda-os-production.up.railway.app';

  /**
   * Crea una instancia de KroniaCore con configuración inicial.
   * @param {Object} config
   * @param {string} [config.baseUrl]      - URL del backend (default: origen actual)
   * @param {string} [config.token]        - Bearer token (extensión)
   * @param {Object} [config.user]         - { usuario, id_asesor, rol, sede } (chat/Brain)
   * @param {function} [config.onError]    - callback global de errores
   */
  function createKroniaCore(config) {
    config = config || {};
    var state = {
      baseUrl: (config.baseUrl || DEFAULT_BASE_URL).replace(/\/$/, ''),
      token: config.token || null,
      user: config.user || null,
      historial: [],   // últimos 8 turnos {role, content}
      onError: config.onError || function () {}
    };

    // ─── Helpers internos ───────────────────────────────────────────
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
      // Solo últimos 8 turnos válidos (el server también limita)
      return state.historial
        .filter(function (h) { return h && (h.role === 'user' || h.role === 'assistant') && h.content; })
        .slice(-8);
    }

    // ─── AUTH ──────────────────────────────────────────────────────
    /** Solicita código 2FA al email del usuario (extensión) */
    function loginRequest(usuario) {
      return authedFetch('/api/kronia/login-request', {
        method: 'POST',
        body: JSON.stringify({ usuario: usuario })
      }).then(function (r) { return r.json(); });
    }

    /** Valida código 2FA y obtiene token de 24h (extensión) */
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
          state.user = {
            usuario: d.usuario,
            id_asesor: d.id_asesor,
            rol: d.rol,
            sede: d.sede
          };
        }
        return d;
      });
    }

    /** Verifica que el token actual siga válido */
    function verifyToken() {
      if (!state.token) return Promise.resolve({ ok: false, error: 'Sin token' });
      return authedFetch('/api/kronia/verify', { method: 'GET' })
        .then(function (r) { return r.json(); })
        .then(function (d) {
          if (d && d.ok) {
            state.user = {
              usuario: d.usuario,
              id_asesor: d.id_asesor,
              rol: d.rol,
              sede: d.sede
            };
          }
          return d;
        });
    }

    /** Cierra sesión (revoca token) */
    function logout() {
      if (!state.token) return Promise.resolve({ ok: true });
      return authedFetch('/api/kronia/logout', { method: 'POST' })
        .then(function (r) { return r.json(); })
        .then(function (d) {
          state.token = null;
          state.user = null;
          state.historial = [];
          return d;
        });
    }

    function setToken(token, user) {
      state.token = token || null;
      if (user) state.user = user;
    }

    function setUser(user) {
      state.user = user || null;
    }

    function isAuthenticated() {
      return !!(state.token || (state.user && state.user.usuario));
    }

    function getUser() {
      return state.user;
    }

    // ─── CHAT ──────────────────────────────────────────────────────
    /**
     * Envía una pregunta a KronIA. Devuelve la respuesta y maneja historial.
     * @param {string} pregunta
     * @param {Object} [opts] - { session_id, extraHistorial }
     * @returns {Promise<{ok, respuesta, accion?, error?}>}
     */
    function chat(pregunta, opts) {
      opts = opts || {};
      if (!pregunta || !pregunta.trim()) {
        return Promise.resolve({ ok: false, error: 'Pregunta vacía' });
      }

      var payload = {
        pregunta: pregunta.trim(),
        session_id: opts.session_id || ('ses_' + Date.now()),
        historial: opts.extraHistorial || historialParaEnvio()
      };

      // Modo legacy: añade datos del usuario al body (chat mayor / Brain)
      if (!state.token && state.user) {
        payload.usuario = state.user.usuario || '';
        payload.id_asesor = state.user.id_asesor || '';
        payload.rol = state.user.rol || 'ASESOR';
        payload.sede = state.user.sede || '';
      }

      return authedFetch('/api/kronia/chat', {
        method: 'POST',
        body: JSON.stringify(payload)
      }).then(function (r) {
        if (r.status === 401) {
          return r.json().then(function (d) {
            return { ok: false, error: (d && d.error) || 'No autorizado', authExpired: true };
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
    /**
     * Transcribe audio (Blob audio/webm) usando Groq Whisper.
     * @param {Blob} blob
     * @returns {Promise<{ok, texto?, error?}>}
     */
    function whisper(blob) {
      if (!blob || !blob.size) return Promise.resolve({ ok: false, error: 'Audio vacío' });
      var h = { 'Content-Type': 'audio/webm' };
      if (state.token) {
        h['Authorization'] = 'Bearer ' + state.token;
      } else if (state.user) {
        h['X-AOS-User'] = state.user.usuario || '';
        h['X-AOS-Id'] = state.user.id_asesor || '';
      }
      return fetch(state.baseUrl + '/api/kronia/whisper', {
        method: 'POST', headers: h, body: blob
      }).then(function (r) {
        if (r.status === 401) {
          return r.json().then(function (d) {
            return { ok: false, error: (d && d.error) || 'No autorizado', authExpired: true };
          });
        }
        return r.json();
      }).catch(function (e) {
        state.onError(e);
        return { ok: false, error: 'Error voz: ' + (e.message || e) };
      });
    }

    // ─── PERSISTENCIA OPCIONAL (chrome.storage / localStorage) ─────
    /**
     * Guarda token y historial en almacenamiento.
     * - En extensión: usar chrome.storage.local (pasar storage custom)
     * - En web: usa localStorage por defecto
     */
    function persist(storage) {
      var s = storage || (typeof localStorage !== 'undefined' ? localStorage : null);
      if (!s) return;
      try {
        var data = {
          token: state.token,
          user: state.user,
          historial: state.historial
        };
        if (s.setItem) {
          s.setItem('kronia_session', JSON.stringify(data));
        } else if (s.set) {
          // chrome.storage.local API
          s.set({ kronia_session: data });
        }
      } catch (e) { /* silent */ }
    }

    function restore(storage) {
      var s = storage || (typeof localStorage !== 'undefined' ? localStorage : null);
      if (!s) return Promise.resolve(null);
      // localStorage sync
      if (s.getItem) {
        try {
          var raw = s.getItem('kronia_session');
          if (raw) {
            var data = JSON.parse(raw);
            if (data.token) state.token = data.token;
            if (data.user) state.user = data.user;
            if (Array.isArray(data.historial)) state.historial = data.historial;
            return Promise.resolve(state);
          }
        } catch (e) { /* silent */ }
        return Promise.resolve(null);
      }
      // chrome.storage.local async
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

    function clearHistorial() {
      state.historial = [];
    }

    function getHistorial() {
      return state.historial.slice();
    }

    // ─── API PÚBLICA ───────────────────────────────────────────────
    return {
      version: '1.0.0',
      // Auth
      loginRequest: loginRequest,
      loginVerify: loginVerify,
      verifyToken: verifyToken,
      logout: logout,
      setToken: setToken,
      setUser: setUser,
      isAuthenticated: isAuthenticated,
      getUser: getUser,
      // Chat
      chat: chat,
      whisper: whisper,
      // Historial
      clearHistorial: clearHistorial,
      getHistorial: getHistorial,
      // Persistencia
      persist: persist,
      restore: restore,
      // Acceso al estado (sólo lectura recomendada)
      _state: state
    };
  }

  // Expone como global window.KroniaCore y también como módulo
  global.KroniaCore = {
    create: createKroniaCore,
    version: '1.0.0'
  };

  // Soporte para CommonJS (extensión bundler) sin romper navegador
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = global.KroniaCore;
  }
})(typeof window !== 'undefined' ? window : (typeof self !== 'undefined' ? self : this));
