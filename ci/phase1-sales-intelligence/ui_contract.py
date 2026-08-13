from pathlib import Path
import re

page = Path('app/public/admin-sales-intelligence.html').read_text(encoding='utf-8')
staging = Path('app/public/admin-sales-intelligence-staging.html').read_text(encoding='utf-8')

required_ids = [
    'si-fact','si-meta','si-pct','si-gap','si-ticket','si-sales','si-best','si-avg',
    'si-chart','si-proj','si-mtd','si-prev','si-delta','si-tbody','si-year','si-sede'
]
for rid in required_ids:
    assert f'id="{rid}"' in page, f'missing UI contract id: {rid}'

assert 'aos_sales_intelligence_summary' in page
assert "fetch('admin-sales-intelligence.html'" in staging
assert 'window.__ASCENDA_STAGING_FIXTURE__=true' in staging
assert '555373.27' in staging
assert '800000' in staging
assert '56948.80' in staging
assert '32839.05' in staging
assert '73.42' in staging
assert '147117.73' in staging
assert '2265.85' in staging

for forbidden in ['INSERT INTO aos_ventas','UPDATE aos_ventas','DELETE FROM aos_ventas','TRUNCATE aos_ventas']:
    assert forbidden.lower() not in page.lower()
    assert forbidden.lower() not in staging.lower()

assert staging.count('.supabase.co') == 0, 'staging harness must not contain a Supabase hostname'
assert '/rest/v1/rpc/aos_sales_intelligence_summary' in staging
assert re.search(r'for\(var i=9;i<=12;i\+\+\)', staging), 'fixture must expose 12 months'

print('PHASE1_UI_CONTRACT=PASS')
