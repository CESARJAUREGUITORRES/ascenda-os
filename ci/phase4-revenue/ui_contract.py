from pathlib import Path

root = Path(__file__).resolve().parents[2]
bridge = (root / 'app/public/f4-revenue-ops.js').read_text(encoding='utf-8')
kronia = (root / 'app/public/f4-kronia-revenue-bridge.js').read_text(encoding='utf-8')
canary = (root / 'app/public/f4-production-canary-hotfix.js').read_text(encoding='utf-8')
sw = (root / 'app/public/phase2-service-worker.js').read_text(encoding='utf-8')
app_shell = (root / 'app/public/app.html').read_text(encoding='utf-8')
proxy = (root / 'app/server-f4.js').read_text(encoding='utf-8')
railway = (root / 'app/railway.json').read_text(encoding='utf-8')
wa2_path = root / 'app/server-wa2.js'
wa2 = wa2_path.read_text(encoding='utf-8') if wa2_path.exists() else ''
wa3_path = root / 'app/server-wa3.js'
wa3 = wa3_path.read_text(encoding='utf-8') if wa3_path.exists() else ''
wa3v2_path = root / 'app/server-wa3-v2.js'
wa3v2 = wa3v2_path.read_text(encoding='utf-8') if wa3v2_path.exists() else ''
wa4_path = root / 'app/server-wa4.js'
wa4 = wa4_path.read_text(encoding='utf-8') if wa4_path.exists() else ''
f5_path = root / 'app/server-f5.js'
f5 = f5_path.read_text(encoding='utf-8') if f5_path.exists() else ''
f17_path = root / 'app/server-f17.js'
f17 = f17_path.read_text(encoding='utf-8') if f17_path.exists() else ''
phase_s_path = root / 'app/server-phase-s.js'
phase_s = phase_s_path.read_text(encoding='utf-8') if phase_s_path.exists() else ''
s152_path = root / 'app/server-phase-s-f17.js'
s152 = s152_path.read_text(encoding='utf-8') if s152_path.exists() else ''
core = (root / 'supabase/migrations/20260814223000_f4_revenue_operations_core_v1.sql').read_text(encoding='utf-8')
cartera_auth = (root / 'supabase/migrations/20260815191500_f4_cartera_gateway_v2_auth_chain_hotfix.sql').read_text(encoding='utf-8')

required_bridge = [
    'aos_sales_admin_gateway_v4', 'aos_sales_admin_sale_v4', 'aos_editar_venta_v4',
    'aos_importar_ventas_preview_v4', 'aos_importar_ventas_v4', 'aos_grabar_venta_caja_v4',
    '/api/f4/cartera-candidates', 'aos_cartera_reconcile_v2', 'canonicalProductName',
    'physicalQty', 'productResolutionStatus', 'REVIEW_REQUIRED', 'PAGO_RECONCILIADO',
    'importApproval', 'carteraCandidateByCase'
]
for marker in required_bridge:
    assert marker in bridge, f'missing F4 bridge marker: {marker}'
assert '/f4-revenue-ops.js' in sw
assert '/f4-kronia-revenue-bridge.js' in sw
assert 'ASCENDA_CRITICAL_RUNTIME_BRIDGES_20260820' in app_shell, 'critical F4/Patient bridges must have a deterministic app-shell marker'
assert '/f4-revenue-ops.js?v=20260820-rev-runtime-hotfix-v1' in app_shell, 'F4 bridge must load directly from app shell, not only through service-worker rewriting'
assert '/f4-kronia-revenue-bridge.js?v=20260820-rev-runtime-hotfix-v1' in app_shell, 'KronIA/F4 bridge must stay paired when direct F4 loading disables SW pair injection'
assert '/f4-production-canary-hotfix.js?v=20260820-rev-runtime-hotfix-v1' in app_shell, 'F4 strong-session recovery must load directly with revenue bridge'
assert "rm[1]==='aos_importar_ventas'" in sw, 'legacy sales import must have a controlled stale-shell safety net'
assert "rpcFrom(req,'aos_importar_ventas_v4'" in sw, 'stale-shell import fallback must route only to tokenized V4 importer'
assert "F4_APP_SESSION_REQUIRED" in sw, 'stale-shell import fallback must fail closed without controlled app token'
assert "var CARTERA={aos_cartera_gateway:'aos_cartera_gateway_v2'}" not in sw, 'Cartera reads must not be re-proxied by the service worker'
assert 'CARTERA[rm[1]]' not in sw, 'Cartera service-worker interception must remain absent'
assert 'select public.aos_cartera_gateway_v2(' in cartera_auth, 'DB compatibility alias must route legacy Cartera read to Auth V3 V2'
assert "'/api/kronia/chat'" in kronia and 'X-AOS-App-Token' in kronia
assert "body.confirmar_accion.rpc==='aos_editar_venta'" in proxy
assert 'F4_STRONG_SESSION_REQUIRED' in proxy
assert 'aos_sales_admin_sale_v4' in proxy and 'aos_editar_venta_v4' in proxy
assert "pathname==='/api/f4/cartera-candidates'" in proxy
assert 'aos_cartera_candidates_v2' in proxy

