// src/pages/asesor.js
import { session } from '../lib/supabase.js'
import { navigate } from '../lib/router.js'

export function AsesorShell(contenido = '', seccion = 'callcenter') {
  const s = session.get()
  if (!s) { navigate('/'); return '' }

  const nav = [
    { id: 'callcenter',    icon: '📞', label: 'Call Center',   ruta: '/asesor' },
    { id: 'agenda',        icon: '📅', label: 'Agenda',        ruta: '/asesor/agenda' },
    { id: 'pacientes',     icon: '👥', label: 'Pacientes',     ruta: '/asesor/pacientes' },
    { id: 'ventas',        icon: '💰', label: 'Ventas',        ruta: '/asesor/ventas' },
    { id: 'comisiones',    icon: '🏆', label: 'Comisiones',    ruta: '/asesor/comisiones' },
    { id: 'seguimientos',  icon: '⏰', label: 'Seguimientos',  ruta: '/asesor/seguimientos' },
  ]

  return `
    <div class="shell">
      <aside class="sidebar">
        <div class="sb-logo">
          <span class="sb-logo-icon">⬡</span>
          <span class="sb-logo-txt"><b>ASCENDA</b>OS</span>
        </div>

        <div class="sb-user">
          <div class="sb-avatar">${s.nombre.charAt(0)}</div>
          <div>
            <div class="sb-name">${s.nombre}</div>
            <div class="sb-role">${s.puesto}</div>
          </div>
        </div>

        <nav class="sb-nav">
          ${nav.map(n => `
            <a class="sb-item ${seccion === n.id ? 'act' : ''}"
               href="${n.ruta}" onclick="event.preventDefault();window._nav('${n.ruta}')">
              <span class="sb-icon">${n.icon}</span>
              <span>${n.label}</span>
            </a>
          `).join('')}
        </nav>

        <div class="sb-bottom">
          ${s.puesto === 'ADMINISTRADOR' ? `
            <a class="sb-item" href="/admin" onclick="event.preventDefault();window._nav('/admin')">
              <span class="sb-icon">⚙️</span><span>Admin</span>
            </a>
          ` : ''}
          <a class="sb-item sb-logout" href="/" onclick="event.preventDefault();window._logout()">
            <span class="sb-icon">↩</span><span>Salir</span>
          </a>
        </div>
      </aside>

      <main class="main-content" id="main-content">
        ${contenido}
      </main>
    </div>
  `
}

export function initShell() {
  window._nav = (ruta) => navigate(ruta)
  window._logout = () => {
    session.clear()
    navigate('/')
  }
}
