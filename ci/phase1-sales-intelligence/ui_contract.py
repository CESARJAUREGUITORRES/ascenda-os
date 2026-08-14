from pathlib import Path
import re

page = Path('app/public/admin-sales-intelligence.html').read_text(encoding='utf-8')
staging = Path('app/public/admin-sales-intelligence-staging.html').read_text(encoding='utf-8')
shell = Path('app/public/app.html').read_text(encoding='utf-8')
login = Path('app/public/login.html').read_text(encoding='utf-8')
team = Path('app/public/admin-team.html').read_text(encoding='utf-8')

required_ids = [
    'si-fact','si-meta','si-pct','si-gap','si-ticket','si-sales','si-best','si-avg',
    'si-chart','si-proj','si-mtd','si-prev','si-delta','si-tbody','si-year','si-sede'
]
for rid in required_ids:
    assert f'id="{rid}"' in page, f'missing UI contract id: {rid}'

assert 'aos_sales_intelligence_gateway' in page
assert 'aos_sales_intelligence_summary' not in page
assert "sessionStorage.getItem('aos_si_token')" in page
assert 'ACTIVO · SOLO LECTURA' in page
assert 'Acceso restringido' in page

assert "fetch('admin-sales-intelligence.html'" in staging
assert 'window.__ASCENDA_STAGING_FIXTURE__=true' in staging
assert 'aos_sales_intelligence_gateway' in staging
assert 'aos_sales_intelligence_summary' not in staging
assert '556097.27' in staging
assert '800000' in staging
assert '57672.80' in staging
assert '35493.05' in staging
assert '62.49' in staging
assert '137527.45' in staging
assert '2351.51' in staging

for forbidden in ['INSERT INTO aos_ventas','UPDATE aos_ventas','DELETE FROM aos_ventas','TRUNCATE aos_ventas']:
    assert forbidden.lower() not in page.lower()
    assert forbidden.lower() not in staging.lower()

assert staging.count('.supabase.co') == 0, 'staging harness must not contain a Supabase hostname'
assert '/rest/v1/rpc/aos_sales_intelligence_gateway' in staging
assert re.search(r'for\(var i=9;i<=12;i\+\+\)', staging), 'fixture must expose 12 months'

assert 'var _APP_VERSION = 20260814.2;' in shell, 'shell cache version must force activation'
assert 'function revalidateAdminSessionContext()' in shell
assert "id:'admin-sales-intelligence'" in shell
assert 'requiresPanel:true' in shell
assert 'canaryNivel' not in shell
assert "perms.indexOf(it.id) >= 0" in shell
assert "sessionStorage.removeItem('aos_si_token')" in shell

assert 'aos_sales_intelligence_claim_session' in login
assert "sessionStorage.setItem('aos_si_token'" in login
assert 'si_session_claimed' in login

assert 'aos_sales_intelligence_set_access' in team
assert 'TARGET_ADMIN_2FA_REQUIRED' in team
assert "d.rol=d.nivel_jerarquia<=2?'admin'" in team
assert "ps.indexOf('admin-sales-intelligence')" in team

print('PHASE1_UI_CONTRACT=PASS')
