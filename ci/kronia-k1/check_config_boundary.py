from pathlib import Path

config=Path('app/public/admin-config.html').read_text(encoding='utf-8')
rail=Path('app/railway.json').read_text(encoding='utf-8')
fail=[]

def req(needle,label):
    if needle not in config: fail.append('MISSING: '+label)

req('K1 SECURITY CONFIG BOUNDARY','config shim installed')
req('aos_kronia_admin_config_safe','config writes use token-bound gateway')
req("raw.indexOf('/rest/v1/aos_configuracion')>=0",'config table mutations intercepted')
req("['POST','PATCH','PUT','DELETE']",'all config mutation verbs covered')
req('CONFIG_DELETE_NOT_ALLOWED','direct config delete rejected')
req('p_clave:key','config key explicitly bound')
req('p_valor:String(value)','config value explicitly bound')
if 'k1_config_boundary.py' not in rail: fail.append('MISSING: Railway config materializer')

if fail:
    print('KRONIA_K1_CONFIG_UI_CONTRACT=FAIL')
    for x in fail: print(' -',x)
    raise SystemExit(1)
print('KRONIA_K1_CONFIG_UI_CONTRACT=PASS')