# P0.6 incident regression: all F4 writes must recover the same Auth V3 app token
# already cached by the Phase 2 login flow before the synchronous F4 bridge reads it.
assert "caches.open('aos-phase2-auth')" in canary, 'F4 canary must read the canonical Phase 2 app-token cache'
assert "sessionStorage.setItem('aos_app_token',t)" in canary, 'F4 canary must synchronize canonical app token into legacy synchronous bridge storage'
assert "name==='aos_editar_venta'||name==='aos_importar_ventas'||name==='aos_grabar_venta_caja'" in canary, 'governed F4 writes must synchronize canonical token before delegation'
assert 'return syncCanonicalAppToken().then' in canary, 'F4 write delegation must await canonical token synchronization'
assert "text.indexOf('CONFIRMAR IMPORTACIÓN DE VENTAS')===0" in canary, 'legacy importer confirmation must be identified exactly'
assert 'window.__AOS_F4_REVENUE_OPS__' in canary, 'legacy confirmation suppression must only happen when F4 V4 bridge is active'
assert 'return nativeConfirm(message)' in canary, 'native confirmations outside F4 import must remain untouched'
assert 'Validación previa · Importar ventas' in bridge, 'V4 preview must remain the single authoritative import approval UI'

# P0.7 editor truth regression: values stored in production must never be silently
# replaced by the first hard-coded <select> option when the legacy list is incomplete.
assert "typeof window.evCampoSel!=='function'||window.evCampoSel.__f4TruthSafe" in canary, 'sales editor select wrapper must be idempotent'
assert "var current=String(val==null?'':val)" in canary, 'sales editor must preserve the exact current production value including empty values'
assert 'if(list.indexOf(current)<0)list.unshift(current)' in canary, 'unknown current sales values must be injected into the editor options instead of falling back'
assert 'window.evCampoSel=safe' in canary, 'truth-safe sales editor selector must replace the incomplete legacy selector'
assert 'safe.__f4TruthSafe=true' in canary, 'sales editor truth wrapper must publish an idempotency marker'

# WA-3 V2 is an additive wrapper between WA-4 and the certified WA-3 V1 authority.
wa4_to_wa3 = (
    ("['server-wa3.js']" in wa4 and 'proxy(req,res)' in wa4)
    or (
        "['server-wa3-v2.js']" in wa4 and 'proxy(req,res)' in wa4
        and "['server-wa3.js']" in wa3v2 and 'proxy(req,res)' in wa3v2
    )
)

