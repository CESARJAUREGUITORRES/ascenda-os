// src/main.js
import '../src/styles/main.css'
import { session } from './lib/supabase.js'
import { register, init, navigate } from './lib/router.js'
import { LoginPage, initLogin } from './pages/login.js'
import { CallCenterPage, initCallCenter } from './pages/callcenter.js'
import { initShell } from './pages/asesor.js'

// ── Registrar rutas ───────────────────────────────────────
register('/', () => {
  if (session.isValid()) {
    const s = session.get()
    return s.puesto === 'ADMINISTRADOR' ? navigate('/admin') : navigate('/asesor')
  }
  return LoginPage()
})

register('/login', LoginPage)

register('/asesor', () => {
  if (!session.isValid()) return navigate('/')
  return CallCenterPage()
})

register('/asesor/callcenter', () => {
  if (!session.isValid()) return navigate('/')
  return CallCenterPage()
})

// Rutas pendientes (placeholder)
;['/asesor/agenda','/asesor/pacientes','/asesor/ventas','/asesor/comisiones','/asesor/seguimientos','/admin'].forEach(ruta => {
  register(ruta, () => {
    if (!session.isValid()) return navigate('/')
    return CallCenterPage() // TODO: cada panel
  })
})

// ── Inicializar página después del render ─────────────────
document.addEventListener('page:mounted', async (e) => {
  const { path } = e.detail
  if (path === '/' || path === '/login') {
    initLogin()
  } else if (path.startsWith('/asesor')) {
    initShell()
    await initCallCenter()
  }
})

// ── Arrancar ──────────────────────────────────────────────
init()
