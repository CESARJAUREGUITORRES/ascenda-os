from pathlib import Path

ROOT=Path('.')

# 1) Database: raw identity reads become a minimal directory; full Team data is token-gated.
p=ROOT/'supabase/migrations/20260814171000_kronia_k1_app_token_control_plane.sql'
s=p.read_text(encoding='utf-8')
marker='-- K1 CURRENT sensitive identity read boundary.'
block=r'''

-- K1 CURRENT sensitive identity read boundary.
-- Raw browser access is a minimal operational directory only. Full Team/PII
-- requires an Auth V3 app token, privileged admin identity and 2FA.
revoke all on table public.aos_usuarios from anon,authenticated;
grant select(id,codigo_asesor,nombre,apellidos,rol,cargo,area,sede,activo,cuenta_activada,two_factor,paneles_acceso,avatar_url,nivel_jerarquia,acceso_geo,sedes_permitidas,cmp,servicios)
  on public.aos_usuarios to anon,authenticated;
revoke all on table public.aos_rrhh from anon,authenticated;
grant select(codigo_asesor,nombre,apellido,puesto,sede,estado)
  on public.aos_rrhh to anon,authenticated;
revoke all on table public.aos_team_full from public,anon,authenticated;
grant select on table public.aos_team_full to service_role;

create or replace function public.aos_team_feed_v3(
  p_token text,
  p_cargo text default null,
  p_limit integer default 200
) returns jsonb
language plpgsql security definer set search_path=''
as $function$
declare v_i jsonb; v_rows jsonb; v_limit integer:=greatest(1,least(coalesce(p_limit,200),500));
begin
  v_i:=public.aos_kronia_identity_v3(p_token,true,'admin-team');
  if not coalesce((v_i->>'ok')::boolean,false) then return v_i; end if;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_rows
  from (
    select * from public.aos_team_full t
    where nullif(trim(coalesce(p_cargo,'')),'') is null or t.cargo=p_cargo
    order by t.nivel_jerarquia,t.nombre
    limit v_limit
  ) x;
  return jsonb_build_object('ok',true,'rows',v_rows);
end
$function$;
revoke all on function public.aos_team_feed_v3(text,text,integer) from public;
grant execute on function public.aos_team_feed_v3(text,text,integer) to anon,authenticated,service_role;
'''
if marker not in s:
    idx=s.rfind('\ncommit;')
    if idx<0: raise SystemExit('K1-B commit anchor missing')
    s=s[:idx]+block+s[idx:]
p.write_text(s,encoding='utf-8')

# 2) Browser compatibility: transparently route full Team reads through the secure feed.
p=ROOT/'app/public/k1-browser-security.js'
s=p.read_text(encoding='utf-8')
if "var SAFE_USER_COLUMNS=" not in s:
    s=s.replace("var SAFE_INTEGRATION_COLUMNS='id,tipo,nombre,cuenta,estado,principal,categoria,icono,descripcion,uso_para,orden,url_docs,url_signup,multi_cuenta,logo_url,created_at,updated_at';",
                "var SAFE_INTEGRATION_COLUMNS='id,tipo,nombre,cuenta,estado,principal,categoria,icono,descripcion,uso_para,orden,url_docs,url_signup,multi_cuenta,logo_url,created_at,updated_at';\n  var SAFE_USER_COLUMNS='id,codigo_asesor,nombre,apellidos,rol,cargo,area,sede,activo,cuenta_activada,two_factor,paneles_acceso,avatar_url,nivel_jerarquia,acceso_geo,sedes_permitidas,cmp,servicios';\n  var SAFE_RRHH_COLUMNS='codigo_asesor,nombre,apellido,puesto,sede,estado';")
