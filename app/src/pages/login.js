// src/pages/login.js
import { query, session } from '../lib/supabase.js'
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
  // Enter key
  document.querySelectorAll('#login-user, #login-pass').forEach(el => {
    el.addEventListener('keydown', e => { if (e.key === 'Enter') doLogin() })
  })

  window._doLogin = doLogin
}

async function doLogin() {
  const user = (document.getElementById('login-user')?.value || '').trim().toLowerCase()
  const pass = (document.getElementById('login-pass')?.value || '').trim()
  const errEl = document.getElementById('login-error')
  const btn = document.getElementById('login-btn')

  if (!user || !pass) {
    errEl.textContent = 'Ingresa usuario y contraseña'
    return
  }

  btn.textContent = 'Verificando...'
  btn.disabled = true
  errEl.textContent = ''

  try {
    // Buscar en Supabase directamente
    const datos = await query(
      'aos_rrhh',
      `?usuario=eq.${encodeURIComponent(user)}&estado=eq.ACTIVO&select=codigo_asesor,nombre,apellido,puesto,sede,usuario,password_hash,permisos`
    )

    if (!datos || datos.length === 0) {
      errEl.textContent = 'Usuario no encontrado'
      btn.textContent = 'Ingresar'
      btn.disabled = false
      return
    }

    const u = datos[0]

    // Validar contraseña (texto plano por ahora — migrar a hash después)
    if (u.password_hash !== pass) {
      errEl.textContent = 'Contraseña incorrecta'
      btn.textContent = 'Ingresar'
      btn.disabled = false
      return
    }

    // Guardar sesión
    session.set({
      codigo_asesor: u.codigo_asesor,
      nombre:        u.nombre,
      apellido:      u.apellido,
      puesto:        u.puesto,
      sede:          u.sede,
      usuario:       u.usuario,
      permisos:      u.permisos || {},
      expires:       Date.now() + (12 * 60 * 60 * 1000) // 12 horas
    })

    // Redirigir según rol
    const ruta = u.puesto === 'ADMINISTRADOR' ? '/admin' : '/asesor'
    navigate(ruta)

  } catch (err) {
    console.error('Login error:', err)
    errEl.textContent = 'Error de conexión. Intenta de nuevo.'
    btn.textContent = 'Ingresar'
    btn.disabled = false
  }
}