direct_f4 = 'node server-f4.js' in railway
wa2_wrapped_f4 = 'node server-wa2.js' in railway and "['server-f4.js']" in wa2 and 'proxy(req,res)' in wa2
wa3_wrapped_chain = (
    'node server-wa3.js' in railway
    and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3
    and "['server-f4.js']" in wa2 and 'proxy(req,res)' in wa2
)
wa4_wrapped_chain = (
    'node server-wa4.js' in railway
    and wa4_to_wa3
    and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3
    and "['server-f4.js']" in wa2 and 'proxy(req,res)' in wa2
)
f5_wrapped_chain = (
    'node server-f5.js' in railway
    and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5
    and wa4_to_wa3
    and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3
    and "['server-f4.js']" in wa2 and 'proxy(req,res)' in wa2
)
phase_s_wrapped_chain = (
    'node server-phase-s.js' in railway
    and "['server-f5.js']" in phase_s and 'proxy(req,res)' in phase_s
    and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5
    and wa4_to_wa3
    and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3
    and "['server-f4.js']" in wa2 and 'proxy(req,res)' in wa2
)
s152_wrapped_chain = (
    'node server-phase-s-f17.js' in railway
    and "a[0]==='server-f5.js'" in s152 and "a[0]='server-f17.js'" in s152 and "require('./server-phase-s.js')" in s152
    and "['server-f5.js']" in phase_s and 'proxy(req,res)' in phase_s
    and "['server-f5.js']" in f17
    and "['server-wa4.js']" in f5 and 'proxy(req,res)' in f5
    and wa4_to_wa3
    and "['server-wa2.js']" in wa3 and 'proxy(req,res)' in wa3
    and "['server-f4.js']" in wa2 and 'proxy(req,res)' in wa2
)
assert direct_f4 or wa2_wrapped_f4 or wa3_wrapped_chain or wa4_wrapped_chain or f5_wrapped_chain or phase_s_wrapped_chain or s152_wrapped_chain, 'Railway must preserve certified F4 chain through explicit WA/F5/Phase-S/F17 wrappers'
assert 'node server-phase2.js' not in railway.split('"environments"')[0]
for text in (bridge,kronia): assert 'service_role' not in text.lower()
assert 'SUPABASE_SERVICE_ROLE_KEY' in proxy
assert 'delete childEnv.SUPABASE_SERVICE_ROLE_KEY' in proxy
for marker in ('delete childEnv.WHATSAPP_VERIFY_TOKEN','delete childEnv.WHATSAPP_APP_SECRET','delete childEnv.WHATSAPP_ACCESS_TOKEN','delete childEnv.WHATSAPP_PHONE_NUMBER_ID','delete childEnv.WHATSAPP_GRAPH_VERSION','delete childEnv.WA_CANARY_MODE','delete childEnv.WA_CANARY_ALLOW_TO'):
    assert marker in proxy, f'missing secret isolation marker: {marker}'
assert "'rawDescription',e->>'descripcion'" in core
assert "'rawDescription',v.descripcion" in core
assert "'canonicalProductName'" in core
cartera_page = (root / 'app/public/admin-cartera.html').read_text(encoding='utf-8')
si_page = (root / 'app/public/admin-sales-intelligence.html').read_text(encoding='utf-8')
assert "pathname==='/api/f4/cartera-read'" in proxy and "pathname==='/api/f4/sales-intelligence-read'" in proxy, 'F4 same-origin sensitive-read transport routes missing'
assert "rpcName='aos_cartera_gateway'" in proxy and "rpcName='aos_sales_intelligence_gateway'" in proxy, 'F4 same-origin read RPC routing missing'
assert 'const appToken=strongToken(req)' in proxy and 'F4_STRONG_SESSION_REQUIRED' in proxy, 'F4 same-origin read must require strong app token'
assert "'/api/f4/cartera-read'" in cartera_page and "'X-AOS-App-Token':t" in cartera_page, 'Cartera same-origin transport missing'
assert "caches.open('aos-phase2-auth')" in cartera_page, 'Cartera cache recovery missing'
assert "'/api/f4/sales-intelligence-read'" in si_page and "'X-AOS-App-Token':token" in si_page, 'Sales Intelligence same-origin transport missing'
assert "caches.open('aos-phase2-auth')" in si_page, 'Sales Intelligence cache recovery missing'
assert "api('aos_cartera_gateway'" not in cartera_page, 'Cartera direct PostgREST read must remain absent'
assert "fetch(SB+'/rest/v1/rpc/aos_sales_intelligence_gateway'" not in si_page, 'SI direct PostgREST read must remain absent'
print('F4 UI/runtime contract PASS')