helper=r'''
  function filterTeamRows(u,rows){
    rows=Array.isArray(rows)?rows.slice():[];
    ['id','codigo_asesor','cargo','sede','activo'].forEach(function(k){var v=u.searchParams.get(k)||'';if(v.indexOf('eq.')===0){v=decodeURIComponent(v.slice(3));rows=rows.filter(function(r){return String(r[k])===v})}});
    var sel=String(u.searchParams.get('select')||'*');
    if(sel&&sel!=='*'&&sel.indexOf('(')<0){var keys=sel.split(',').map(function(x){return x.trim()}).filter(Boolean);rows=rows.map(function(r){var o={};keys.forEach(function(k){if(Object.prototype.hasOwnProperty.call(r,k))o[k]=r[k]});return o})}
    var lim=Number(u.searchParams.get('limit')||500);if(Number.isFinite(lim)&&lim>0)rows=rows.slice(0,Math.min(lim,500));
    return rows;
  }
'''
if 'function filterTeamRows' not in s:
    anchor='  function targetIdFrom(u){'
    if anchor not in s: raise SystemExit('browser helper anchor missing')
    s=s.replace(anchor,helper+anchor,1)
route=r'''
    if(u.hostname.indexOf('supabase.co')>=0&&method==='GET'&&u.pathname==='/rest/v1/aos_team_full'){
      var cargo=(u.searchParams.get('cargo')||'').replace(/^eq\./,'');
      return rpcJson('aos_team_feed_v3',{p_token:token(),p_cargo:cargo?decodeURIComponent(cargo):null,p_limit:Number(u.searchParams.get('limit')||500)}).then(function(d){return resp(filterTeamRows(u,d.rows||[]),200)});
    }
    if(u.hostname.indexOf('supabase.co')>=0&&method==='GET'&&u.pathname==='/rest/v1/aos_usuarios'){
      return rpcJson('aos_team_feed_v3',{p_token:token(),p_cargo:null,p_limit:500}).then(function(d){return resp(filterTeamRows(u,d.rows||[]),200)}).catch(function(){u.searchParams.set('select',SAFE_USER_COLUMNS);return nativeFetch(u.toString(),init)});
    }
    if(u.hostname.indexOf('supabase.co')>=0&&method==='GET'&&u.pathname==='/rest/v1/aos_rrhh'){
      u.searchParams.set('select',SAFE_RRHH_COLUMNS);return nativeFetch(u.toString(),init);
    }
'''
if "u.pathname==='/rest/v1/aos_team_full'" not in s:
    anchor="    if(u.hostname.indexOf('supabase.co')>=0&&method==='GET'&&u.pathname==='/rest/v1/aos_agente_logs'){"
    if anchor not in s: raise SystemExit('browser route anchor missing')
    s=s.replace(anchor,route+'\n'+anchor,1)
p.write_text(s,encoding='utf-8')

# 3) Sales Intelligence admin action must use the one canonical Auth V3 app token.
p=ROOT/'app/public/admin-team.html'
s=p.read_text(encoding='utf-8')
s=s.replace("sessionStorage.getItem('aos_si_token')||''", "sessionStorage.getItem('aos_app_token')||''")
if 'aos_si_token' in s:
    raise SystemExit('admin-team alternate Sales Intelligence token authority survived')
p.write_text(s,encoding='utf-8')

# 4) SQL certificate: prove sensitive raw reads are closed and tokenized Team feed exists.
p=ROOT/'ci/kronia-k1-phase2/001_k1_phase2_certificate.sql'
s=p.read_text(encoding='utf-8')
cert=r'''

-- K1P2-CURRENT-PII: raw sensitive Team/identity reads must be closed.
do $$
declare j jsonb;
begin
  if has_table_privilege('anon','public.aos_team_full','SELECT') or has_table_privilege('authenticated','public.aos_team_full','SELECT') then
    raise exception 'K1P2-PII-01 aos_team_full remains browser-readable';
  end if;
  if has_table_privilege('anon','public.aos_usuarios','SELECT') or has_table_privilege('anon','public.aos_rrhh','SELECT') then
    raise exception 'K1P2-PII-02 raw identity table-level SELECT remains open';
  end if;
  if has_column_privilege('anon','public.aos_usuarios','sueldo','SELECT')
     or has_column_privilege('anon','public.aos_usuarios','dni','SELECT')
     or has_column_privilege('anon','public.aos_usuarios','direccion','SELECT')
     or has_column_privilege('anon','public.aos_usuarios','contacto_emergencia','SELECT')
     or has_column_privilege('anon','public.aos_rrhh','password_hash','SELECT') then
    raise exception 'K1P2-PII-03 sensitive identity columns remain browser-readable';
  end if;
  if not has_column_privilege('anon','public.aos_usuarios','id','SELECT')
     or not has_column_privilege('anon','public.aos_rrhh','codigo_asesor','SELECT') then
    raise exception 'K1P2-PII-04 minimal directory compatibility missing';
  end if;
  if not has_function_privilege('anon','public.aos_team_feed_v3(text,text,integer)','EXECUTE') then
    raise exception 'K1P2-PII-05 secure Team feed unavailable';
  end if;
  j:=public.aos_team_feed_v3('invalid-token',null,10);
  if coalesce((j->>'ok')::boolean,true) then raise exception 'K1P2-PII-06 Team feed accepted invalid authority'; end if;
end $$;
\echo 'KRONIA_K1_CURRENT_SENSITIVE_READ_BOUNDARY=PASS'
'''
if 'KRONIA_K1_CURRENT_SENSITIVE_READ_BOUNDARY=PASS' not in s:
    s += cert
