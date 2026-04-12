// src/pages/callcenter.js
// 100% Supabase directo — sin GAS
import { rpc, session } from '../lib/supabase.js'
import { AsesorShell, initShell } from './asesor.js'

// ── Estado global del panel ───────────────────────────────
let STATE = {
  lead:      null,
  subTipif:  'NO CONTESTA',
  guardando: false,
}

// ── Template del panel ────────────────────────────────────
function template() {
  return `
    <!-- KPIs -->
    <div class="kpi-strip">
      <div class="kpi-card blue">
        <div class="kpi-label">Llamadas hoy</div>
        <div class="kpi-val" id="kpi-llam">—</div>
        <div class="kpi-sub">del día</div>
      </div>
      <div class="kpi-card cyan">
        <div class="kpi-label">Citas hoy</div>
        <div class="kpi-val" id="kpi-citas">—</div>
        <div class="kpi-sub">confirmadas</div>
      </div>
      <div class="kpi-card green">
        <div class="kpi-label">Conv. leads</div>
        <div class="kpi-val" id="kpi-conv">—</div>
        <div class="kpi-sub">Llam → Cita</div>
      </div>
      <div class="kpi-card amber">
        <div class="kpi-label">Mes</div>
        <div class="kpi-val" id="kpi-mes">—</div>
        <div class="kpi-sub">llamadas</div>
      </div>
      <div class="kpi-card purple">
        <div class="kpi-label">Facturado</div>
        <div class="kpi-val" id="kpi-fact" style="font-size:16px">—</div>
        <div class="kpi-sub">este mes</div>
      </div>
    </div>

    <!-- Grid 3 col -->
    <div class="cc-grid page-grid" style="grid-template-columns:340px 1fr;flex:1;min-height:0;">

      <!-- COL 1: CALL CENTER -->
      <div style="display:flex;flex-direction:column;gap:10px;">
        <div class="card" style="flex:1;display:flex;flex-direction:column;">

          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;">
            <div style="font-family:'Exo 2',sans-serif;font-weight:800;font-size:12px;letter-spacing:.5px;">CALL CENTER</div>
            <div style="display:flex;gap:6px;">
              <span class="chip chip-base" id="cc-tier">CARGANDO</span>
              <span class="chip chip-cita">● EN LÍNEA</span>
            </div>
          </div>

          <!-- Número activo -->
          <div id="cc-num-block" style="background:linear-gradient(135deg,#EBF2FF,#E0F7F3);border-radius:10px;padding:12px 14px;margin-bottom:10px;border:1px solid #DBEAFE;cursor:pointer;" onclick="window._abrirFicha()">
            <div style="font-size:9px;color:#9AAAC8;margin-bottom:2px;" id="cc-nombre-pac"></div>
            <div style="font-family:'Exo 2',sans-serif;font-size:28px;font-weight:800;letter-spacing:3px;color:#0A4FBF;" id="cc-num">Cargando...</div>
            <div style="font-size:10px;color:#9AAAC8;margin-top:3px;">
              <span style="font-weight:700;color:#1A6FE8;" id="cc-trat"></span>
              <span id="cc-meta"></span>
            </div>
            <div style="font-size:8px;color:#9AAAC8;text-align:right;margin-top:4px;">👆 Toca para ver ficha</div>
          </div>

          <!-- Botones llamar/WA -->
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:10px;">
            <button onclick="window._llamar()" style="padding:10px;border-radius:9px;background:#0A4FBF;color:#fff;border:none;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;gap:6px;">
              📞 Llamar
            </button>
            <button onclick="window._whatsapp()" style="padding:10px;border-radius:9px;background:#25D366;color:#fff;border:none;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;gap:6px;">
              💬 WhatsApp
            </button>
          </div>

          <!-- Tipificación -->
          <select id="cc-tipif" onchange="window._onTipif(this.value)" style="width:100%;padding:8px 10px;border-radius:8px;border:1px solid #DDE4F5;background:#F0F4FC;font-size:12px;margin-bottom:8px;outline:none;">
            <option value="">— Tipificación —</option>
            <option value="CITA CONFIRMADA">✅ CITA CONFIRMADA</option>
            <option value="SIN CONTACTO">📵 SIN CONTACTO</option>
            <option value="NO LE INTERESA">❌ NO LE INTERESA</option>
            <option value="SEGUIMIENTO">🔁 SEGUIMIENTO</option>
            <option value="PROVINCIA">📍 PROVINCIA</option>
            <option value="SACAR DE LA BASE">🗑 SACAR DE LA BASE</option>
          </select>

          <!-- Sub-tipif SIN CONTACTO -->
          <div id="sub-tipif" style="display:none;padding:8px 10px;background:#FFF7ED;border-radius:8px;border:1px solid #FED7AA;margin-bottom:8px;">
            <div style="font-size:9px;font-weight:700;color:#D97706;margin-bottom:6px;text-transform:uppercase;">¿Qué pasó?</div>
            <div style="display:flex;gap:6px;flex-wrap:wrap;" id="sub-opts">
              <button onclick="window._subTipif('NO CONTESTA')"   class="sub-opt act" data-v="NO CONTESTA">No contesta</button>
              <button onclick="window._subTipif('SIN SERVICIO')"  class="sub-opt"     data-v="SIN SERVICIO">Sin servicio</button>
              <button onclick="window._subTipif('NO EXISTE')"     class="sub-opt"     data-v="NO EXISTE">Nº no existe</button>
            </div>
          </div>

          <textarea id="cc-obs" placeholder="Observación..." style="width:100%;padding:8px 10px;border-radius:8px;border:1px solid #DDE4F5;background:#F0F4FC;font-size:12px;resize:none;height:50px;margin-bottom:8px;outline:none;"></textarea>

          <button id="cc-guardar" onclick="window._guardar()" style="width:100%;padding:10px;border-radius:8px;background:#0A4FBF;color:#fff;border:none;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;gap:5px;">
            ✓ Guardar resultado
          </button>
        </div>

        <!-- Historial hoy -->
        <div class="card">
          <div style="font-size:9px;font-weight:700;color:#9AAAC8;letter-spacing:.5px;text-transform:uppercase;margin-bottom:8px;">LLAMADAS DE HOY</div>
          <div id="cc-hist" style="max-height:200px;overflow-y:auto;">
            <div class="ld"><span class="sp"></span></div>
          </div>
        </div>
      </div>

      <!-- COL 2: SCORE + TIPIFICACIONES -->
      <div style="display:flex;flex-direction:column;gap:10px;">

        <!-- Score del mes -->
        <div class="card">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px;">
            <div style="font-family:'Exo 2',sans-serif;font-weight:800;font-size:11px;">SCORE DEL MES</div>
            <select id="score-mes" onchange="window._cargarScore()" style="padding:3px 8px;border-radius:6px;border:1px solid #DDE4F5;background:#F0F4FC;font-size:10px;outline:none;"></select>
          </div>
          <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:12px;">
            <div style="background:#F0F4FC;border-radius:8px;padding:8px;border:1px solid #DDE4F5;">
              <div style="font-family:'Exo 2',sans-serif;font-size:18px;font-weight:800;color:#0A4FBF;" id="sc-llam">—</div>
              <div style="font-size:8px;color:#9AAAC8;text-transform:uppercase;">Llamadas</div>
            </div>
            <div style="background:#F0F4FC;border-radius:8px;padding:8px;border:1px solid #DDE4F5;">
              <div style="font-family:'Exo 2',sans-serif;font-size:18px;font-weight:800;color:#0A4FBF;" id="sc-citas">—</div>
              <div style="font-size:8px;color:#9AAAC8;text-transform:uppercase;">Citas</div>
            </div>
            <div style="background:#F0F4FC;border-radius:8px;padding:8px;border:1px solid #DDE4F5;">
              <div style="font-family:'Exo 2',sans-serif;font-size:18px;font-weight:800;color:#16A34A;" id="sc-ventas">—</div>
              <div style="font-size:8px;color:#9AAAC8;text-transform:uppercase;">Ventas</div>
            </div>
            <div style="background:#F0F4FC;border-radius:8px;padding:8px;border:1px solid #DDE4F5;">
              <div style="font-family:'Exo 2',sans-serif;font-size:16px;font-weight:800;color:#0A4FBF;" id="sc-fact">—</div>
              <div style="font-size:8px;color:#9AAAC8;text-transform:uppercase;">Facturado</div>
            </div>
          </div>

          <!-- Tipificaciones -->
          <div style="font-size:9px;font-weight:700;color:#9AAAC8;text-transform:uppercase;letter-spacing:.4px;margin-bottom:6px;">TIPIFICACIONES</div>
          <div id="tipif-bars"><div class="ld"><span class="sp"></span></div></div>
        </div>

        <!-- Tabla anual -->
        <div class="card">
          <div style="font-family:'Exo 2',sans-serif;font-weight:800;font-size:11px;margin-bottom:10px;">HISTÓRICO ANUAL</div>
          <div id="tabla-anual"><div class="ld"><span class="sp"></span></div></div>
        </div>
      </div>

    </div>

    <style>
      .sub-opt{padding:4px 10px;border-radius:6px;border:1.5px solid #FED7AA;background:#fff;font-size:10px;font-weight:700;color:#D97706;cursor:pointer;}
      .sub-opt.act{background:#D97706;border-color:#D97706;color:#fff;}
    </style>
  `
}

