from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
app = (root / 'app/public/app.html').read_text(encoding='utf-8')
cartera = (root / 'app/public/admin-cartera.html').read_text(encoding='utf-8')
caja = (root / 'app/public/caja.html').read_text(encoding='utf-8')
migration = (root / 'supabase/migrations/20260814034401_cartera_phase2_reconciliation.sql').read_text(encoding='utf-8')

assert re.search(r"id\s*:\s*['\"]admin-cartera['\"]", app)
assert re.search(r"admin-cartera[\s\S]{0,220}requiresPanel\s*:\s*true", app)
assert re.search(r"['\"]admin-cartera['\"]\s*:\s*['\"]ViewAdminCartera['\"]", app)
assert re.search(r"['\"]ViewAdminCartera['\"]\s*:\s*['\"]/admin-cartera\.html['\"]", app)
assert re.search(r"viewId\s*===\s*['\"]admin-cartera['\"]", app)

assert "aos_cartera_gateway" in cartera
assert "aos_cartera_reconcile" in cartera
assert "p_expected_updated_at:current.updatedAt" in cartera
assert "aos_si_token" in cartera
assert "RECORDATORIOS BLOQUEADOS" in cartera
assert "Adelantos ≠ deuda" in cartera

assert "rpc('aos_abonar_cotizacion_v2'" in caja
assert re.search(r"p_token\s*:\s*financeToken", caja)
assert re.search(r"p_idempotency_key\s*:", caja)
assert "aos_caja_cotizaciones_gateway" in caja
assert not re.search(r"rpc\(['\"]aos_abonar_cotizacion['\"]", caja)
assert not re.search(r"sbGet\(['\"]aos_cotizaciones['\"]", caja)

assert "enable row level security" in migration.lower()
assert "revoke all on table public.aos_cartera_reconciliacion" in migration.lower()
assert "revoke all on table public.aos_cotizaciones" in migration.lower()
assert "revoke all on table public.aos_pagos" in migration.lower()
assert "set search_path = ''" in migration
assert "for update;" in migration.lower()
assert "request_id" in migration
assert "forbidden_sede" in migration.lower()
assert "stale_case" in migration.lower()
assert "'OVERPAYMENT'" in migration
assert "'SERVICIO'" in migration
assert "'remindersEnabled',false" in migration
assert "send-reminder" not in migration.lower()
assert "send-template" not in migration.lower()

print('CARTERA_PHASE2_UI_CONTRACT=PASS')
