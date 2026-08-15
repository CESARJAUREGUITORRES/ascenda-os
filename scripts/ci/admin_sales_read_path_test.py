#!/usr/bin/env python3
from pathlib import Path
p=Path(__file__).resolve().parents[2]/'app/public/admin-sales.html'
s=p.read_text(encoding='utf-8')
assert "var VS_SB='https://ituyqwstonmhnfshnaqz.supabase.co',VS_SK='" in s
assert "fetch(VS_SB+'/rest/v1/rpc/'" in s
assert "if(!r.ok||!b||b.code||b.error)" in s
assert "timeZone:'America/Lima'" in s
assert "fetch(SB+'/rest/v1/rpc/'" not in s
print('ADMIN_SALES_READ_PATH=PASS')
