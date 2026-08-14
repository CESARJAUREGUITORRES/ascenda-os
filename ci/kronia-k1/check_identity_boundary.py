from pathlib import Path

team=Path('app/public/admin-team.html').read_text(encoding='utf-8')
rail=Path('app/railway.json').read_text(encoding='utf-8')
fail=[]

def req(needle,label):
    if needle not in team: fail.append('MISSING: '+label)

def order(a,b,label):
    if a not in team or b not in team or team.index(a)>team.rindex(b): fail.append('ORDER: '+label)

req('K1 IDENTITY BOUNDARY — compatibility shim','identity shim installed')
req("aos_kronia_admin_identity_safe",'safe identity gateway used')
req("p_action:action",'gateway action is explicit')
req("p_target_user_id:targetId||null",'target identity is explicit')
req("p_params:params||{}",'gateway params are structured')
req("K1_RAW_FETCH",'original fetch preserved for non-identity contracts')
req("raw.indexOf('/rest/v1/aos_usuarios?')>=0 && method==='PATCH'",'direct usuarios PATCH intercepted')
req("raw.indexOf('/rest/v1/aos_rrhh?')>=0 && method==='PATCH'",'direct RRHH PATCH intercepted')
req("/rest/v1/rpc/aos_admin_cambiar_password",'legacy password RPC intercepted')
req("/rest/v1/rpc/aos_admin_crear_usuario",'legacy create-user RPC intercepted')
req("/rest/v1/rpc/aos_admin_cambiar_username",'legacy username RPC intercepted')
req("/rest/v1/rpc/aos_admin_toggle_usuario",'legacy toggle RPC intercepted')
req("/rest/v1/rpc/aos_admin_eliminar_usuario",'legacy delete RPC intercepted')
req("b.accion==='force_logout'",'force logout redirected to identity gateway')
req('Entregada por el administrador mediante canal seguro','credential emails are scrubbed')
req('Contraseña mínimo 8 caracteres','activation UI matches gateway password minimum')
order('K1 IDENTITY BOUNDARY — compatibility shim','loadTeam();','identity shim loads before Team bootstrap')

if 'k1_identity_boundary.py' not in rail:
    fail.append('MISSING: Railway identity materializer')

if fail:
    print('KRONIA_K1_IDENTITY_UI_CONTRACT=FAIL')
    for x in fail: print(' -',x)
    raise SystemExit(1)
print('KRONIA_K1_IDENTITY_UI_CONTRACT=PASS')