// ── Inicialización ────────────────────────────────────────
export async function initCallCenter() {
  const s = session.get()
  if (!s) return

  // Poblar selector de meses
  poblarMeses()

  // Cargar todo en paralelo
  await Promise.all([
    cargarKPIs(s),
    cargarSiguienteLead(s),
    cargarHistorial(s),
    cargarScore(s),
    cargarAnual(s),
  ])

  // Handlers globales
  window._llamar    = () => { if (STATE.lead) window.open(`tel:+51${STATE.lead.num}`) }
  window._whatsapp  = () => { if (STATE.lead) window.open(`https://wa.me/51${STATE.lead.num}`) }
  window._onTipif   = onTipif
  window._subTipif  = setSubTipif
  window._guardar   = guardar
  window._cargarScore = () => cargarScore(s)
  window._abrirFicha = () => {} // TODO: Bloque 3
}

// ── Cargar KPIs ───────────────────────────────────────────
async function cargarKPIs(s) {
  try {
    const hoy = new Date().toISOString().slice(0,10)
    const mes = hoy.slice(0,7) + '-01'
    const d = await rpc('aos_panel_asesor', {
      p_asesor: s.nombre.toUpperCase(),
      p_id_asesor: s.codigo_asesor,
      p_hoy: hoy,
      p_mes_inicio: mes
    })
    set('kpi-llam', d.llamHoy  || 0)
    set('kpi-citas', d.citasHoy || 0)
    const conv = d.llamHoy > 0 ? Math.round((d.citasHoy||0)/d.llamHoy*100) : 0
    set('kpi-conv', conv + '%')
    set('kpi-mes',  d.llamMes  || 0)
    const fact = parseFloat(d.factMes) || 0
    set('kpi-fact', fact > 0 ? 'S/' + fact.toFixed(0) : 'S/0')

    // Guardar para el historial
    window._panelData = d
    renderHistorial(d.llamadasHoy || [])
    renderTipifBars(d.tipifMes || [])
  } catch(e) {
    console.error('KPIs:', e)
  }
}

