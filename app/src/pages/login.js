// src/pages/login.js
import { rpc, session } from '../lib/supabase.js'
import { navigate } from '../lib/router.js'

export function LoginPage() {
  return `
    <div class="login-wrap">
      <div class="login-card">
        <div class="login-logo">
          <div class="logo-icon">⬡</div>
          <div class="logo-text">
            <span class="logo-ascenda">ASCENDA</span><span class="logo-os">OS</span>
          </div>
          <div class="logo-sub">Zi Vital · CRM Clínica</div>
        </div>
        <div class="login-form">
          <div class="field">
            <label>Usuario</label>
            <input id="login-user" type="text" placeholder="ej: wilmer" autocomplete="username" />
          </div>
          <div class="field">
            <label>Contraseña</label>
            <input id="login-pass" type="password" placeholder="••••••••" autocomplete="current-password" />
          </div>
          <div class="login-error" id="login-error"></div>
          <button id="login-btn" class="btn-primary" onclick="window._doLogin()">
            Ingresar
          </button>
        </div>
        <div class="login-footer">AscendaOS v2 · Supabase Direct</div>
      </div>
    </div>
  `
}

export function initLogin() {
  document.querySelectorAll('#login-user, #login-pass').forEach(el => {
    el.addEventListener('keydown', e => { if (e.key === 'Enter') doLogin() })
  })
  window._doLogin = doLogin

  // Auto-focus
  setTimeout(() => document.getElementById('login-user')?.focus(), 100)
}

async function doLogin() {
  const user = (document.getElementById('login-user')?.value || '').trim().toLowerCase()
  const pass = (document.getElementById('login-pass')?.value || '').trim()
  const errEl = document.getElementById('login-error')
  const btn   = document.getElementById('login-btn')

  if (!user || !pass) { errEl.textContent = 'Ingresa usuario y contraseña'; return }

  btn.textContent = 'Verificando...'
  btn.disabled = true
  errEl.textContent = ''

  try {
    // Llamada directa a la RPC de login en Supabase
    const res = await rpc('aos_login', { p_usuario: user, p_password: pass })

    if (!res || !res.ok) {
      errEl.textContent = res?.error || 'Credenciales incorrectas'
      btn.textContent = 'Ingresar'
      btn.disabled = false
      return
    }

    // Guardar sesión 12 horas
    session.set({
      codigo_asesor: res.codigo_asesor,
      nombre:        res.nombre,
      apellido:      res.apellido,
      puesto:        res.puesto,
      sede:          res.sede,
      usuario:       res.usuario,
      permisos:      res.permisos || {},
      expires:       Date.now() + (12 * 60 * 60 * 1000)
    })

    const ruta = res.puesto === 'ADMINISTRADOR' ? '/admin' : '/asesor'
    navigate(ruta)

  } catch (err) {
    console.error('Login error:', err)
    errEl.textContent = 'Error de conexión. Intenta de nuevo.'
    btn.textContent = 'Ingresar'
    btn.disabled = false
  }
}
