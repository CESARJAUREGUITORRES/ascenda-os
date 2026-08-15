from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
app = (root / 'app/public/app.html').read_text(encoding='utf-8')
cartera = (root / 'app/public/admin-cartera.html').read_text(encoding='utf-8')
caja = (root / 'app/public/caja.html').read_text(encoding='utf-8')
migration = (root / 'supabase/migrations/20260814034401_cartera_phase2_reconciliation.sql').read_text(encoding='utf-8')
cleanup = (root / 'supabase/migrations/20260814050000_cartera_phase2_security_cleanup.sql').read_text(encoding='utf-8')
rollback = (root / 'supabase/rollbacks/20260814034401_cartera_phase2_reconciliation.rollback.sql').read_text(encoding='utf-8')
railway = (root / 'app/railway.json').read_text(encoding='utf-8')
phase2 = (root / 'app/server-phase2.js').read_text(encoding='utf-8')
f4 = (root / 'app/server-f4.js').read_text(encoding='utf-8') if (root/'app/server-f4.js').exists() else ''
wa2 = (root / 'app/server-wa2.js').read_text(encoding='utf-8') if (root/'app/server-wa2.js').exists() else ''
wa3 = (root / 'app/server-wa3.js').read_text(encoding='utf-8') if (root/'app/server-wa3.js').exists() else ''
wa4 = (root / 'app/server-wa4.js').read_text(encoding='utf-8') if (root/'app/server-wa4.js').exists() else ''

assert re.search(r"id\s*:\s*['\"]admin-cartera['\"]", app)
assert re.search(r"admin-cartera[\s\S]{0,220}requiresPanel\s*:\s*true", app)
assert re.search(r"['\"]admin-cartera['\"]\s*:\s*['\"]ViewAdminCartera['\"]", app)
assert re.search(r"['\"]ViewAdminCartera['\"]\s*:\s*['\"]/admin-cartera\.html['\"]", app)
assert re.search(r"viewId\s*===\s*['\"]admin-cartera['\"]", app)

assert "/api/f4/cartera-read" in cartera
assert "caches.open('aos-phase2-auth')" in cartera
assert "'X-AOS-App-Token':t" in cartera
assert "api('aos_cartera_gateway'" not in cartera
assert "pathname==='/api/f4/cartera-read'" in f4
assert "rpcName='aos_cartera_gateway'" in f4
assert "aos_cartera_reconcile" in cartera
assert "p_expected_updated_at:current.updatedAt" in cartera
assert "sessionStorage.getItem('aos_app_token')" in cartera
assert "aos_si_token" not in cartera
assert "RECORDATORIOS BLOQUEADOS" in cartera
assert "Adelantos ≠ deuda" in cartera

assert "rpc('aos_abonar_cotizacion_v2'" in caja
assert re.search(r"p_token\s*:\s*financeToken", caja)
assert re.search(r"p_idempotency_key\s*:", caja)
assert "aos_caja_cotizaciones_gateway" in caja
assert not re.search(r"rpc\(['\"]aos_abonar_cotizacion['\"]", caja)
assert not re.search(r"sbGet\(['\"]aos_cotizaciones['\"]", caja)
assert len(caja) > 150000
for anchor in ('id="ov-venta"', 'function cargarCaja(', 'function buscarPaciente(q)', 'function finalizarGrabado()'):
    assert anchor in caja