// ── Siguiente lead ────────────────────────────────────────
async function cargarSiguienteLead(s) {
  try {
    const hoy = new Date().toISOString().slice(0,10)
    const d = await rpc('aos_siguiente_lead', {
      p_asesor: s.nombre.toUpperCase(),
      p_id_asesor: s.codigo_asesor,
      p_hoy: hoy
    })
    if (!d || !d.ok || !d.lead) {
      set('cc-num', 'Sin leads')
      set('cc-tier', 'BASE OK')
      return
    }
    STATE.lead = {
      num:   d.lead.num || '',
      trat:  d.lead.trat || '',
      wa:    `https://wa.me/51${(d.lead.num||'').replace(/\D/g,'')}`,
      intento: d.lead.intento || 1,
      fecha: d.lead.fecha || '',
      rowNum: 0,
    }
    set('cc-num',  STATE.lead.num)
    set('cc-trat', STATE.lead.trat)
    set('cc-meta', ` · #${STATE.lead.intento}`)
    set('cc-tier', d.tier || 'TIER 1')
  } catch(e) {
    console.error('Lead:', e)
    set('cc-num', 'Error')
  }
}

// ── Historial ─────────────────────────────────────────────
async function cargarHistorial(s) {
  if (window._panelData) {
    renderHistorial(window._panelData.llamadasHoy || [])
  }
}