p.write_text(s,encoding='utf-8')

# 5) Safe recovery cannot reopen Team/identity PII.
p=ROOT/'supabase/rollbacks/20260814_kronia_k1_phase2_safe_recovery.sql'
s=p.read_text(encoding='utf-8')
recovery=r'''

-- Sensitive identity reads remain least-privilege during recovery.
revoke all on table public.aos_usuarios from anon,authenticated;
grant select(id,codigo_asesor,nombre,apellidos,rol,cargo,area,sede,activo,cuenta_activada,two_factor,paneles_acceso,avatar_url,nivel_jerarquia,acceso_geo,sedes_permitidas,cmp,servicios)
  on public.aos_usuarios to anon,authenticated;
revoke all on table public.aos_rrhh from anon,authenticated;
grant select(codigo_asesor,nombre,apellido,puesto,sede,estado) on public.aos_rrhh to anon,authenticated;
revoke all on table public.aos_team_full from public,anon,authenticated;
grant select on table public.aos_team_full to service_role;
'''
if '-- Sensitive identity reads remain least-privilege during recovery.' not in s:
    idx=s.rfind('\ncommit;')
    if idx<0: raise SystemExit('recovery commit anchor missing')
    s=s[:idx]+recovery+s[idx:]
p.write_text(s,encoding='utf-8')

# 6) Static CURRENT contract guards the browser/database boundary and canonical token.
p=ROOT/'ci/kronia-k1-phase2/runtime_contract.py'
s=p.read_text(encoding='utf-8')
if "browser=(app/'public/k1-browser-security.js').read_text()" in s and "adminteam=(app/'public/admin-team.html').read_text()" not in s:
    s=s.replace("browser=(app/'public/k1-browser-security.js').read_text()", "browser=(app/'public/k1-browser-security.js').read_text(); adminteam=(app/'public/admin-team.html').read_text()")
anchor="assert 'aos_si_token' not in browser and 'aos_app_token' in browser\n"
checks=(
    "assert 'aos_team_feed_v3' in migration_b and 'revoke all on table public.aos_team_full from public,anon,authenticated' in migration_b\n"
    "assert \"grant select(id,codigo_asesor,nombre,apellidos,rol,cargo,area,sede,activo,cuenta_activada,two_factor,paneles_acceso,avatar_url,nivel_jerarquia,acceso_geo,sedes_permitidas,cmp,servicios)\" in migration_b\n"
    "assert \"u.pathname==='/rest/v1/aos_team_full'\" in browser and 'SAFE_USER_COLUMNS' in browser and 'SAFE_RRHH_COLUMNS' in browser\n"
    "assert 'aos_si_token' not in adminteam and 'aos_app_token' in adminteam\n"
)
if checks not in s:
    if anchor not in s: raise SystemExit('runtime canonical-token anchor missing')
    s=s.replace(anchor,anchor+checks,1)
p.write_text(s,encoding='utf-8')

print('KRONIA_K1_CURRENT_SENSITIVE_READ_FIX=PASS')
