from pathlib import Path

root = Path(__file__).resolve().parents[2]
bridge = (root / 'app/public/f4-revenue-ops.js').read_text(encoding='utf-8')
kronia = (root / 'app/public/f4-kronia-revenue-bridge.js').read_text(encoding='utf-8')
sw = (root / 'app/public/phase2-service-worker.js').read_text(encoding='utf-8')
proxy = (root / 'app/server-f4.js').read_text(encoding='utf-8')
railway = (root / 'app/railway.json').read_text(encoding='utf-8')
core = (root / 'supabase/migrations/20260814223000_f4_revenue_operations_core_v1.sql').read_text(encoding='utf-8')

required_bridge = [
    'aos_sales_admin_gateway_v4', 'aos_sales_admin_sale_v4', 'aos_editar_venta_v4',
    'aos_importar_ventas_preview_v4', 'aos_importar_ventas_v4', 'aos_grabar_venta_caja_v4',
    '/api/f4/cartera-candidates', 'aos_cartera_reconcile_v2', 'canonicalProductName',
    'physicalQty', 'productResolutionStatus', 'REVIEW_REQUIRED', 'PAGO_RECONCILIADO',
    'importApproval', 'carteraCandidateByCase'
]
for marker in required_bridge:
    assert marker in bridge, f'missing F4 bridge marker: {marker}'

assert '/f4-revenue-ops.js' in sw, 'service worker must inject F4 revenue bridge'
assert '/f4-kronia-revenue-bridge.js' in sw, 'service worker must inject KronIA revenue proof bridge'
assert "'/api/kronia/chat'" in kronia and 'X-AOS-App-Token' in kronia
assert "body.confirmar_accion.rpc==='aos_editar_venta'" in proxy
assert 'F4_STRONG_SESSION_REQUIRED' in proxy
assert 'aos_sales_admin_sale_v4' in proxy and 'aos_editar_venta_v4' in proxy
assert "pathname==='/api/f4/cartera-candidates'" in proxy
assert 'aos_cartera_candidates_v2' in proxy
assert 'node server-f4.js' in railway
assert 'node server-phase2.js' not in railway.split('"environments"')[0]

# F4 never embeds service-role credentials in browser/runtime bridges.
for text in (bridge, kronia, proxy):
    assert 'service_role' not in text.lower()

# Raw evidence preservation belongs to the DB read model. The browser consumes the
# enriched payload transparently, so do not require a dead marker in the bridge.
assert "'rawDescription',e->>'descripcion'" in core
assert "'rawDescription',v.descripcion" in core
assert "'canonicalProductName'" in core
print('F4 UI/runtime contract PASS')