function renderHistorial(items) {
  const el = document.getElementById('cc-hist')
  if (!el) return
  if (!items.length) {
    el.innerHTML = '<div class="ld">Sin llamadas hoy</div>'
    return
  }
  const chipMap = {
    'CITA CONFIRMADA':'chip-cita','SIN CONTACTO':'chip-sc',
    'NO CONTESTA':'chip-sc','NO LE INTERESA':'chip-ni',
    'SEGUIMIENTO':'chip-seg'
  }
  el.innerHTML = `<table style="width:100%;border-collapse:collapse;font-size:10px;">
    <thead><tr style="color:#9AAAC8;font-size:8px;font-weight:700;text-transform:uppercase;">
      <th style="padding:3px 5px;text-align:left;">Hora</th>
      <th style="padding:3px 5px;text-align:left;">Número</th>
      <th style="padding:3px 5px;text-align:left;">Trat.</th>
      <th style="padding:3px 5px;text-align:left;">Estado</th>
    </tr></thead>
    <tbody>${items.slice(0,30).map(r => {
      const est = r.estado === 'NO CONTESTA' ? 'SIN CONTACTO' : (r.estado||'—')
      const cls = chipMap[r.estado] || chipMap[est] || 'chip-base'
      return `<tr style="border-bottom:1px solid rgba(221,228,245,.3);">
        <td style="padding:5px;">${(r.hora||'—').slice(0,5)}</td>
        <td style="padding:5px;font-weight:700;">${r.num||'—'}</td>
        <td style="padding:5px;color:#6B7BA8;max-width:80px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${(r.trat||'—').slice(0,14)}</td>
        <td style="padding:5px;"><span class="chip ${cls}">${est}</span></td>
      </tr>`
    }).join('')}</tbody>
  </table>`
}

// ── Score ─────────────────────────────────────────────────
async function cargarScore(s) {
  try {
    const sel = document.getElementById('score-mes')
    const val = sel?.value
    const now = new Date()
    const mes = val ? parseInt(val.split('-')[1],10) : now.getMonth()+1
    const anio = val ? parseInt(val.split('-')[0],10) : now.getFullYear()
    const mesStr = `${anio}-${String(mes).padStart(2,'0')}-01`
    const mesKey = `${anio}-${String(mes).padStart(2,'0')}`
    const esActual = mes === now.getMonth()+1 && anio === now.getFullYear()

    const d = await rpc('aos_panel_asesor', {
      p_asesor: s.nombre.toUpperCase(),
      p_id_asesor: s.codigo_asesor,
      p_hoy: new Date().toISOString().slice(0,10),
      p_mes_inicio: mesStr
    })

    let ll, cc, vv, ff
    if (esActual) {
      ll = Number(d.llamMes)||0; cc = Number(d.citasMes)||0
      vv = Number(d.ventasMes)||0; ff = parseFloat(d.factMes)||0
    } else {
      const rM = (d.resumenAnual||[]).find(r => String(r.mesKey||'').slice(0,7) === mesKey)
      const vM = (d.ventasAnual||[]).find(v => String(v.mesKey||'').slice(0,7) === mesKey)
      ll = rM ? Number(rM.llamadas) : 0; cc = rM ? Number(rM.citas) : 0
      vv = vM ? Number(vM.ventas) : 0; ff = vM ? parseFloat(vM.fact)||0 : 0
    }

    set('sc-llam',   ll)
    set('sc-citas',  cc)
    set('sc-ventas', vv)
    set('sc-fact',   ff > 0 ? 'S/' + ff.toFixed(0) : 'S/0')
    renderTipifBars(d.tipifMes || [])
  } catch(e) { console.error('Score:', e) }
}

