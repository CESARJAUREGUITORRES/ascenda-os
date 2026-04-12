// src/lib/supabase.js
// Conexión directa a Supabase — sin GAS, sin intermediarios

const SB_URL = 'https://ituyqwstonmhnfshnaqz.supabase.co'
const SB_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0'

// Cliente fetch simple para RPCs de Supabase
export async function rpc(nombre, params = {}) {
  const res = await fetch(`${SB_URL}/rest/v1/rpc/${nombre}`, {
    method: 'POST',
    headers: {
      'apikey': SB_ANON,
      'Authorization': `Bearer ${SB_ANON}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(params)
  })
  if (!res.ok) throw new Error(`RPC ${nombre} falló: ${res.status}`)
  return res.json()
}

// Query directa a tabla
export async function query(tabla, filtros = '') {
  const res = await fetch(`${SB_URL}/rest/v1/${tabla}${filtros}`, {
    headers: {
      'apikey': SB_ANON,
      'Authorization': `Bearer ${SB_ANON}`
    }
  })
  if (!res.ok) throw new Error(`Query ${tabla} falló: ${res.status}`)
  return res.json()
}

// Sesión en localStorage
export const session = {
  get() {
    try { return JSON.parse(localStorage.getItem('aos_session')) } catch { return null }
  },
  set(data) {
    localStorage.setItem('aos_session', JSON.stringify(data))
  },
  clear() {
    localStorage.removeItem('aos_session')
  },
  isValid() {
    const s = this.get()
    return s && s.codigo_asesor && s.expires > Date.now()
  }
}
