from pathlib import Path

root = Path(__file__).resolve().parents[2]
app = (root / 'app/public/app.html').read_text(encoding='utf-8')
cartera = (root / 'app/public/admin-cartera.html').read_text(encoding='utf-8')
caja = (root / 'app/public/caja.html').read_text(encoding='utf-8')
migration = (root / 'supabase/migrations/20260814034401_cartera_phase2_reconciliation.sql').read_text(encoding='utf-8')

assert "id:'admin-cartera'" in app
assert "requiresPanel:true" in app
assert "'admin-cartera':'ViewAdminCartera'" in app
assert "'ViewAdminCartera':     '/admin-cartera.html'" in app
assert "viewId === 'admin-cartera'" in app

assert "aos_cartera_gateway" in cartera
assert "aos_cartera_reconcile" in cartera
assert "aos_si_token" in cartera
assert "RECORDATORIOS BLOQUEADOS" in cartera
assert "Adelantos ≠ deuda" in cartera

assert "rpc('aos_abonar_cotizacion_v2'" in caja
assert "p_token: financeToken" in caja
assert "rpc('aos_abonar_cotizacion'," not in caja

assert "enable row level security" in migration.lower()
assert "revoke all on table public.aos_cartera_reconciliacion" in migration.lower()
assert "set search_path = ''" in migration
assert "for update;" in migration.lower()
assert "'OVERPAYMENT'" in migration
assert "'SERVICIO'" in migration
assert "reminder" not in migration.lower()

print('CARTERA_PHASE2_UI_CONTRACT=PASS')