// ── Anual ─────────────────────────────────────────────────
async function cargarAnual(s) {
  const el = document.getElementById('tabla-anual')
  if (!el) return
  try {
    const anio = new Date().getFullYear()
    const d = await rpc('aos_historico_asesor_anual', {
      p_asesor: s.nombre.toUpperCase(),
      p_id_asesor: s.codigo_asesor,
      p_anio: anio
    })
    const meses = d?.meses || []
    const MNOM = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic']
    el.innerHTML = `<table style="width:100%;border-collapse:collapse;">
      <thead><tr style="background:#F0F4FC;">
        <th style="padding:3px 6px;text-align:left;font-size:8px;color:#9AAAC8;font-weight:700;">Mes</th>
        <th style="padding:3px 6px;text-align:right;font-size:8px;color:#9AAAC8;font-weight:700;">Llam</th>
        <th style="padding:3px 6px;text-align:right;font-size:8px;color:#9AAAC8;font-weight:700;">Citas</th>
        <th style="padding:3px 6px;text-align:right;font-size:8px;color:#9AAAC8;font-weight:700;">S/</th>
      </tr></thead>
      <tbody>${meses.map(m => {
        const bg = m.es_actual ? 'background:#EBF2FF;' : ''
        return `<tr style="border-bottom:1px solid #F0F4FC;${bg}">
          <td style="padding:3px 6px;font-weight:700;font-size:9px;">${MNOM[(m.mes_num-1)||0]}${m.es_actual?'●':''}</td>
          <td style="padding:3px 6px;text-align:right;font-size:9px;">${m.llamadas||0}</td>
          <td style="padding:3px 6px;text-align:right;font-size:9px;">${m.citas||0}</td>
          <td style="padding:3px 6px;text-align:right;font-size:9px;font-weight:700;color:#0A4FBF;">${m.fact>0?'S/'+parseFloat(m.fact).toFixed(0):'—'}</td>
        </tr>`
      }).join('')}</tbody>
    </table>`
  } catch(e) { el.innerHTML = '<div class="ld">Sin datos</div>' }
}

// ── Tipif bars ────────────────────────────────────────────
function renderTipifBars(tipifMes) {
  const el = document.getElementById('tipif-bars')
  if (!el) return
  const total = tipifMes.reduce((s,t) => s + Number(t.cnt||0), 0) || 1
  const cols = {
    'CITA CONFIRMADA':'#16A34A','SIN CONTACTO':'#DC2626',
    'NO LE INTERESA':'#7C3AED','SEGUIMIENTO':'#0A4FBF',
    'PROVINCIA':'#D97706','SACAR DE LA BASE':'#9AAAC8'
  }
  const sorted = [...tipifMes].sort((a,b) => (b.cnt||0)-(a.cnt||0))
  el.innerHTML = sorted.map(t => {
    const pct = Math.round(Number(t.cnt||0)/total*100)
    const col = cols[t.estado] || '#9AAAC8'
    return `<div style="display:flex;align-items:center;gap:6px;margin-bottom:4px;">
      <div style="font-size:8px;color:#6B7BA8;min-width:70px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${t.estado||'—'}</div>
      <div style="flex:1;background:#F0F4FC;border-radius:2px;height:10px;overflow:hidden;">
        <div style="width:${pct}%;height:100%;background:${col};border-radius:2px;"></div>
      </div>
      <div style="font-size:9px;font-weight:700;color:#0D1B3E;min-width:18px;text-align:right;">${t.cnt||0}</div>
    </div>`
  }).join('') || '<div class="ld">Sin llamadas</div>'
}

