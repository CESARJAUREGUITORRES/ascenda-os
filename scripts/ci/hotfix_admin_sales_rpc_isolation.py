#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
P = ROOT / 'app/public/admin-sales.html'
text = P.read_text(encoding='utf-8')

old = """var SB='https://ituyqwstonmhnfshnaqz.supabase.co',SK='"""
if old not in text:
    if "var VS_SB='https://ituyqwstonmhnfshnaqz.supabase.co',VS_SK='" in text:
        print('ADMIN_SALES_RPC_ISOLATION=ALREADY_APPLIED')
        raise SystemExit(0)
    raise SystemExit('ADMIN_SALES_RPC_ISOLATION=FAIL: legacy SB/SK declaration not found')

text = text.replace("var SB='https://ituyqwstonmhnfshnaqz.supabase.co',SK='", "var VS_SB='https://ituyqwstonmhnfshnaqz.supabase.co',VS_SK='", 1)

old_rpc = "function rpc(fn,p,ok){fetch(SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json'},body:JSON.stringify(p||{})}).then(function(r){return r.json();}).then(ok||function(){}).catch(function(e){console.error(fn,e);});}"
new_rpc = "function rpc(fn,p,ok){fetch(VS_SB+'/rest/v1/rpc/'+fn,{method:'POST',headers:{'apikey':VS_SK,'Authorization':'Bearer '+VS_SK,'Content-Type':'application/json'},body:JSON.stringify(p||{}),cache:'no-store'}).then(function(r){return r.json().then(function(b){if(!r.ok||!b||b.code||b.error)throw new Error((b&&(b.message||b.error||b.code))||('HTTP '+r.status));return b;});}).then(ok||function(){}).catch(function(e){console.error('Ventas RPC '+fn,e);var f=el('vs-fact');if(f)f.textContent='Error de lectura';var tb=el('vs-tb');if(tb)tb.innerHTML='<tr><td colspan=\"10\" class=\"ld\">No se pudieron cargar las ventas. Reintenta o recarga el panel.</td></tr>';});}"
if old_rpc not in text:
    raise SystemExit('ADMIN_SALES_RPC_ISOLATION=FAIL: rpc helper source shape changed')
text = text.replace(old_rpc, new_rpc, 1)

old_rest = "function rest(p,o){return fetch(SB+'/rest/v1/'+p,Object.assign({headers:{'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json','Prefer':'return=minimal'}},o||{}));}"
new_rest = "function rest(p,o){return fetch(VS_SB+'/rest/v1/'+p,Object.assign({headers:{'apikey':VS_SK,'Authorization':'Bearer '+VS_SK,'Content-Type':'application/json','Prefer':'return=minimal'},cache:'no-store'},o||{}));}"
if old_rest not in text:
    raise SystemExit('ADMIN_SALES_RPC_ISOLATION=FAIL: rest helper source shape changed')
text = text.replace(old_rest, new_rest, 1)

# Prevent UTC rollover from defining "Hoy". The monthly view is unaffected, but this
# keeps the same Lima business-day contract as Admin Home.
old_today = "var hoyStr=new Date().toISOString().slice(0,10);"
new_today = "var hoyStr=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());"
if old_today in text:
    text = text.replace(old_today, new_today, 1)

P.write_text(text, encoding='utf-8')
print('ADMIN_SALES_RPC_ISOLATION=PASS')