assert 'onclick="selPaciente(' not in caja
assert "row.addEventListener('click', function(){ selPaciente(p); })" in caja
assert 'JSON.stringify(r).replace(/"/g' not in caja
assert "row.addEventListener('click', function(){ agregarItemDesdeCatalogo(r); })" in caja
assert "row.addEventListener('click', function(){ cargarCotEnVenta(cot.id); })" in caja
assert "advisor.textContent = 'Asesor: ' + cot.asesor" in caja
assert "escH(plan.autor || '')" in caja
assert "escH(item.nombre || '')" in caja
assert "suggestion.textContent = value" in caja
assert "suggestion.addEventListener('click'" in caja
assert "badgeDetail.textContent = pendientes.length" in caja
assert "badge.addEventListener('click'" in caja
assert "precioVariante.toFixed(2)" in caja
assert "precioItem.toFixed(2)" in caja
assert "box.innerHTML='<div" not in caja
assert "badge.innerHTML = '<div style=\"display:flex;align-items:center;gap:8px;font-size:12px;\">'" not in caja
assert "(v.precio||0) + '</span>" not in caja
assert 'var abonoFailed = false' in caja
assert 'delete VT._paymentKeys[cotId]' not in caja
assert 'if (abonoFailed)' in caja

# Production runtime compatibility is explicit, not arbitrary wrapper acceptance.
prod = railway.split('"environments"')[0]
direct_phase2 = '"startCommand": "node server-phase2.js"' in prod
f4_chain = '"startCommand": "node server-f4.js"' in prod and "spawn(process.execPath,['server-phase2.js']" in f4
wa2_chain = ('"startCommand": "node server-wa2.js"' in prod and "['server-f4.js']" in wa2 and 'proxy(req,res)' in wa2 and "spawn(process.execPath,['server-phase2.js']" in f4)
wa3_chain = ('"startCommand": "node server-wa3.js"' in prod and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3 and "['server-f4.js']" in wa2 and 'proxy(req,res)' in wa2 and "spawn(process.execPath,['server-phase2.js']" in f4)
wa4_chain = ('"startCommand": "node server-wa4.js"' in prod and "['server-wa3.js']" in wa4 and 'proxy(req,res)' in wa4 and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3 and "['server-f4.js']" in wa2 and 'proxy(req,res)' in wa2 and "spawn(process.execPath,['server-phase2.js']" in f4)
assert direct_phase2 or f4_chain or wa2_chain or wa3_chain or wa4_chain, 'Cartera requires certified Phase2 runtime chain'
assert 'LEGACY_AUTH_ENDPOINT_RETIRED' in phase2

assert "enable row level security" in migration.lower()
assert "revoke all on table public.aos_cartera_reconciliacion" in migration.lower()
assert "revoke all on table public.aos_cotizaciones" in migration.lower()
assert "revoke all on table public.aos_pagos" in migration.lower()
assert "set search_path = ''" in migration
assert "for update;" in migration.lower()
assert "request_id" in migration
assert "request_hash" in migration
assert "registrado_por_user_id" in migration
assert "abierto_por_user_id" in migration
assert "BALANCE_MUST_MATCH_QUOTE" in migration
assert "aos_cartera_saldo_finite_chk" in migration
assert "aos_cartera_monto_finite_chk" in migration
assert "forbidden_sede" in migration.lower()
assert "stale_case" in migration.lower()
assert "'OVERPAYMENT'" in migration
assert "'SERVICIO'" in migration
assert "'remindersEnabled',false" in migration
assert "send-reminder" not in migration.lower()
assert "send-template" not in migration.lower()
assert re.search(r"drop function if exists public\.aos_cartera_reconcile\(\s*text,uuid,text,text,numeric,numeric,text,text,text\s*\)", cleanup, re.I)
assert re.search(r"drop function if exists public\.aos_abonar_cotizacion_v2\(\s*text,text,numeric,text,text,text,text,text,text,text,text,text\s*\)", cleanup, re.I)
assert "aos_sales_intelligence_access" in cleanup

assert "grant execute" not in rollback.lower()
assert not re.search(r"grant[\s\S]{0,120}\b(?:anon|authenticated)\b", rollback, re.I)
assert "revoke all on function public.aos_abonar_cotizacion_v2" in rollback.lower()
assert "rename to aos_cartera_reconciliacion_rollback_20260814" in rollback.lower()

print('CARTERA_PHASE2_UI_CONTRACT=PASS')