// ── Guardar llamada ───────────────────────────────────────
async function guardar() {
  if (STATE.guardando || !STATE.lead) return
  const tipif = document.getElementById('cc-tipif')?.value
  if (!tipif) { alert('Selecciona una tipificación'); return }
  if (tipif === 'CITA CONFIRMADA' || tipif === 'SEGUIMIENTO') return

  STATE.guardando = true
  const btn = document.getElementById('cc-guardar')
  btn.textContent = 'Guardando...'
  btn.disabled = true

  try {
    const s = session.get()
    // Por ahora llama al GAS para la escritura en Sheets
    // TODO: migrar escritura directo a Supabase cuando eliminemos Sheets
    const payload = {
      numero:     STATE.lead.num,
      estado:     tipif,
      subEstado:  tipif === 'SIN CONTACTO' ? STATE.subTipif : '',
      obs:        document.getElementById('cc-obs')?.value?.trim() || '',
      tratamiento: STATE.lead.trat,
      rowNum:     0
    }
    // Insertar directo en Supabase (aos_llamadas)
    await insertLlamada(s, payload)

    document.getElementById('cc-tipif').value = ''
    document.getElementById('cc-obs').value = ''
    document.getElementById('sub-tipif').style.display = 'none'

    // Recargar datos
    await Promise.all([cargarKPIs(s), cargarSiguienteLead(s)])

  } catch(e) {
    console.error('Guardar:', e)
    alert('Error al guardar')
  }
  STATE.guardando = false
  btn.textContent = '✓ Guardar resultado'
  btn.disabled = false
}

async function insertLlamada(s, p) {
  const hoy = new Date().toISOString().slice(0,10)
  const hora = new Date().toISOString()
  const res = await fetch(`https://ituyqwstonmhnfshnaqz.supabase.co/rest/v1/aos_llamadas`, {
    method: 'POST',
    headers: {
      'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0',
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal'
    },
    body: JSON.stringify({
      fecha:          hoy,
      hora_llamada:   hora,
      numero_limpio:  p.numero,
      asesor:         s.nombre.toUpperCase(),
      id_asesor:      s.codigo_asesor,
      tratamiento:    p.tratamiento,
      estado:         p.estado,
      sub_estado:     p.subEstado || null,
      observacion:    p.obs || null,
    })
  })
  if (!res.ok) {
    const err = await res.text()
    throw new Error(err)
  }
}

// ── Helpers ───────────────────────────────────────────────
function onTipif(val) {
  const sub = document.getElementById('sub-tipif')
  if (val === 'SIN CONTACTO') {
    sub.style.display = 'block'
    STATE.subTipif = 'NO CONTESTA'
  } else {
    sub.style.display = 'none'
  }
}

function setSubTipif(val) {
  STATE.subTipif = val
  document.querySelectorAll('.sub-opt').forEach(b => {
    b.classList.toggle('act', b.dataset.v === val)
  })
}

function poblarMeses() {
  const sel = document.getElementById('score-mes')
  if (!sel) return
  const MNOM = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic']
  const now = new Date()
  let html = ''
  for (let i = 0; i < 12; i++) {
    const d = new Date(now.getFullYear(), now.getMonth()-i, 1)
    const v = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`
    html += `<option value="${v}"${i===0?' selected':''}>${MNOM[d.getMonth()].toUpperCase()} ${d.getFullYear()}</option>`
  }
  sel.innerHTML = html
}

function set(id, val) {
  const el = document.getElementById(id)
  if (el) el.textContent = val
}

// ── Exportar ──────────────────────────────────────────────
export function CallCenterPage() {
  const s = session.get()
  return AsesorShell(template(), 'callcenter')
}
